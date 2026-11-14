import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { cache } from "react";
import { formatDate } from "@/design/format";
import { Alert, Amount, Badge, Button } from "@/design/ui";
import { requireLocale } from "@/i18n/locale";
import { causeCopy } from "@/institutes/cause-copy";
import { isCauseSlug, publishedCauseLocales } from "@/institutes/causes";
import { institute } from "@/institutes/markaz-al-azeem";
import { pageTranslation } from "@/institutes/site-pages";
import {
  getDonorWall,
  getPublicOverview,
  getPublishedCauses,
} from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import { CauseProgress } from "../cause-progress";
import "../causes.css";

export const dynamic = "force-dynamic";

const readCause = cache(async (slug: string) => {
  if (!isCauseSlug(slug)) return undefined;
  const [cause] = await getPublishedCauses(new Headers(await headers()), slug);
  return cause;
});

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/causes/[slug]">) {
  const { locale: requestedLocale, slug } = await params;
  const locale = requireLocale(requestedLocale);
  const cause = await readCause(slug);
  if (!cause) return {};
  const title = pageTranslation(cause.title, locale)?.text;
  const description = pageTranslation(cause.summary, locale)?.text;
  if (!title || !description) return {};
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: publishedCauseLocales(cause),
    path: `/causes/${slug}`,
    title: `${title} · ${institute.name[locale]}`,
    description,
  });
}

export default async function CausePage({
  params,
}: PageProps<"/[locale]/causes/[slug]">) {
  const { locale: requestedLocale, slug } = await params;
  const locale = requireLocale(requestedLocale);
  setRequestLocale(locale);
  const cause = await readCause(slug);
  if (!cause) notFound();
  const copy = causeCopy[locale];
  const t = await getTranslations("common.public");
  const requestHeaders = new Headers(await headers());
  const [overview, wall] = await Promise.all([
    getPublicOverview(requestHeaders),
    getDonorWall(requestHeaders, new URLSearchParams({ cause: cause.slug })),
  ]);
  const money = overview?.causes.find((item) => item.id === cause.id);
  const spending = (overview?.spending ?? []).filter(
    (entry) => entry.cause_id === cause.id,
  );
  const title = pageTranslation(cause.title, locale);
  const summary = pageTranslation(cause.summary, locale);
  const body = pageTranslation(cause.body ?? undefined, locale);
  const scholar = pageTranslation(cause.zakat_approved_by ?? undefined, locale);
  if (!title || !summary) notFound();

  const fallback = [title, summary, body, scholar].some(
    (item) => item && item.language !== locale,
  );
  const month = new Intl.DateTimeFormat(`${locale}-PK`, {
    month: "long",
    timeZone: "UTC",
    numberingSystem: "latn",
  });
  return (
    <article
      className="shell giving-causes giving-detail"
      aria-labelledby="giving-cause-title"
    >
      <a className="giving-back" href={`/${locale}/causes`}>
        {copy.backCauses}
      </a>
      <header className="giving-heading">
        <p className="giving-kicker">{copy.kinds[cause.cause_type]}</p>
        <h1
          id="giving-cause-title"
          lang={title.language}
          dir={title.language === "ur" ? "rtl" : "ltr"}
        >
          {title.text}
        </h1>
        {cause.status === "closed" && cause.ends_on && (
          <Alert tone="warning">
            {copy.status.closed} · {formatDate(cause.ends_on, locale)}
          </Alert>
        )}
        {cause.status === "archived" && (
          <Alert tone="warning">{copy.status.archived}</Alert>
        )}
        {fallback && <Alert tone="warning">{t("fallback")}</Alert>}
        <p
          lang={summary.language}
          dir={summary.language === "ur" ? "rtl" : "ltr"}
        >
          {summary.text}
        </p>
      </header>
      <section
        className="giving-card giving-facts"
        aria-label={copy.kinds[cause.cause_type]}
      >
        <p className="giving-status">
          {cause.status === "active" ? copy.active : copy.status[cause.status]}
        </p>
        <CauseProgress
          cause={cause}
          locale={locale}
          showLifetime
          spent={money?.spent_paisa}
          spentLabel={t("spent")}
        />
        <dl>
          {cause.starts_on && (
            <div>
              <dt>{copy.starts}</dt>
              <dd>
                <time dateTime={cause.starts_on}>
                  {formatDate(cause.starts_on, locale)}
                </time>
              </dd>
            </div>
          )}
          {cause.ends_on && (
            <div>
              <dt>{copy.ends}</dt>
              <dd>
                <time dateTime={cause.ends_on}>
                  {formatDate(cause.ends_on, locale)}
                </time>
              </dd>
            </div>
          )}
          {cause.stock_year_start_month && (
            <div>
              <dt>{copy.stockMonth}</dt>
              <dd>
                {month.format(
                  Date.UTC(2000, cause.stock_year_start_month - 1, 1),
                )}
              </dd>
            </div>
          )}
          {scholar && (
            <div>
              <dt>{copy.zakatApproved}</dt>
              <dd
                lang={scholar.language}
                dir={scholar.language === "ur" ? "rtl" : "ltr"}
              >
                {scholar.text}
              </dd>
            </div>
          )}
        </dl>
        <Badge tone={cause.accepts_zakat ? "zakat" : "neutral"}>
          {cause.accepts_zakat ? copy.zakatEligible : t("notZakat")}
        </Badge>
      </section>
      {body && (
        <p
          className="published-page-copy"
          lang={body.language}
          dir={body.language === "ur" ? "rtl" : "ltr"}
        >
          {body.text}
        </p>
      )}
      <div>
        <Button
          href={
            cause.status === "active"
              ? `/${locale}/donate/${slug}`
              : `/${locale}/donate`
          }
        >
          {cause.status === "active" ? copy.donate : t("giveAllNeeds")}
        </Button>
      </div>
      <section aria-labelledby="cause-spending-title">
        <h2 id="cause-spending-title">{t("whereMoneyWent")}</h2>
        <p className="measure">{t("whereMoneyBody")}</p>
        {spending.length === 0 ? (
          <p>{t("noSpending")}</p>
        ) : (
          <ul className="wall-list">
            {spending.map((entry) => {
              const description = pageTranslation(entry.description, locale);
              return (
                <li className="wall-row" key={entry.id}>
                  <time dateTime={entry.spent_on}>
                    {formatDate(entry.spent_on, locale)}
                  </time>
                  <Amount paisa={entry.amount_paisa} locale={locale} />
                  {entry.status === "reversed" && (
                    <Badge tone="warning">{t("corrected")}</Badge>
                  )}
                  {description && (
                    <p
                      lang={description.language}
                      dir={description.language === "ur" ? "rtl" : "ltr"}
                    >
                      {description.text}
                    </p>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>
      {wall.items.length > 0 && (
        <section aria-labelledby="cause-wall-title">
          <h2 id="cause-wall-title">{t("donorWallTitle")}</h2>
          <ul className="wall-list">
            {wall.items.map((entry) => (
              <li className="wall-row" key={entry.public_ref}>
                <Amount paisa={entry.amount_paisa} locale={locale} />
                <span>{entry.donor_label ?? t("anonymous")}</span>
                <time dateTime={entry.given_on}>
                  {formatDate(entry.given_on, locale)}
                </time>
              </li>
            ))}
          </ul>
        </section>
      )}
    </article>
  );
}
