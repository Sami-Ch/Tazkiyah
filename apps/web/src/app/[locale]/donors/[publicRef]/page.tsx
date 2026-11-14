import { routing } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { formatDate } from "@/design/format";
import { Amount, EmptyState } from "@/design/ui";
import { requireLocale } from "@/i18n/locale";
import { institute } from "@/institutes/markaz-al-azeem";
import { pageTranslation } from "@/institutes/site-pages";
import { donationRefPattern } from "@/server/donor-trail";
import { getPublicDonor } from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import type { PublicDonor } from "@/server/transparency";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/donors/[publicRef]">) {
  const { locale: raw, publicRef } = await params;
  const locale = requireLocale(raw);
  const donor = (await getPublicDonor(
    new Headers(await headers()),
    publicRef,
  )) as PublicDonor | null;
  const t = await getTranslations({ locale, namespace: "common" });
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: `/donors/${publicRef}`,
    title: `${donor?.display_name ?? t("public.donorProfileTitle")} · ${institute.name[locale]}`,
    description: t("public.donorProfileEmpty"),
  });
}

export default async function DonorProfilePage({
  params,
}: PageProps<"/[locale]/donors/[publicRef]">) {
  const { locale: raw, publicRef } = await params;
  const locale = requireLocale(raw);
  setRequestLocale(locale);
  if (!donationRefPattern.test(publicRef)) notFound();
  const donor = (await getPublicDonor(
    new Headers(await headers()),
    publicRef,
  )) as PublicDonor | null;
  if (!donor) notFound();
  const t = await getTranslations("common.public");
  const initial = Array.from(donor.display_name)[0] ?? "";
  return (
    <article className="shell public-stack" aria-labelledby="donor-profile-title">
      <header className="public-intro">
        <p className="profile-mark" aria-hidden="true">
          <bdi>{initial}</bdi>
        </p>
        <h1 id="donor-profile-title">
          <bdi>{donor.display_name}</bdi>
        </h1>
        <p>{t("profilePhotoLater")}</p>
      </header>
      {donor.links.length > 0 && (
        <section aria-labelledby="donor-links-title">
          <h2 id="donor-links-title">{t("donorProfileLinks")}</h2>
          <ul>
            {donor.links.map((link) => (
              <li key={link.url}>
                <a href={link.url} rel="nofollow noopener noreferrer">
                  {link.label}
                </a>
              </li>
            ))}
          </ul>
        </section>
      )}
      {donor.gifts.length === 0 ? (
        <EmptyState title={donor.display_name}>{t("donorProfileEmpty")}</EmptyState>
      ) : (
        <ul className="wall-list">
          {donor.gifts.map((gift) => {
            const title = pageTranslation(gift.cause_title ?? undefined, locale);
            return (
              <li className="wall-row" key={gift.public_ref}>
                <Amount paisa={gift.amount_paisa} locale={locale} />
                <span>
                  {gift.cause_slug ? (
                    <a href={`/${locale}/causes/${gift.cause_slug}`}>
                      {title?.text ?? gift.cause_slug}
                    </a>
                  ) : (
                    t("allNeeds")
                  )}
                </span>
                <time dateTime={gift.given_on}>{formatDate(gift.given_on, locale)}</time>
                {gift.trail_public && (
                  <a href={`/${locale}/trail/${gift.public_ref}`}>{t("viewTrail")}</a>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </article>
  );
}
