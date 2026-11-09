import pg from "pg";
import {
  createResendEmailSender,
  receiptEmailIdempotencyKey,
  renderReceiptEmail,
  type EmailSender,
} from "../../../../packages/email/src/index";

type Env = {
  RECEIPT_EMAIL_PROVIDER?: string;
  RECEIPT_JOBS_HYPERDRIVE?: { connectionString: string };
  RECEIPT_JOBS_DATABASE_URL?: string;
  RECEIPT_EMAIL_LINK_KEY?: string;
  RECEIPT_EMAIL_FROM?: string;
  RECEIPT_EMAIL_REPLY_TO?: string;
  RESEND_API_KEY?: string;
};

type Claim = { job_id: string; claim_token: string };
type Locale = "en" | "ur";
type LocalizedText = Partial<Record<Locale, string>>;
type Prepared = {
  outcome: string;
  to_email: string;
  receipt_number: string;
  receipt_locale: Locale;
  credited_on: string;
  amount_paisa: string;
  institute_name: LocalizedText;
  cause_title: LocalizedText | null;
  domain: string;
  include_trail: boolean;
};

const batchSize = 10;
const encoder = new TextEncoder();

async function digest(value: string) {
  return Buffer.from(
    await crypto.subtle.digest("SHA-256", encoder.encode(value)),
  ).toString("hex");
}

async function importLinkKey(secret: string) {
  if (!/^[a-f0-9]{64}$/i.test(secret))
    throw new Error("Invalid receipt link key.");
  return crypto.subtle.importKey(
    "raw",
    Buffer.from(secret, "hex"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export async function runReceiptJobs(
  db: Pick<pg.Client, "query">,
  envelope: { from: string; replyTo?: string; linkKey: string },
  sender: EmailSender,
) {
  const key = await importLinkKey(envelope.linkKey);
  const {
    rows: [role],
  } = await db.query<{ role: string }>("select current_user as role");
  if (role?.role !== "tazkiyah_mail")
    throw new Error("Invalid receipt database role.");

  const { rows: claims } = await db.query<Claim>(
    "select job_id, claim_token from mail.claim_receipt_emails($1::integer)",
    [batchSize],
  );
  for (const claim of claims) {
    const token = Buffer.from(
      await crypto.subtle.sign(
        "HMAC",
        key,
        encoder.encode(`receipt-trail/v1:${claim.job_id}`),
      ),
    ).toString("base64url");
    const hash = await digest(token);
    const {
      rows: [prepared],
    } = await db.query<Prepared>(
      "select * from mail.prepare_receipt_email($1::uuid, $2::uuid, $3::text, null::text)",
      [claim.job_id, claim.claim_token, hash],
    );
    if (!prepared || prepared.outcome === "stale") continue;

    async function finish(result: string, retryAfterSeconds?: number) {
      await db.query(
        "select mail.finish_receipt_email($1::uuid, $2::uuid, $3::text, $4::integer)",
        [claim.job_id, claim.claim_token, result, retryAfterSeconds ?? null],
      );
    }

    if (prepared.outcome !== "ready") {
      await finish(
        prepared.outcome === "invalid" ? "provider_rejected" : prepared.outcome,
      );
      continue;
    }

    const locale = prepared.receipt_locale;
    let message;
    try {
      const origin = new URL(`https://${prepared.domain}`).origin;
      message = renderReceiptEmail({
        locale,
        instituteName:
          prepared.institute_name[locale] ??
          prepared.institute_name.en ??
          prepared.institute_name.ur ??
          "",
        receiptNumber: prepared.receipt_number,
        creditedOn: prepared.credited_on,
        amountPaisa: prepared.amount_paisa,
        causeTitle:
          prepared.cause_title?.[locale] ??
          prepared.cause_title?.en ??
          prepared.cause_title?.ur,
        trailLink: prepared.include_trail
          ? { origin, url: `${origin}/${locale}/trail#${token}` }
          : undefined,
      });
    } catch {
      await finish("provider_rejected");
      continue;
    }

    const outgoing = {
      to: prepared.to_email,
      idempotencyKey: receiptEmailIdempotencyKey(claim.job_id),
      ...message,
    };
    const bodyHash = await digest(
      JSON.stringify({
        adapter: "resend/v1",
        from: envelope.from,
        replyTo: envelope.replyTo,
        ...outgoing,
      }),
    );
    const {
      rows: [binding],
    } = await db.query<Pick<Prepared, "outcome">>(
      "select outcome from mail.prepare_receipt_email($1::uuid, $2::uuid, $3::text, $4::text)",
      [claim.job_id, claim.claim_token, hash, bodyHash],
    );
    if (!binding || binding.outcome === "stale") continue;
    if (binding.outcome !== "ready") {
      await finish(
        binding.outcome === "invalid" ? "provider_rejected" : binding.outcome,
      );
      continue;
    }

    const result = await sender.send(outgoing);
    if (result.status === "accepted") {
      await finish("sent");
    } else if (
      result.retryable &&
      (result.reason === "quota_exceeded" || result.reason === "rate_limited")
    ) {
      await finish("rate_limited", result.retryAfterSeconds);
    } else if (result.reason === "configuration") {
      await finish("configuration", result.retryAfterSeconds);
    } else if (result.retryable) {
      await finish(
        result.reason === "unconfirmed"
          ? "network_error"
          : "provider_unavailable",
        result.retryAfterSeconds,
      );
    } else {
      await finish(
        result.reason === "idempotency_conflict"
          ? "payload_changed"
          : "provider_rejected",
      );
    }
  }
}

export default {
  async scheduled(_controller: unknown, env: Env) {
    if (env.RECEIPT_EMAIL_PROVIDER !== "resend") return;
    const connectionString =
      env.RECEIPT_JOBS_HYPERDRIVE?.connectionString ??
      env.RECEIPT_JOBS_DATABASE_URL;
    const from = env.RECEIPT_EMAIL_FROM?.trim();
    const replyTo = env.RECEIPT_EMAIL_REPLY_TO?.trim() || undefined;
    const apiKey = env.RESEND_API_KEY;
    const linkKey = env.RECEIPT_EMAIL_LINK_KEY;
    if (!connectionString || !from || !apiKey || !linkKey)
      throw new Error("Receipt email Worker configuration is incomplete.");

    const db = new pg.Client({
      connectionString,
      connectionTimeoutMillis: 5000,
      query_timeout: 15000,
    });
    let closing = false;
    db.on("error", (error: Error) => {
      if (
        closing &&
        error instanceof TypeError &&
        error.message === "This socket has been closed."
      )
        return;
      console.error("Receipt email database connection error.");
    });
    try {
      await db.connect();
      await runReceiptJobs(
        db,
        { from, replyTo, linkKey },
        createResendEmailSender({ apiKey, from, replyTo }),
      );
    } catch {
      throw new Error("Receipt email batch could not complete.");
    } finally {
      closing = true;
      await db
        .end()
        .catch(() =>
          console.error(
            "Receipt email database connection did not close cleanly.",
          ),
        );
    }
  },
};
