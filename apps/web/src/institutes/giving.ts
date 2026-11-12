import type { LocalizedPageText } from "./site-pages";

export const donationPurposes = ["general", "sadaqah", "zakat"] as const;
export type DonationPurpose = (typeof donationPurposes)[number];

export type PublishedBankAccount = {
  id: string;
  label: LocalizedPageText;
  bank_name: string;
  account_title: string;
  account_number: string | null;
  iban: string | null;
  branch: string | null;
  for_donation_types: DonationPurpose[];
};
