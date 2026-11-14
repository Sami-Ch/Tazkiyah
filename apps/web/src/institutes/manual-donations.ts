import type { Locale } from "@tazkiyah/i18n/routing";

export const donationTypes = ["general", "sadaqah", "zakat"] as const;
export type DonationType = (typeof donationTypes)[number];

export function asciiDigits(value: string) {
  const localizedDigits = "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹";
  return value.replace(/[٠-٩۰-۹]/g, (digit) =>
    String(localizedDigits.indexOf(digit) % 10),
  );
}

export const receiptPattern = /^[A-Z0-9]{1,64}-\d{4}-\d{5,19}$/;
export const reversalCategories = [
  "recorded_twice",
  "wrong_details",
  "wrong_type",
  "wrong_donor",
  "transfer_returned",
  "refund_to_donor",
  "moved_to_another_cause",
  "other",
] as const;
export type ReversalCategory = (typeof reversalCategories)[number];

export type TransferForReversal = {
  receipt_number: string;
  credited_on: string;
  amount_paisa: string;
  donation_type: DonationType;
  cause_title: Partial<Record<Locale, string>> | null;
  status: "recorded" | "reversed";
  has_spending: boolean;
  reversed_on: string | null;
  reversal_reason: ReversalCategory | null;
};

export type DonationBank = {
  id: string;
  label: Partial<Record<Locale, string>>;
  bank_name: string;
  for_donation_types: DonationType[];
};

export type DonationCause = {
  id: string;
  title: Partial<Record<Locale, string>>;
  slug: string;
  starts_on: string | null;
  ends_on: string | null;
  accepts_zakat: boolean;
};

export type RecordedDonation = {
  id: string;
  receipt_number: string;
  credited_on: string;
  amount_paisa: string;
  donation_type: DonationType;
  cause_id: string | null;
};

export function karachiDate() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Karachi",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format();
}

export function formatPkr(value: string | bigint, locale: Locale) {
  const paisa = BigInt(value);
  const remainder = paisa % 100n;
  const format = new Intl.NumberFormat(`${locale}-PK`, {
    style: "currency",
    currency: "PKR",
    minimumFractionDigits: remainder ? 2 : 0,
  });
  if (!remainder) return format.format(paisa / 100n);
  const digits = new Intl.NumberFormat(`${locale}-PK`, {
    minimumIntegerDigits: 2,
  }).format(remainder);
  return format
    .formatToParts(paisa / 100n)
    .map((part) => (part.type === "fraction" ? digits : part.value))
    .join("");
}
