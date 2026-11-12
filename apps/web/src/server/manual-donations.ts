import { sql } from "drizzle-orm";
import {
  donationTypes,
  karachiDate,
  type DonationBank,
  type DonationCause,
  type RecordedDonation,
} from "@/institutes/manual-donations";
import { privateJson } from "./staff-invitations";
import type { AdminAccess, AuthQuery } from "./workspace-access";

export type DonationWorkspace =
  | {
      state: "allowed";
      banks: DonationBank[];
      causes: DonationCause[];
      recent: RecordedDonation[];
    }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

export async function readDonationWorkspace(tx: AuthQuery, sessionId: string) {
  const {
    rows: [options],
  } = await tx.execute<{
    allowed: boolean;
    bank_accounts: DonationBank[];
    causes: DonationCause[];
  }>(
    sql`select * from identity.read_manual_donation_options(${sessionId}::uuid)`,
  );
  if (!options?.allowed) return privateJson({ state: "denied" });

  const { rows } = await tx.execute<RecordedDonation>(sql`
    select id, receipt_number, credited_on::text, amount_paisa::text,
      donation_type, cause_id
    from identity.list_manual_donations(${sessionId}::uuid)
  `);
  return privateJson({
    state: "allowed",
    banks: options.bank_accounts,
    causes: options.causes,
    recent: rows,
  } satisfies DonationWorkspace);
}

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const supportedDate = /^(?!0000)\d{4}-\d{2}-\d{2}$/;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const localizedDigits = "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹";

export async function recordDonation(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const {
    operation,
    bank,
    reference,
    date,
    amount,
    type,
    cause,
    email,
    emailConfirmed,
    language,
    confirmLarge,
    confirmSimilar,
  } = input as Record<string, unknown>;
  const rupees =
    typeof amount === "string"
      ? amount.replace(/[٠-٩۰-۹]/g, (digit) =>
          String(localizedDigits.indexOf(digit) % 10),
        )
      : "";
  if (
    typeof operation !== "string" ||
    !uuid.test(operation) ||
    typeof bank !== "string" ||
    !uuid.test(bank) ||
    typeof reference !== "string" ||
    reference.trim().length < 1 ||
    reference.trim().length > 120 ||
    /[\x00-\x1f\x7f]/.test(reference) ||
    typeof date !== "string" ||
    !supportedDate.test(date) ||
    date > karachiDate() ||
    !/^[1-9]\d{0,11}$/.test(rupees) ||
    !donationTypes.some((kind) => kind === type) ||
    (cause !== "" && (typeof cause !== "string" || !uuid.test(cause))) ||
    typeof email !== "string" ||
    email.length > 254 ||
    (email.trim() !== "" && !emailPattern.test(email.trim())) ||
    (emailConfirmed !== undefined && typeof emailConfirmed !== "boolean") ||
    (emailConfirmed === true && email.trim() === "") ||
    (language !== "en" && language !== "ur") ||
    typeof confirmLarge !== "boolean" ||
    typeof confirmSimilar !== "boolean"
  )
    return invalid();

  const instant = new Date(date + "T00:00:00Z");
  if (
    !Number.isFinite(instant.getTime()) ||
    instant.toISOString().slice(0, 10) !== date
  )
    return invalid();

  if (emailConfirmed === true) {
    await tx.execute(
      sql`select set_config('app.receipt_email_confirmed', 'true', true)`,
    );
  }

  const {
    rows: [result],
  } = await tx.execute<{
    code: string;
    donation_id: string | null;
    receipt_number: string | null;
  }>(sql`
    select * from identity.record_manual_donation(
      ${sessionId}::uuid, ${operation}::uuid, ${bank}::uuid, ${reference.trim()},
      ${date}::date, ${(BigInt(rupees) * 100n).toString()}::bigint, ${type},
      ${cause || null}::uuid, ${email.trim().toLowerCase() || null}, ${language},
      true, ${confirmLarge}, ${confirmSimilar}
    )
  `);
  switch (result?.code) {
    case "recorded":
    case "existing":
      return privateJson(
        {
          code: result.code,
          receipt: result.receipt_number,
          emailQueued: result.code === "recorded" && emailConfirmed === true,
        },
        result.code === "recorded" ? 201 : 200,
      );
    case "bank_unavailable":
    case "cause_unavailable":
    case "large_confirmation_required":
    case "similar_confirmation_required":
    case "operation_conflict":
    case "bank_reference_conflict":
      return privateJson({ code: result.code }, 409);
    case "invalid":
      return invalid();
    default:
      return privateJson({ code: "denied" }, 403);
  }
}
