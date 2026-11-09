import { sql } from "drizzle-orm";
import {
  donationPurposes,
  type PublishedBankAccount,
} from "@/institutes/giving";
import { privateJson } from "./staff-invitations";
import type { AdminAccess, AuthQuery } from "./workspace-access";

export type AdminBankAccount = PublishedBankAccount & {
  is_active: boolean;
  show_on_donate: boolean;
};

export type BankWorkspace =
  | { state: "allowed"; accounts: AdminBankAccount[] }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

export async function readPublishedBankAccounts(tx: AuthQuery) {
  const {
    rows: [institute],
  } = await tx.execute<{
    bank_accounts: PublishedBankAccount[];
  }>(sql`select bank_accounts from public_api.institute_public`);
  return privateJson(institute?.bank_accounts ?? []);
}

export async function readBankWorkspace(tx: AuthQuery, sessionId: string) {
  const { rows } = await tx.execute<AdminBankAccount>(sql`
    select * from identity.read_bank_accounts(${sessionId}::uuid)
  `);
  return privateJson({
    state: "allowed",
    accounts: rows,
  } satisfies BankWorkspace);
}

function field(value: unknown, max: number) {
  if (typeof value !== "string" || /[\x00-\x1f\x7f]/.test(value))
    return undefined;
  const trimmed = value.trim();
  return trimmed.length <= max ? trimmed : undefined;
}

export async function writeBankAccount(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const data = input as Record<string, unknown>;
  let query;
  if (data.action === "create") {
    const en = field(data.labelEn, 90);
    const ur = field(data.labelUr, 90);
    const bank = field(data.bank, 120);
    const title = field(data.title, 120);
    const number = field(data.number, 40);
    const iban = field(data.iban, 42)?.replaceAll(" ", "").toUpperCase();
    const branch = field(data.branch, 120);
    if (
      !en ||
      !ur ||
      !bank ||
      !title ||
      number === undefined ||
      iban === undefined ||
      branch === undefined ||
      (!number && !iban) ||
      (number && !/^[A-Za-z0-9][A-Za-z0-9 -]{2,39}$/.test(number)) ||
      (iban && !/^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$/.test(iban)) ||
      !Array.isArray(data.purposes) ||
      !data.purposes.length ||
      data.purposes.length > 3 ||
      !data.purposes.every((value: unknown) =>
        donationPurposes.some((item) => item === value),
      )
    )
      return invalid();
    query = sql`select identity.create_bank_account(
      ${sessionId}::uuid, ${sql.param({ en, ur })}::jsonb, ${bank}, ${title},
      ${number || null}, ${iban || null}, ${branch || null}, ${sql.param(data.purposes)}::text[]
    ) as code`;
  } else if (data.action === "publish" || data.action === "hide") {
    if (
      typeof data.id !== "string" ||
      !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(data.id) ||
      (data.action === "publish" && data.confirm !== true)
    )
      return invalid();
    query = sql`select identity.set_bank_account_publication(
      ${sessionId}::uuid, ${data.id}::uuid, ${data.action === "publish"}, ${data.confirm === true}
    ) as code`;
  } else {
    return invalid();
  }

  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(query);
  switch (result?.code) {
    case "created":
      return privateJson(result, 201);
    case "updated":
      return privateJson(result);
    case "duplicate":
    case "inactive":
      return privateJson(result, 409);
    case "invalid":
      return invalid();
    default:
      return privateJson({ code: "denied" }, 403);
  }
}
