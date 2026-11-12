import { sql } from "drizzle-orm";
import { institute } from "@/institutes/markaz-al-azeem";
import { receiptPattern } from "@/institutes/manual-donations";
import { privateJson, tokenHash } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

type Cursor = { recorded_at: string; id: string };
type LocalizedText = Partial<Record<"en" | "ur", string>>;
type TrailRow = Cursor & {
  receipt_number: string;
  receipt_locale: "en" | "ur";
  credited_on: string;
  amount_paisa: string;
  donation_type: "general" | "sadaqah" | "zakat";
  cause_title: LocalizedText | null;
  bank_reference_tail: string | null;
  public_ref?: string;
  donor_name: string | null;
  issuer_name: LocalizedText | null;
  issuer_address: LocalizedText | null;
  issuer_slug: string;
  issuer_logo_key: string | null;
  replaces_donation: boolean;
  replaces_receipt: string | null;
  status: "recorded" | "reversed";
  reversal_reason: string | null;
  events: {
    event_type: "received" | "allocated";
    occurred_on: string;
    amount_paisa: string;
    cause_title: LocalizedText | null;
  }[];
};

const pageSize = 20;
const tokenPattern = /^[A-Za-z0-9_-]{43}$/;
export const donationRefPattern = /^[a-z2-7]{10}$/;
const uuidPattern = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;
const cursorPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/;

async function requestFields(request: Request) {
  if (
    request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !==
      "application/json" ||
    !request.body
  )
    return null;

  const reader = request.body.getReader();
  const buffer = new Uint8Array(1024);
  let length = 0;
  try {
    for (;;) {
      const chunk = await reader.read();
      if (chunk.done) break;
      if (length + chunk.value.length > buffer.length) {
        await reader.cancel();
        return null;
      }
      buffer.set(chunk.value, length);
      length += chunk.value.length;
    }
    const input: unknown = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(
        buffer.subarray(0, length),
      ),
    );
    return input && typeof input === "object" && !Array.isArray(input)
      ? (input as Record<string, unknown>)
      : null;
  } catch {
    return null;
  } finally {
    reader.releaseLock();
  }
}

function readCursor(value: unknown): Cursor | null | undefined {
  if (value === undefined) return null;
  if (!value || typeof value !== "object") return undefined;
  const { recorded_at, id } = value as Record<string, unknown>;
  if (
    typeof recorded_at !== "string" ||
    !cursorPattern.test(recorded_at) ||
    typeof id !== "string" ||
    !uuidPattern.test(id)
  )
    return undefined;
  const date = new Date(recorded_at);
  if (
    !Number.isFinite(date.getTime()) ||
    date.toISOString().slice(0, 23) !== recorded_at.slice(0, 23)
  )
    return undefined;
  return { recorded_at, id };
}

export async function readTrailQuery(request: Request) {
  const fields = await requestFields(request);
  if (
    !fields ||
    typeof fields.token !== "string" ||
    !tokenPattern.test(fields.token)
  )
    return null;
  const cursor = readCursor(fields.cursor);
  if (cursor === undefined) return null;
  return { hash: await tokenHash(fields.token), cursor };
}

function receiptLogo(slug: string, storageKey: string | null) {
  const parts = storageKey?.split("/");
  if (
    parts?.length &&
    parts.every((part) => part && part !== "." && part !== "..")
  )
    return `https://media.azeem-lateef.com/${parts.map(encodeURIComponent).join("/")}`;
  return slug === "markaz-al-azeem" ? institute.logo.small : null;
}

function trailPage(rows: TrailRow[]) {
  const tail = rows[pageSize - 1];
  return privateJson({
    donations: rows
      .slice(0, pageSize)
      .map(({ issuer_slug, issuer_logo_key, ...donation }) => ({
        ...donation,
        issuer_logo: receiptLogo(issuer_slug, issuer_logo_key),
      })),
    nextCursor:
      rows.length > pageSize
        ? { recorded_at: tail.recorded_at, id: tail.id }
        : null,
  });
}

