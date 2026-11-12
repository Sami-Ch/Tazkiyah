import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { cache } from "react";
import { requireLocale } from "@/i18n/locale";
import { causeCopy } from "@/institutes/cause-copy";
import { isCauseSlug, publishedCauseLocales } from "@/institutes/causes";
import { institute } from "@/institutes/markaz-al-azeem";
import { pageTranslation } from "@/institutes/site-pages";
import { getPublishedCauses } from "@/server/auth";
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
  const title = pageTranslation(cause.title, locale);
  const summary = pageTranslation(cause.summary, locale);
  const body = pageTranslation(cause.body ?? undefined, locale);
  const scholar = pageTranslation(cause.zakat_approved_by ?? undefined, locale);
  if (!title || !summary) notFound();

  const fallback = [title, summary, body, scholar].some(
    (item) => item && item.language !== locale,
  );
  const date = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "long",
    timeZone: "UTC",
  });
  const month = new Intl.DateTimeFormat(`${locale}-PK`, {
    month: "long",
    timeZone: "UTC",
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
        {fallback && <p className="published-page-note">{copy.fallback}</p>}
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
        <CauseProgress cause={cause} locale={locale} showLifetime />
        <dl>
          {cause.starts_on && (
            <div>
              <dt>{copy.starts}</dt>
              <dd>
                <time dateTime={cause.starts_on}>
                  {date.format(new Date(cause.starts_on))}
                </time>
              </dd>
            </div>
          )}
          {cause.ends_on && (
            <div>
              <dt>{copy.ends}</dt>
              <dd>
                <time dateTime={cause.ends_on}>
                  {date.format(new Date(cause.ends_on))}
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
        {cause.accepts_zakat && (
          <p className="giving-kicker">{copy.zakatEligible}</p>
        )}
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
        <a
          className="button button-primary"
          href={
            cause.status === "active"
              ? `/${locale}/donate/${slug}`
              : `/${locale}/donate`
          }
        >
          {cause.status === "active" ? copy.donate : copy.otherWays}
        </a>
      </div>
    </article>
  );
}
