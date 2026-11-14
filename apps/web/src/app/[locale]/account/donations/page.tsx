import { requireLocale } from "@/i18n/locale";
import { AccountDonations } from "./account-donations";

export const dynamic = "force-dynamic";

export default async function DonationsPage({
  params,
}: PageProps<"/[locale]/account/donations">) {
  return <AccountDonations locale={requireLocale((await params).locale)} />;
}