export async function readDonorTrail(
  tx: AuthQuery,
  query: { hash: string; cursor: Cursor | null },
) {
  const { rows } = await tx.execute<TrailRow>(sql`
    select id, receipt_number, receipt_locale, credited_on, amount_paisa,
      donation_type, status, recorded_at, events, reversal_reason, cause_title, bank_reference_tail,
      donor_name, issuer_name, issuer_address, issuer_slug, issuer_logo_key, replaces_donation, replaces_receipt
    from identity.read_guest_trail(
      ${query.hash}, ${query.cursor?.recorded_at ?? null}::timestamptz, ${query.cursor?.id ?? null}::uuid
    )
  `);
  if (!rows.length) return privateJson({ code: "unavailable" }, 404);
  return trailPage(rows);
}

export async function readAccountTrail(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const fields = await requestFields(request);
  if (!fields) return privateJson({ code: "invalid" }, 400);
  const cursor = readCursor(fields.cursor);
  const ref = fields.donationRef;
  if (
    cursor === undefined ||
    (ref !== undefined &&
      (typeof ref !== "string" || !donationRefPattern.test(ref) || cursor))
  )
    return privateJson({ code: "invalid" }, 400);

  const { rows } = await tx.execute<TrailRow>(sql`
    select id, receipt_number, receipt_locale, credited_on, amount_paisa,
      donation_type, status, recorded_at, events, reversal_reason, cause_title, bank_reference_tail, public_ref,
      donor_name, issuer_name, issuer_address, issuer_slug, issuer_logo_key, replaces_donation, replaces_receipt
    from identity.read_account_trail(${sessionId}::uuid, ${cursor?.recorded_at ?? null}::timestamptz,
      ${cursor?.id ?? null}::uuid, ${ref ?? null}::text)
  `);
  if (ref && !rows.length) return privateJson({ code: "unavailable" }, 404);
  return trailPage(rows);
}

export async function claimGuestDonations(tx: AuthQuery, sessionId: string) {
  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(sql`
    select identity.claim_guest_donations(${sessionId}::uuid) as code
  `);
  switch (result?.code) {
    case "claimed":
    case "none":
      return privateJson(result);
    case "conflict":
      return privateJson(result, 409);
    default:
      return privateJson({ code: "denied" }, 403);
  }
}

export async function manageDonorLink(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
  origin: string,
) {
  const data = await requestFields(request);
  const receipt =
    typeof data?.receipt === "string" ? data.receipt.trim().toUpperCase() : "";
  if (!data || !receiptPattern.test(receipt) || data.confirm !== true)
    return privateJson({ code: "invalid" }, 400);

  let link: URL | undefined;
  let query;
  if (data.action === "issue") {
    const email =
      typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
    if (
      email.length > 254 ||
      !/^[^\s@\x00-\x1f\x7f]+@[^\s@\x00-\x1f\x7f]+\.[^\s@\x00-\x1f\x7f]+$/.test(
        email,
      ) ||
      (data.language !== "en" && data.language !== "ur")
    )
      return privateJson({ code: "invalid" }, 400);
    const token = Buffer.from(
      crypto.getRandomValues(new Uint8Array(32)),
    ).toString("base64url");
    const hash = await tokenHash(token);
    query = sql`select identity.issue_trail_link(${sessionId}::uuid, ${receipt}, ${email}, ${hash}, ${token.slice(-4)}) as outcome`;
    link = new URL(`/${data.language}/trail`, origin);
    link.hash = token;
  } else if (data.action === "revoke") {
    query = sql`select identity.revoke_trail_link(${sessionId}::uuid, ${receipt}) as outcome`;
  } else {
    return privateJson({ code: "invalid" }, 400);
  }

  const {
    rows: [result],
  } = await tx.execute<{ outcome: string }>(query);
  switch (result?.outcome) {
    case "issued":
      return privateJson({ code: "issued", link: link?.href }, 201);
    case "revoked":
      return privateJson({ code: "revoked" });
    case "unavailable":
      return privateJson({ code: "no_match" }, 404);
    case "invalid":
      return privateJson({ code: "invalid" }, 400);
    case "collision":
      return privateJson({ code: "unavailable" }, 503);
    default:
      return privateJson({ code: "denied" }, 403);
  }
}
