import { sql } from "drizzle-orm";
import type { Locale } from "@tazkiyah/i18n/routing";
import { asciiDigits, receiptPattern } from "@/institutes/manual-donations";
import { donationRefPattern } from "./donor-trail";
import { privateJson, tokenHash } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const day = /^(?!0000)\d{4}-\d{2}-\d{2}$/;
const httpsLink = /^https:\/\/[^/\s@]+[.][^/\s@]+(\/\S*)?$/;

export type AllNeedsCause = {
  id: string;
  title: Partial<Record<Locale, string>>;
  accepts_zakat: boolean;
  status: "active" | "closed";
};

export type AllNeedsGift = {
  pool: "zakat" | "general";
  donation_id: string;
  receipt_number: string;
  credited_on: string;
  unallocated_paisa: string;
};

export type AllNeedsPool = {
  pool: "zakat" | "general";
  unallocated_paisa: string;
  gifts: number;
};

export type AllNeedsWorkspace =
  | {
      state: "allowed";
      pools: AllNeedsPool[];
      gifts: AllNeedsGift[];
      causes: AllNeedsCause[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

export type ReportEntry = {
  id: string;
  cause_id: string;
  amount_paisa: string;
  spent_on: string;
  description: Partial<Record<Locale, string>>;
  report_id: string | null;
};

export type SpendingReport = {
  id: string;
  period_kind: "daily" | "weekly" | "custom";
  period_start: string;
  period_end: string;
  title: Partial<Record<Locale, string>>;
  notes: Partial<Record<Locale, string>> | null;
  status: "draft" | "published";
};

export type ReportWorkspace =
  | {
      state: "allowed";
      entries: ReportEntry[];
      reports: SpendingReport[];
      causes: { id: string; title: Partial<Record<Locale, string>> }[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

export type DonorProfileWorkspace =
  | {
      state: "allowed";
      public_ref: string;
      display_name: string | null;
      profile_public: boolean;
      profile_links: { label: string; url: string }[];
      photo: "unavailable";
    }
  | { state: "signed-out" | "denied" | "unavailable" };

type JsonRecord = Record<string, unknown>;

function asRecord(value: unknown): JsonRecord | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonRecord)
    : null;
}

function textPair(ur: unknown, en: unknown, limit: number) {
  const description: Record<string, string> = {};
  for (const [language, value] of [
    ["ur", ur],
    ["en", en],
  ] as const) {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    if (!trimmed) continue;
    if (trimmed.length > limit || /\p{Cc}/u.test(trimmed)) return null;
    description[language] = trimmed;
  }
  return Object.keys(description).length ? description : null;
}

function wholeRupees(value: unknown) {
  const rupees = typeof value === "string" ? asciiDigits(value) : "";
  if (!/^[1-9]\d{0,11}$/.test(rupees)) return null;
  return (BigInt(rupees) * 100n).toString();
}

async function readJson(request: Request) {
  const input: unknown = await request.json().catch(() => null);
  return asRecord(input);
}

export async function readAllNeedsWorkspace(tx: AuthQuery, sessionId: string) {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: JsonRecord }>(sql`
    select identity.all_needs_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace = parseJson(row?.workspace);
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    pools: Array.isArray(workspace.pools) ? workspace.pools : [],
    gifts: Array.isArray(workspace.gifts) ? workspace.gifts : [],
    causes: Array.isArray(workspace.causes) ? workspace.causes : [],
  } satisfies AllNeedsWorkspace);
}

export async function manageAllNeeds(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const body = await readJson(request);
  if (!body || (body.action !== "preview" && body.action !== "split"))
    return privateJson({ code: "invalid" }, 400);
  if (body.pool !== "zakat" && body.pool !== "general")
    return privateJson({ code: "invalid" }, 400);
  if (!Array.isArray(body.parts) || body.parts.length === 0)
    return privateJson({ code: "invalid" }, 400);
  const parts = [];
  for (const part of body.parts) {
    const row = asRecord(part);
    const amount = wholeRupees(row?.amount);
    if (!row || typeof row.causeId !== "string" || !uuid.test(row.causeId) || !amount)
      return privateJson({ code: "invalid" }, 400);
    parts.push({ cause_id: row.causeId, amount_paisa: amount });
  }
  const query =
    body.action === "preview"
      ? sql`select identity.preview_all_needs_split(${sessionId}::uuid, ${body.pool}, ${JSON.stringify(parts)}::jsonb) as result`
      : sql`select identity.apply_all_needs_split(${sessionId}::uuid, ${body.pool}, ${JSON.stringify(parts)}::jsonb) as result`;
  const {
    rows: [row],
  } = await tx.execute<{ result: JsonRecord }>(query);
  const result = parseJson(row?.result);
  const code = typeof result?.code === "string" ? result.code : "invalid";
  if (code === "denied") return privateJson({ code }, 403);
  if (code === "preview" || code === "split") return privateJson(result);
  if (code === "over" || code === "cause") return privateJson({ code }, 409);
  return privateJson({ code: "invalid" }, 400);
}

export async function readSpendingReports(tx: AuthQuery, sessionId: string) {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: JsonRecord }>(sql`
    select identity.spending_reports_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace = parseJson(row?.workspace);
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    entries: Array.isArray(workspace.entries) ? workspace.entries : [],
    reports: Array.isArray(workspace.reports) ? workspace.reports : [],
    causes: Array.isArray(workspace.causes) ? workspace.causes : [],
  } satisfies ReportWorkspace);
}

