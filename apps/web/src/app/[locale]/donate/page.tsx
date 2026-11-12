import { routing } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { requireLocale } from "@/i18n/locale";
import { givingCopy } from "@/institutes/giving-copy";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import { DonationPage } from "./donation-page";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/donate">) {
  const locale = requireLocale((await params).locale);
  const copy = givingCopy[locale];
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: "/donate",
    title: copy.title,
    description: copy.intro,
  });
}

export default async function Donate({
  params,
  searchParams,
}: PageProps<"/[locale]/donate">) {
  const locale = requireLocale((await params).locale);
  const { type } = await searchParams;
  return <DonationPage locale={locale} requestedPurpose={type} />;
}
