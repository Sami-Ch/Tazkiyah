import { notFound } from "next/navigation";
import { requireLocale } from "@/i18n/locale";
import { donationRefPattern } from "@/server/donor-trail";
import { AccountDonations } from "../account-donations";

export const dynamic = "force-dynamic";

export default async function DonationPage({
  params,
}: PageProps<"/[locale]/account/donations/[donationRef]">) {
  const { locale, donationRef } = await params;
  if (!donationRefPattern.test(donationRef)) notFound();
  return (
    <AccountDonations
      locale={requireLocale(locale)}
      donationRef={donationRef}
    />
  );
}
