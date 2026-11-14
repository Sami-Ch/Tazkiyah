import { routing, type Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { Badge, Button, EmptyState } from "@/design/ui";
import { requireLocale } from "@/i18n/locale";
import { causeCopy } from "@/institutes/cause-copy";
import type { CauseKind, PublishedCause } from "@/institutes/causes";
import { institute } from "@/institutes/markaz-al-azeem";
import { pageTranslation } from "@/institutes/site-pages";
import { getPublishedCauses } from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import { CauseProgress } from "./cause-progress";
import "./causes.css";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/causes">) {
  const locale = requireLocale((await params).locale);
  const copy = causeCopy[locale];
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: "/causes",
    title: `${copy.title} · ${institute.name[locale]}`,
    description: copy.intro,
  });
}

function CauseGrid({
  causes,
  locale,
  past = false,
}: {
  causes: PublishedCause[];
  locale: Locale;
  past?: boolean;
}) {
  const copy = causeCopy[locale];
  const Heading = past ? "h3" : "h2";
  return (
    <ul className="cause-grid" role="list">
      {causes.map((cause) => {
        const title = pageTranslation(cause.title, locale);
        const summary = pageTranslation(cause.summary, locale);
        if (!title || !summary) return null;
        return (
          <li className="ui-card" key={cause.id}>
            <div className="ui-pattern" aria-hidden="true" />
            <p className="giving-kicker">{copy.kinds[cause.cause_type]}</p>
            <Heading
              lang={title.language}
              dir={title.language === "ur" ? "rtl" : "ltr"}
            >
              {title.text}
            </Heading>
            {cause.accepts_zakat && (
              <Badge tone="zakat">{copy.zakatEligible}</Badge>
            )}
            <p
              lang={summary.language}
              dir={summary.language === "ur" ? "rtl" : "ltr"}
            >
              {summary.text}
            </p>
            <CauseProgress cause={cause} locale={locale} />
            <p className="giving-status">
              {cause.status === "active"
                ? copy.active
                : copy.status[cause.status]}
            </p>
            <Button
              href={`/${locale}/causes/${cause.slug}`}
              variant="secondary"
            >
              {copy.view}
              <span className="visually-hidden" lang={title.language}>
                {" "}
                {title.text}
              </span>
            </Button>
          </li>
        );
      })}
    </ul>
  );
}

function one(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function CausesPage({
  params,
  searchParams,
}: PageProps<"/[locale]/causes">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const query = await searchParams;
  const kind = one(query.kind);
  const zakat = one(query.zakat) === "1";
  const copy = causeCopy[locale];
  const t = await getTranslations("common.public");
  const causes = (
    await getPublishedCauses(new Headers(await headers()))
  ).filter((cause) => cause.status !== "archived");
  const visible = causes.filter((cause) => {
    if (zakat && !cause.accepts_zakat) return false;
    if (kind === "campaign" || kind === "ongoing" || kind === "yearly_stock")
      return cause.cause_type === (kind as CauseKind);
    return true;
  });
  const current = visible.filter(({ status }) => status === "active");
  const closed = visible.filter(({ status }) => status === "closed");
  const chip = (href: string, label: string, currentChip: boolean) => (
    <a href={href} aria-current={currentChip ? "true" : undefined}>
      {label}
    </a>
  );

  return (
    <section
      className="shell public-stack"
      aria-labelledby="giving-causes-title"
    >
      <header className="public-intro">
        <h1 id="giving-causes-title">{copy.title}</h1>
        <p>{copy.intro}</p>
      </header>
      <nav className="filter-row" aria-label={copy.title}>
        {chip(`/${locale}/causes`, t("filterAll"), !kind && !zakat)}
        {chip(`/${locale}/causes?zakat=1`, t("zakatOnly"), zakat && !kind)}
        {chip(
          `/${locale}/causes?kind=campaign`,
          t("campaigns"),
          kind === "campaign",
        )}
        {chip(
          `/${locale}/causes?kind=ongoing`,
          t("ongoing"),
          kind === "ongoing",
        )}
        {chip(
          `/${locale}/causes?kind=yearly_stock`,
          t("yearly"),
          kind === "yearly_stock",
        )}
      </nav>
      {current.length > 0 ? (
        <CauseGrid causes={current} locale={locale} />
      ) : (
        causes.length === 0 && (
          <EmptyState title={copy.title}>{t("causesSoon")}</EmptyState>
        )
      )}
      <article className="ui-card">
        <h2>{t("allNeeds")}</h2>
        <p>{t("allNeedsCard")}</p>
        <Button href={`/${locale}/donate`}>{t("giveAllNeeds")}</Button>
      </article>
      {closed.length > 0 && (
        <details>
          <summary className="ui-button ui-button-quiet">
            {t("closedCauses")}
          </summary>
          <CauseGrid causes={closed} locale={locale} past />
        </details>
      )}
    </section>
  );
}
