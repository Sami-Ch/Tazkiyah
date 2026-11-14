import { sql } from "drizzle-orm";
import { publicModules, type PublicModule } from "@/institutes/public-ledger";
import type { LocalizedPageText } from "@/institutes/site-pages";
import { privateJson } from "./staff-invitations";
import type { AdminAccess, AuthQuery } from "./workspace-access";

const themes = ["night-and-paper", "garden-and-clay"] as const;
const batches = ["daily", "weekly"] as const;

export type InstituteAdmin = { id: string; name: string };

export type InstituteSettingsRow = {
  name: LocalizedPageText;
  short_name: LocalizedPageText | null;
  parent_body: LocalizedPageText | null;
  address: LocalizedPageText;
  contact: {
    phone?: string;
    whatsapp?: string;
    email?: string;
    map_url?: string;
    visiting?: LocalizedPageText;
  };
  theme_direction: (typeof themes)[number] | null;
  founded_year: number | null;
  spending_batch_mode: (typeof batches)[number];
  principal_user_id: string | null;
  primary_domain: string | null;
  logo_saved: boolean;
  admins: InstituteAdmin[];
};

export type InstituteWorkspace =
  | { state: "allowed"; settings: InstituteSettingsRow }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

export type ModuleSwitch = { module_name: PublicModule; enabled: boolean };

export type ModuleWorkspace =
  | { state: "allowed"; modules: ModuleSwitch[] }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

export type ExpectedPledge = {
  id: string;
  frequency: "monthly" | "yearly";
  amount_paisa: string;
  donation_type: "zakat" | "sadaqah" | "general";
  cause_title: LocalizedPageText | null;
  period_start: string;
  period_end: string;
  starts_on: string;
  is_anonymous: boolean;
  donor_label: string | null;
  missed_periods: number;
};

export type PledgeWorkspace =
  | { state: "allowed"; pledges: ExpectedPledge[] }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

function localized(value: unknown): LocalizedPageText | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const pair = {
    ...(typeof record.en === "string" ? { en: record.en } : {}),
    ...(typeof record.ur === "string" ? { ur: record.ur } : {}),
  };
  return pair.en || pair.ur ? pair : null;
}

export async function readInstituteWorkspace(tx: AuthQuery, sessionId: string) {
  const {
    rows: [row],
  } = await tx.execute<InstituteSettingsRow>(sql`
    select name, short_name, parent_body, address, contact, theme_direction,
      founded_year, spending_batch_mode, principal_user_id, primary_domain,
      logo_saved, admins
    from identity.read_institute_settings(${sessionId}::uuid)
  `);
  if (!row) return privateJson({ state: "denied" } satisfies InstituteWorkspace);
  return privateJson({
    state: "allowed",
    settings: {
      ...row,
      name: localized(row.name) ?? {},
      short_name: localized(row.short_name),
      parent_body: localized(row.parent_body),
      address: localized(row.address) ?? {},
      contact: row.contact ?? {},
      admins: Array.isArray(row.admins) ? row.admins : [],
    },
  } satisfies InstituteWorkspace);
}

function pair(value: unknown, max: number) {
  if (value === null) return null;
  if (!value || typeof value !== "object") return undefined;
  const record = value as Record<string, unknown>;
  const en = typeof record.en === "string" ? record.en.trim() : "";
  const ur = typeof record.ur === "string" ? record.ur.trim() : "";
  if (!en && !ur) return null;
  if (!en || !ur || en.length > max || ur.length > max) return undefined;
  if (/[\u0000-\u001f\u007f]/.test(en + ur)) return undefined;
  return { en, ur };
}

function text(value: unknown, max: number) {
  if (value === null || value === "") return null;
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  if (!trimmed) return null;
  if (trimmed.length > max || /[\u0000-\u001f\u007f]/.test(trimmed))
    return undefined;
  return trimmed;
}