export async function manageSpendingReport(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const body = await readJson(request);
  if (!body) return privateJson({ code: "invalid" }, 400);
  if (body.action === "publish") {
    if (typeof body.reportId !== "string" || !uuid.test(body.reportId))
      return privateJson({ code: "invalid" }, 400);
    const {
      rows: [row],
    } = await tx.execute<{ code: string; events: number | null }>(sql`
      select code, events from identity.publish_staff_report(
        ${sessionId}::uuid, ${body.reportId}::uuid
      )
    `);
    if (row?.code === "denied") return privateJson(row, 403);
    if (row?.code === "not_found") return privateJson(row, 404);
    if (row?.code === "not_ready") return privateJson(row, 409);
    if (row?.code === "published") return privateJson(row);
    return privateJson({ code: "invalid" }, 400);
  }
  if (body.action !== "save") return privateJson({ code: "invalid" }, 400);
  const title = textPair(body.titleUr, body.titleEn, 120);
  const notes =
    body.notesUr || body.notesEn
      ? textPair(body.notesUr, body.notesEn, 500)
      : null;
  if (
    (body.kind !== "daily" && body.kind !== "weekly" && body.kind !== "custom") ||
    typeof body.start !== "string" ||
    !day.test(body.start) ||
    typeof body.end !== "string" ||
    !day.test(body.end) ||
    !title ||
    ((body.notesUr || body.notesEn) && !notes) ||
    !Array.isArray(body.entryIds) ||
    body.entryIds.length === 0 ||
    body.entryIds.some((id) => typeof id !== "string" || !uuid.test(id))
  )
    return privateJson({ code: "invalid" }, 400);
  const {
    rows: [saved],
  } = await tx.execute<{ code: string; report_id: string | null }>(sql`
    select code, report_id from identity.save_spending_report(
      ${sessionId}::uuid, ${body.kind}, ${body.start}::date, ${body.end}::date,
      ${JSON.stringify(title)}::jsonb, ${notes ? JSON.stringify(notes) : null}::jsonb,
      ${`{${body.entryIds.join(",")}}`}::uuid[]
    )
  `);
  if (saved?.code === "denied") return privateJson(saved, 403);
  if (saved?.code === "entries") return privateJson(saved, 409);
  if (saved?.code === "saved") return privateJson(saved, 201);
  return privateJson({ code: "invalid" }, 400);
}

