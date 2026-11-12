import { sql } from "drizzle-orm";
import { asciiDigits, karachiDate } from "@/institutes/manual-donations";
import type { LocalizedPageText } from "@/institutes/site-pages";
import { privateJson } from "./staff-invitations";
import type { AdminAccess, AuthQuery } from "./workspace-access";

export type StatementBank = {
  id: string;
  label: LocalizedPageText;
  bank_name: string;
  is_active: boolean;
};
type StatementCredit = {
  id: string;
  credited_on: string;
  amount_paisa: string;
};
export type StatementTransfer = StatementCredit & {
  receipt_number: string;
  reference_tail: string;
  matched: boolean | null;
  statement_from: string | null;
  statement_to: string | null;
};
export type BankStatement = {
  review: string;
  transfers: StatementTransfer[];
  otherCredits: StatementCredit[];
};
export type StatementWorkspace =
  | { state: "allowed"; banks: StatementBank[] }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

function validDate(value: unknown): value is string {
  if (
    typeof value !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
    value < "1900-01-01"
  )
    return false;
  const date = new Date(`${value}T00:00:00Z`);
  return (
    Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value
  );
}

export async function readStatementWorkspace(tx: AuthQuery, sessionId: string) {
  const { rows } = await tx.execute<StatementBank>(sql`
    select * from identity.read_statement_accounts(${sessionId}::uuid)
  `);
  return privateJson({
    state: "allowed",
    banks: rows,
  } satisfies StatementWorkspace);
}

export async function manageBankStatement(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const {
    action,
    bank,
    from,
    to,
    review,
    matched,
    credited,
    amount,
    note,
    operation,
  } = input as Record<string, unknown>;
  if (
    typeof bank !== "string" ||
    !uuid.test(bank) ||
    !validDate(from) ||
    !validDate(to) ||
    from > to ||
    to > karachiDate()
  )
    return invalid();

  let code = "loaded";
  if (action === "close" || action === "note") {
    if (typeof operation !== "string" || !uuid.test(operation))
      return invalid();
    let write;
    if (action === "close") {
      if (
        typeof review !== "string" ||
        !/^[0-9a-f]{32}$/.test(review) ||
        !Array.isArray(matched) ||
        matched.some((id) => typeof id !== "string" || !uuid.test(id))
      )
        return invalid();
      write = sql`select identity.close_bank_statement(${sessionId}::uuid, ${bank}::uuid, ${from}::date,
        ${to}::date, ${review}, ${sql.param(matched)}::uuid[], ${operation}::uuid) as code`;
    } else {
      const normalizedAmount =
        typeof amount === "string" ? asciiDigits(amount).replace("٫", ".") : "";
      if (
        !validDate(credited) ||
        credited < from ||
        credited > to ||
        !/^\d{1,12}(?:\.\d{1,2})?$/.test(normalizedAmount) ||
        typeof note !== "string" ||
        note.length > 500 ||
        !note.trim() ||
        /\p{Cc}/u.test(note)
      )
        return invalid();
      const [rupees, fraction = ""] = normalizedAmount.split(".");
      const paisa = (
        BigInt(rupees) * 100n +
        BigInt(fraction.padEnd(2, "0"))
      ).toString();
      write = sql`select identity.note_non_donation_credit(${sessionId}::uuid, ${bank}::uuid, ${credited}::date,
        ${paisa}::bigint, ${note.trim()}, ${operation}::uuid) as code`;
    }
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(write);
    if (result?.code === "stale") return privateJson(result, 409);
    if (result?.code === "denied") return privateJson(result, 403);
    if (result?.code !== "closed" && result?.code !== "noted") return invalid();
    code = result.code;
  } else if (action !== "load") {
    return invalid();
  }

  const {
    rows: [result],
  } = await tx.execute<{ statement: BankStatement | null }>(sql`
    select identity.read_bank_statement(${sessionId}::uuid, ${bank}::uuid, ${from}::date, ${to}::date) as statement
  `);
  return result?.statement
    ? privateJson({ code, statement: result.statement })
    : invalid();
}