export async function saveInstituteSettings(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const data = input as Record<string, unknown>;
  const name = pair(data.name, 160);
  const shortName = pair(data.shortName, 80);
  const parent = pair(data.parent, 160);
  const address = pair(data.address, 240);
  const visiting = pair(data.visiting, 240);
  const phone = text(data.phone, 24);
  const whatsapp = text(data.whatsapp, 24);
  const email = text(data.email, 254);
  const mapUrl = text(data.map, 300);
  const founded =
    data.founded === "" || data.founded === null
      ? null
      : typeof data.founded === "number" &&
          Number.isInteger(data.founded) &&
          data.founded >= 1800 &&
          data.founded <= 2100
        ? data.founded
        : undefined;
  const principal = data.principal === "" || data.principal === null
    ? null
    : typeof data.principal === "string" &&
        /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(data.principal)
      ? data.principal
      : undefined;
  if (
    !name ||
    shortName === undefined ||
    parent === undefined ||
    !address ||
    visiting === undefined ||
    phone === undefined ||
    whatsapp === undefined ||
    email === undefined ||
    mapUrl === undefined ||
    founded === undefined ||
    principal === undefined ||
    !themes.some((theme) => theme === data.theme) ||
    !batches.some((batch) => batch === data.batch)
  )
    return invalid();

  const contact = {
    ...(phone ? { phone } : {}),
    ...(whatsapp ? { whatsapp } : {}),
    ...(email ? { email } : {}),
    ...(mapUrl ? { map_url: mapUrl } : {}),
    ...(visiting ? { visiting } : {}),
  };
  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(sql`
    select identity.save_institute_settings(
      ${sessionId}::uuid, ${sql.param(name)}::jsonb, ${sql.param(shortName)}::jsonb,
      ${sql.param(parent)}::jsonb, ${sql.param(address)}::jsonb, ${sql.param(contact)}::jsonb,
      ${data.theme}, ${founded}::smallint, ${data.batch}, ${principal}::uuid
    ) as code
  `);
  if (result?.code === "updated") return privateJson({ code: "updated" });
  if (result?.code === "invalid") return invalid();
  return privateJson({ code: "denied" }, 403);
}

export async function readModuleWorkspace(tx: AuthQuery, sessionId: string) {
  const { rows } = await tx.execute<ModuleSwitch>(sql`
    select module_name, enabled from identity.read_module_switches(${sessionId}::uuid)
  `);
  const modules = rows.filter((row): row is ModuleSwitch =>
    publicModules.some((name) => name === row.module_name),
  );
  if (modules.length !== publicModules.length)
    return privateJson({ state: "denied" } satisfies ModuleWorkspace);
  return privateJson({
    state: "allowed",
    modules,
  } satisfies ModuleWorkspace);
}

export async function saveModuleSwitches(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const data = input as Record<string, unknown>;
  if (
    !Array.isArray(data.modules) ||
    data.modules.length > publicModules.length ||
    !data.modules.every((name: unknown) =>
      publicModules.some((moduleName) => moduleName === name),
    ) ||
    new Set(data.modules).size !== data.modules.length
  )
    return invalid();
  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(sql`
    select identity.set_enabled_modules(
      ${sessionId}::uuid, ${sql.param(data.modules)}::text[], ${data.confirm === true}
    ) as code
  `);
  if (result?.code === "updated") return privateJson({ code: "updated" });
  if (result?.code === "confirm")
    return privateJson({ code: "confirm" }, 409);
  if (result?.code === "invalid") return invalid();
  return privateJson({ code: "denied" }, 403);
}

export async function readPledgeWorkspace(tx: AuthQuery, sessionId: string) {
  const { rows } = await tx.execute<ExpectedPledge>(sql`
    select id, frequency, amount_paisa::text, donation_type, cause_title,
      period_start::text, period_end::text, starts_on::text, is_anonymous,
      donor_label, missed_periods
    from identity.refresh_expected_pledges(${sessionId}::uuid)
  `);
  return privateJson({
    state: "allowed",
    pledges: rows.map((row) => ({
      ...row,
      cause_title: localized(row.cause_title),
      amount_paisa: String(row.amount_paisa),
    })),
  } satisfies PledgeWorkspace);
}