export async function setDonationVisibility(
  tx: AuthQuery,
  request: Request,
  sessionId: string | null,
) {
  const body = await readJson(request);
  if (!body) return privateJson({ code: "invalid" }, 400);
  const token = typeof body.token === "string" ? body.token : "";
  const guest = /^[A-Za-z0-9_-]{43}$/.test(token);
  if (token && !guest) return privateJson({ code: "invalid" }, 400);
  if (!sessionId && !guest) return privateJson({ code: "denied" }, 403);
  const publicRef = body.publicRef;
  const receipt = body.receipt;
  if (
    (publicRef !== undefined &&
      (typeof publicRef !== "string" || !donationRefPattern.test(publicRef))) ||
    (receipt !== undefined &&
      (typeof receipt !== "string" || !receiptPattern.test(receipt.trim().toUpperCase()))) ||
    (body.anonymous !== undefined && typeof body.anonymous !== "boolean") ||
    (body.trailPublic !== undefined && typeof body.trailPublic !== "boolean") ||
    (body.anonymous === undefined && body.trailPublic === undefined)
  )
    return privateJson({ code: "invalid" }, 400);
  const hash = guest ? await tokenHash(token) : null;
  const {
    rows: [row],
  } = await tx.execute<{ code: string }>(sql`
    select identity.set_donation_visibility(
      ${sessionId}::uuid, ${hash}, ${typeof publicRef === "string" ? publicRef : null},
      ${typeof receipt === "string" ? receipt.trim().toUpperCase() : null},
      ${typeof body.anonymous === "boolean" ? body.anonymous : null},
      ${typeof body.trailPublic === "boolean" ? body.trailPublic : null}
    ) as code
  `);
  if (row?.code === "denied") return privateJson(row, 403);
  if (row?.code === "not_found") return privateJson(row, 404);
  if (row?.code === "saved") return privateJson(row);
  return privateJson({ code: "invalid" }, 400);
}

