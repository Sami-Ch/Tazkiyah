import { sql } from "drizzle-orm";
import {
  causeKinds,
  causeLimits,
  isCauseSlug,
  type EditableCause,
  type PublishedCause,
} from "@/institutes/causes";
import { privateJson } from "./staff-invitations";
import type { AdminAccess, AuthQuery } from "./workspace-access";

export type CauseWorkspace =
  | { state: "allowed"; causes: EditableCause[] }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

export async function readPublishedCauses(tx: AuthQuery, slug: string | null) {
  if (slug !== null && !isCauseSlug(slug)) return privateJson([]);
  const { rows } = await tx.execute<PublishedCause>(sql`
    select id, slug, cause_type, title::jsonb, summary::jsonb,
      ${slug === null ? sql`null::jsonb` : sql`body::jsonb`} as body,
      target_paisa::text, raised_paisa::text, lifetime_raised_paisa::text,
      target_period, stock_year_start_month, starts_on::text, ends_on::text,
      accepts_zakat, zakat_approved_by::jsonb, status
    from public_api.causes
    ${slug === null ? sql`` : sql`where slug = ${slug}`}
    order by case status when 'active' then 0 when 'closed' then 1 else 2 end,
      display_order, created_at desc, slug
  `);
  return privateJson(rows);
}

export async function readCauseWorkspace(tx: AuthQuery, sessionId: string) {
  const { rows } = await tx.execute<EditableCause>(sql`
    select id, slug, cause_type, title, summary, body, status, starts_on::text, ends_on::text,
      target_paisa::text, target_period, stock_year_start_month, accepts_zakat,
      revision, has_recorded_allocations, zakat_approved_by, receipt_public_by_default
    from identity.read_causes(${sessionId})
  `);
  return privateJson({
    state: "allowed",
    causes: rows,
  } satisfies CauseWorkspace);
}

function localizedPair(input: unknown, maxLength: number, optional = false) {
  if (!input || typeof input !== "object") return undefined;
  const { en, ur } = input as Record<string, unknown>;
  if (typeof en !== "string" || typeof ur !== "string") return undefined;
  const pair = { en: en.trim(), ur: ur.trim() };
  if (optional && !pair.en && !pair.ur) return null;
  if (
    Object.values(pair).some(
      (value) => !value || value.length > maxLength || value.includes("\u0000"),
    )
  )
    return undefined;
  return pair;
}

function optionalDate(value: unknown) {
  if (value === "") return null;
  if (
    typeof value !== "string" ||
    !/^(?!0000)[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(value)
  )
    return undefined;
  const date = new Date(value + "T00:00:00Z");
  return Number.isFinite(date.getTime()) &&
    date.toISOString().slice(0, 10) === value
    ? value
    : undefined;
}

function scholarName(input: unknown) {
  if (input === null) return null;
  if (!input || typeof input !== "object") return undefined;
  const { en, ur } = input as Record<string, unknown>;
  if (typeof en !== "string" || typeof ur !== "string") return undefined;
  const names = Object.entries({ en: en.trim(), ur: ur.trim() }).filter(
    ([, value]) => value,
  );
  if (
    names.some(
      ([, value]) =>
        value.length > causeLimits.scholar || /\p{Cc}/u.test(value),
    )
  )
    return undefined;
  return names.length ? Object.fromEntries(names) : null;
}

function targetPaisa(value: unknown) {
  if (value === "") return null;
  if (typeof value !== "string" || !/^\d{1,12}(?:\.\d{1,2})?$/.test(value))
    return undefined;
  const [whole, fraction = ""] = value.split(".");
  const paisa = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, "0"));
  return paisa > 0n ? paisa.toString() : undefined;
}

function isUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(value)
  );
}

export async function writeCause(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const data = input as Record<string, unknown>;
  const { action, id, revision } = data;
  if (action !== "create" && (!isUuid(id) || !isUuid(revision)))
    return invalid();

  let query;
  if (action === "create" || action === "edit") {
    const { slug, kind, period, stockMonth, zakat, receiptPublicByDefault } =
      data;
    const hasDonationSettings =
      data.scholar !== undefined || receiptPublicByDefault !== undefined;
    const scholar = hasDonationSettings ? scholarName(data.scholar) : null;
    const title = localizedPair(data.title, causeLimits.title);
    const summary = localizedPair(data.summary, causeLimits.summary);
    const body = localizedPair(data.body, causeLimits.body, true);
    const target = targetPaisa(data.target);
    const starts = optionalDate(data.starts);
    const ends = optionalDate(data.ends);
    if (
      (action === "create" && !isCauseSlug(slug)) ||
      !causeKinds.some((candidate) => candidate === kind) ||
      !title ||
      !summary ||
      body === undefined ||
      target === undefined ||
      starts === undefined ||
      ends === undefined ||
      (starts !== null && ends !== null && starts > ends) ||
      typeof zakat !== "boolean" ||
      scholar === undefined ||
      (!zakat && scholar !== null) ||
      (hasDonationSettings && typeof receiptPublicByDefault !== "boolean") ||
      (kind === "campaign" && (target === null || ends === null)) ||
      (kind !== "campaign" && ends !== null) ||
      (kind === "ongoing" && period !== "monthly" && period !== "yearly") ||
      (kind === "yearly_stock" &&
        (typeof stockMonth !== "number" ||
          !Number.isInteger(stockMonth) ||
          stockMonth < 1 ||
          stockMonth > 12))
    )
      return invalid();
    const settings = hasDonationSettings
      ? { scholar, receiptPublicByDefault }
      : null;
    const values = sql`${kind}, ${sql.param(title)}::jsonb, ${sql.param(summary)}::jsonb,
      ${sql.param(body)}::jsonb, ${target}::bigint, ${kind === "ongoing" ? period : null},
      ${kind === "yearly_stock" ? stockMonth : null}::smallint, ${starts}::date, ${ends}::date, ${zakat}, ${sql.param(settings)}::jsonb`;
    query =
      action === "create"
        ? sql`select identity.create_cause(${sessionId}::uuid, ${slug}, ${values}) as outcome`
        : sql`select identity.edit_cause(${sessionId}::uuid, ${id}::uuid, ${revision}::uuid, ${values}) as outcome`;
  } else if (
    action === "publish" ||
    action === "close" ||
    action === "archive"
  ) {
    const next =
      action === "publish"
        ? "active"
        : action === "close"
          ? "closed"
          : "archived";
    query = sql`select identity.transition_cause(
      ${sessionId}::uuid, ${id}::uuid, ${revision}::uuid, ${next}
    ) as outcome`;
  } else {
    return invalid();
  }
  const {
    rows: [result],
  } = await tx.execute<{ outcome: string }>(query);
  switch (result?.outcome) {
    case "created":
      return privateJson({ outcome: "created" }, 201);
    case "updated":
      return privateJson({ outcome: "updated" });
    case "duplicate":
    case "stale":
    case "settings_locked":
    case "archive_blocked":
      return privateJson({ code: result.outcome }, 409);
    case "invalid":
      return invalid();
    default:
      return privateJson({ code: "denied" }, 403);
  }
}
