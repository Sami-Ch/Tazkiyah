import type { Locale } from "@tazkiyah/i18n/routing";

export const donationTypes = ["general", "sadaqah", "zakat"] as const;
export type DonationType = (typeof donationTypes)[number];

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