export async function readDonorProfileWorkspace(
  tx: AuthQuery,
  sessionId: string,
) {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: JsonRecord }>(sql`
    select identity.donor_profile_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace = parseJson(row?.workspace);
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    public_ref: workspace.public_ref,
    display_name: workspace.display_name ?? null,
    profile_public: workspace.profile_public === true,
    profile_links: Array.isArray(workspace.profile_links)
      ? workspace.profile_links
      : [],
    photo: "unavailable",
  });
}

function profileLinks(value: unknown) {
  if (!Array.isArray(value) || value.length > 5) return null;
  const links = [];
  for (const item of value) {
    const row = asRecord(item);
    if (!row || typeof row.label !== "string" || typeof row.url !== "string")
      return null;
    const label = row.label.trim();
    const url = row.url.trim();
    if (
      label.length < 1 ||
      label.length > 40 ||
      /\p{Cc}/u.test(label) ||
      !httpsLink.test(url) ||
      url.length > 300
    )
      return null;
    links.push({ label, url });
  }
  return links;
}

export async function saveDonorProfile(
  tx: AuthQuery,
  request: Request,
  sessionId: string | null,
) {
  const body = await readJson(request);
  if (!body) return privateJson({ code: "invalid" }, 400);
  const token = typeof body.token === "string" ? body.token : "";
  if (token) {
    if (!/^[A-Za-z0-9_-]{43}$/.test(token) || typeof body.displayName !== "string")
      return privateJson({ code: "invalid" }, 400);
    const {
      rows: [row],
    } = await tx.execute<{ code: string }>(sql`
      select identity.save_guest_display_name(${await tokenHash(token)}, ${body.displayName}) as code
    `);
    if (row?.code === "denied") return privateJson(row, 403);
    if (row?.code === "saved") return privateJson(row);
    return privateJson({ code: "invalid" }, 400);
  }
  if (!sessionId) return privateJson({ code: "denied" }, 403);
  const links = profileLinks(body.links);
  const name = typeof body.displayName === "string" ? body.displayName : "";
  if (links === null || typeof body.profilePublic !== "boolean")
    return privateJson({ code: "invalid" }, 400);
  const {
    rows: [row],
  } = await tx.execute<{ code: string }>(sql`
    select identity.save_donor_profile(
      ${sessionId}::uuid, ${name}, ${body.profilePublic}, ${JSON.stringify(links)}::jsonb
    ) as code
  `);
  if (row?.code === "denied") return privateJson(row, 403);
  if (row?.code === "name") return privateJson(row, 409);
  if (row?.code === "saved") return privateJson(row);
  return privateJson({ code: "invalid" }, 400);
}

export type PublicTrailEvent = {
  event_type: string;
  occurred_on: string;
  amount_paisa: string;
  cause_title: Partial<Record<Locale, string>> | null;
  description: Partial<Record<Locale, string>> | null;
  report_title: Partial<Record<Locale, string>> | null;
};

export type PublicTrail = {
  public_ref: string;
  amount_paisa: string;
  given_on: string;
  status: string;
  donor_label: string | null;
  profile_ref: string | null;
  cause_title: Partial<Record<Locale, string>> | null;
  events: PublicTrailEvent[];
};

export async function readPublicTrail(tx: AuthQuery, ref: string | null) {
  if (!ref || !donationRefPattern.test(ref))
    return privateJson({ code: "not_found" }, 404);
  const { rows } = await tx.execute<JsonRecord>(sql`
    select t.public_ref, t.donation_amount_paisa::text as amount_paisa,
      t.given_on::text, t.donation_status as status, t.donor_label, t.profile_ref,
      cause.title as cause_title, t.event_type, t.occurred_on::text, t.amount_paisa::text as event_amount,
      event_cause.title as event_cause_title, t.spending_description, t.report_title
    from public_api.public_trails t
    left join public_api.causes cause on cause.id = t.donation_cause_id
    left join public_api.causes event_cause on event_cause.id = t.cause_id
    where t.public_ref = ${ref}
    order by t.event_id
  `);
  if (!rows.length) return privateJson({ code: "not_found" }, 404);
  const first = rows[0];
  const body: PublicTrail = {
    public_ref: String(first.public_ref),
    amount_paisa: String(first.amount_paisa),
    given_on: String(first.given_on),
    status: String(first.status),
    donor_label:
      typeof first.donor_label === "string" ? first.donor_label : null,
    profile_ref:
      typeof first.profile_ref === "string" ? first.profile_ref : null,
    cause_title: localized(first.cause_title),
    events: rows.map((row) => ({
      event_type: String(row.event_type),
      occurred_on: String(row.occurred_on),
      amount_paisa: String(row.event_amount),
      cause_title: localized(row.event_cause_title),
      description: localized(row.spending_description),
      report_title: localized(row.report_title),
    })),
  };
  if (body.donor_label === null) body.profile_ref = null;
  return privateJson(body);
}

export type PublicDonor = {
  public_ref: string;
  display_name: string;
  links: { label: string; url: string }[];
  gifts: {
    public_ref: string;
    amount_paisa: string;
    given_on: string;
    trail_public: boolean;
    cause_title: Partial<Record<Locale, string>> | null;
    cause_slug: string | null;
  }[];
};

export async function readPublicDonor(tx: AuthQuery, ref: string | null) {
  if (!ref || !donationRefPattern.test(ref))
    return privateJson({ code: "not_found" }, 404);
  const {
    rows: [profile],
  } = await tx.execute<JsonRecord>(sql`
    select public_ref, display_name, profile_links
    from public_api.donor_profiles where public_ref = ${ref}
  `);
  if (!profile || typeof profile.display_name !== "string")
    return privateJson({ code: "not_found" }, 404);
  const { rows } = await tx.execute<JsonRecord>(sql`
    select g.public_ref, g.amount_paisa::text, g.given_on::text, g.trail_public,
      c.title as cause_title, c.slug as cause_slug
    from public_api.donor_profile_gifts g
    left join public_api.causes c on c.id = g.cause_id
    where g.profile_ref = ${ref}
    order by g.given_on desc, g.public_ref desc
  `);
  const body: PublicDonor = {
    public_ref: String(profile.public_ref),
    display_name: profile.display_name,
    links: linkList(profile.profile_links),
    gifts: rows.flatMap((row) => {
      if (typeof row.public_ref !== "string" || typeof row.amount_paisa !== "string")
        return [];
      return [
        {
          public_ref: row.public_ref,
          amount_paisa: row.amount_paisa,
          given_on: String(row.given_on),
          trail_public: row.trail_public === true,
          cause_title: localized(row.cause_title),
          cause_slug: typeof row.cause_slug === "string" ? row.cause_slug : null,
        },
      ];
    }),
  };
  return privateJson(body);
}

function linkList(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.flatMap((item) => {
    const row = asRecord(item);
    if (!row || typeof row.label !== "string" || typeof row.url !== "string")
      return [];
    if (!httpsLink.test(row.url)) return [];
    return [{ label: row.label, url: row.url }];
  });
}

function localized(value: unknown) {
  const row = asRecord(value);
  if (!row) return null;
  const text: Partial<Record<Locale, string>> = {};
  if (typeof row.ur === "string") text.ur = row.ur;
  if (typeof row.en === "string") text.en = row.en;
  return text.ur || text.en ? text : null;
}

function parseJson(value: unknown): JsonRecord | null {
  if (typeof value === "string") {
    try {
      return asRecord(JSON.parse(value));
    } catch {
      return null;
    }
  }
  return asRecord(value);
}
