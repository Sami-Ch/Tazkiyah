import { notFound } from "next/navigation";
import { requireLocale } from "@/i18n/locale";
import { isCauseSlug } from "@/institutes/causes";
import { givingCopy } from "@/institutes/giving-copy";
import { DonationPage } from "../donation-page";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/donate/[slug]">) {
  const locale = requireLocale((await params).locale);
  const copy = givingCopy[locale];
  return { title: copy.title, description: copy.intro };
}

export default async function DonateToCause({
  params,
  searchParams,
}: PageProps<"/[locale]/donate/[slug]">) {
  const { locale: requestedLocale, slug } = await params;
  const locale = requireLocale(requestedLocale);
  if (!isCauseSlug(slug)) notFound();
  const { type } = await searchParams;
  return <DonationPage locale={locale} slug={slug} requestedPurpose={type} />;
}
