import { sql } from "drizzle-orm";
import type { Locale } from "@tazkiyah/i18n/routing";
import {
  asciiDigits,
  karachiDate,
  reversalCategories,
  type DonationType,
} from "@/institutes/manual-donations";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const day = /^(?!0000)\d{4}-\d{2}-\d{2}$/;

export type SpendingBalance = {
  donation_type: DonationType;
  unspent_paisa: string;
  raised_paisa: string;
  spent_paisa: string;
};

export type SpendingCause = {
  id: string;
  title: Partial<Record<Locale, string>>;
  status: "active" | "closed";
  balances: SpendingBalance[];
};

export type SpendingPool = {
  pool: "zakat" | "general";
  unallocated_paisa: string;
  gifts: number;
};

export type SpendingEntryRow = {
  id: string;
  cause_id: string;
  amount_paisa: string;
  spent_on: string;
  description: Partial<Record<Locale, string>>;
  status: "draft" | "recorded" | "reversed";
  receipt_public: boolean;
  matched_paisa: string;
};

export type SpendingWorkspace =
  | {
      state: "allowed";
      batch_on: string;
      causes: SpendingCause[];
      pools: SpendingPool[];
      entries: SpendingEntryRow[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type WorkspaceJson = {
  allowed: boolean;
  batch_on?: string;
  causes?: SpendingCause[];
  pools?: SpendingPool[];
  entries?: SpendingEntryRow[];
};

function textPair(ur: unknown, en: unknown) {
  const description: Record<string, string> = {};
  for (const [language, value] of [
    ["ur", ur],
    ["en", en],
  ] as const) {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    if (!trimmed) continue;
    if (trimmed.length > 500 || /\p{Cc}/u.test(trimmed)) return null;
    description[language] = trimmed;
  }
  return Object.keys(description).length ? description : null;
}

export async function readSpendingWorkspace(
  tx: AuthQuery,
  sessionId: string,
): Promise<Response> {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: WorkspaceJson }>(sql`
    select identity.spending_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace =
    typeof row?.workspace === "string"
      ? (JSON.parse(row.workspace) as WorkspaceJson)
      : row?.workspace;
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    batch_on: workspace.batch_on ?? "",
    causes: workspace.causes ?? [],
    pools: workspace.pools ?? [],
    entries: workspace.entries ?? [],
  } satisfies SpendingWorkspace);
}

export async function manageSpending(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const body = input as Record<string, unknown>;

  if (body.action === "record" || body.action === "record-one") {
    const entryId = body.entryId;
    if (
      body.action === "record-one" &&
      (typeof entryId !== "string" || !uuid.test(entryId))
    )
      return invalid();
    const { rows } = await tx.execute<{
      entry_id: string | null;
      code: string;
      matched_paisa: string | null;
      unmatched_paisa: string | null;
    }>(sql`
      select entry_id, code, matched_paisa::text, unmatched_paisa::text
      from identity.record_spending_batch(
        ${sessionId}::uuid,
        ${body.action === "record-one" ? entryId : null}::uuid
      )
    `);
    const code = rows[0]?.code;
    if (code === "denied") return privateJson({ code }, 403);
    if (!code || code === "invalid") return invalid();
    return privateJson({ code, results: rows });
  }

  if (body.action === "reverse") {
    const { entryId, category, note } = body;
    if (
      typeof entryId !== "string" ||
      !uuid.test(entryId) ||
      !reversalCategories.some((reason) => reason === category) ||
      typeof note !== "string" ||
      note.length > 500 ||
      /\p{Cc}/u.test(note) ||
      (category === "other" && !note.trim())
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.reverse_spending_entry(
        ${sessionId}::uuid, ${entryId}::uuid, ${category}, ${note.trim()}
      ) as code
    `);
    if (result?.code === "denied") return privateJson(result, 403);
    if (result?.code === "not_found") return privateJson(result, 404);
    if (result?.code === "not_recorded") return privateJson(result, 409);
    if (result?.code === "reversed") return privateJson(result);
    return invalid();
  }

  if (body.action !== "save") return invalid();
  const description = textPair(body.descriptionUr, body.descriptionEn);
  const rupees =
    typeof body.amount === "string" ? asciiDigits(body.amount) : "";
  const spentOn = body.date;
  if (
    typeof body.causeId !== "string" ||
    !uuid.test(body.causeId) ||
    !/^[1-9]\d{0,11}$/.test(rupees) ||
    typeof spentOn !== "string" ||
    !day.test(spentOn) ||
    spentOn > karachiDate() ||
    !description ||
    (body.receiptPublic !== undefined &&
      typeof body.receiptPublic !== "boolean")
  )
    return invalid();
  const instant = new Date(spentOn + "T00:00:00Z");
  if (
    !Number.isFinite(instant.getTime()) ||
    instant.toISOString().slice(0, 10) !== spentOn
  )
    return invalid();

  const {
    rows: [saved],
  } = await tx.execute<{ code: string; entry_id: string | null }>(sql`
    select code, entry_id from identity.save_spending_draft(
      ${sessionId}::uuid, ${body.causeId}::uuid, ${(BigInt(rupees) * 100n).toString()}::bigint,
      ${spentOn}::date, ${JSON.stringify(description)}::jsonb, ${body.receiptPublic !== false}
    )
  `);
  if (saved?.code === "denied") return privateJson(saved, 403);
  if (saved?.code === "cause_unavailable") return privateJson(saved, 409);
  if (saved?.code === "saved" || saved?.code === "saved_over_balance")
    return privateJson(saved, 201);
  return invalid();
}
