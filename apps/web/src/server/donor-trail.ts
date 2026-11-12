import { sql } from "drizzle-orm";
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
const receiptPattern = /^[A-Z0-9]{1,64}-\d{4}-\d{5,19}$/;
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

export async function readTrailQuery(request: Request) {
  const fields = await requestFields(request);
  if (
    !fields ||
    typeof fields.token !== "string" ||
    !tokenPattern.test(fields.token)
  )
    return null;

  let cursor: Cursor | null = null;
  if (fields.cursor !== undefined) {
    if (!fields.cursor || typeof fields.cursor !== "object") return null;
    const { recorded_at, id } = fields.cursor as Record<string, unknown>;
    if (
      typeof recorded_at !== "string" ||
      !cursorPattern.test(recorded_at) ||
      typeof id !== "string" ||
      !uuidPattern.test(id)
    )
      return null;
    const date = new Date(recorded_at);
    if (
      !Number.isFinite(date.getTime()) ||
      date.toISOString().slice(0, 23) !== recorded_at.slice(0, 23)
    )
      return null;
    cursor = { recorded_at, id };
  }
  return { hash: await tokenHash(fields.token), cursor };
}

export async function readDonorTrail(
  tx: AuthQuery,
  query: { hash: string; cursor: Cursor | null },
) {
  const { rows } = await tx.execute<TrailRow>(sql`
    select id, receipt_number, receipt_locale, credited_on, amount_paisa,
      donation_type, status, recorded_at, events, reversal_reason
    from identity.read_guest_trail(
      ${query.hash}, ${query.cursor?.recorded_at ?? null}::timestamptz, ${query.cursor?.id ?? null}::uuid
    )
  `);
  if (!rows.length) return privateJson({ code: "unavailable" }, 404);
  const tail = rows[pageSize - 1];
  return privateJson({
    donations: rows.slice(0, pageSize).map((row) => ({
      ...row,
      cause_title:
        row.events.find(({ event_type }) => event_type === "allocated")
          ?.cause_title ?? null,
    })),
    nextCursor:
      rows.length > pageSize
        ? { recorded_at: tail.recorded_at, id: tail.id }
        : null,
  });
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
