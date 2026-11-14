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
import { getPublicTrail } from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import type { PublicTrail } from "@/server/transparency";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/trail/[publicRef]">) {
  const { locale: raw, publicRef } = await params;
  const locale = requireLocale(raw);
  const t = await getTranslations({ locale, namespace: "common" });
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: `/trail/${publicRef}`,
    title: `${t("public.publicTrailTitle")} · ${institute.name[locale]}`,
    description: t("public.publicTrailIntro"),
  });
}

export default async function PublicTrailPage({
  params,
}: PageProps<"/[locale]/trail/[publicRef]">) {
  const { locale: raw, publicRef } = await params;
  const locale = requireLocale(raw);
  setRequestLocale(locale);
  if (!donationRefPattern.test(publicRef)) notFound();
  const trail = (await getPublicTrail(
    new Headers(await headers()),
    publicRef,
  )) as PublicTrail | null;
  if (!trail) notFound();
  const t = await getTranslations("common.public");
  const cause = pageTranslation(trail.cause_title ?? undefined, locale);
  const spent = trail.events.some(
    (event) => event.event_type === "spent" || event.event_type === "reported",
  );
  return (
    <article className="shell public-stack" aria-labelledby="public-trail-title">
      <header className="public-intro">
        <h1 id="public-trail-title">{t("publicTrailTitle")}</h1>
        <p>{t("publicTrailIntro")}</p>
      </header>
      <section className="ui-card">
        <p>
          <Amount paisa={trail.amount_paisa} locale={locale} />
        </p>
        <p>
          <time dateTime={trail.given_on}>{formatDate(trail.given_on, locale)}</time>
        </p>
        <p>{cause?.text ?? t("allNeeds")}</p>
        {trail.donor_label ? (
          <p>
            {trail.profile_ref ? (
              <a href={`/${locale}/donors/${trail.profile_ref}`}>
                <bdi>{trail.donor_label}</bdi>
              </a>
            ) : (
              <bdi>{trail.donor_label}</bdi>
            )}
          </p>
        ) : (
          <p>{t("anonymous")}</p>
        )}
      </section>
      {trail.events.length === 0 ? (
        <EmptyState title={t("publicTrailTitle")}>{t("publicTrailEmptySpend")}</EmptyState>
      ) : (
        <ol className="wall-list">
          {trail.events.map((event) => {
            const title = pageTranslation(event.cause_title ?? undefined, locale);
            const description = pageTranslation(event.description ?? undefined, locale);
            const report = pageTranslation(event.report_title ?? undefined, locale);
            const label =
              event.event_type === "received" ||
              event.event_type === "allocated" ||
              event.event_type === "spent" ||
              event.event_type === "reported" ||
              event.event_type === "reversal"
                ? t(`trailEvents.${event.event_type}`)
                : event.event_type;
            return (
              <li className="wall-row" key={`${event.event_type}-${event.occurred_on}-${event.amount_paisa}`}>
                <strong>{label}</strong>
                <time dateTime={event.occurred_on}>{formatDate(event.occurred_on, locale)}</time>
                <Amount paisa={event.amount_paisa} locale={locale} />
                {title && <span>{title.text}</span>}
                {description && <p>{description.text}</p>}
                {report && <p>{report.text}</p>}
              </li>
            );
          })}
        </ol>
      )}
      {!spent && trail.events.length > 0 && <p>{t("publicTrailEmptySpend")}</p>}
    </article>
  );
}
