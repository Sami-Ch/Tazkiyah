import { routing, type Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { causeCopy } from "@/institutes/cause-copy";
import type { PublishedCause } from "@/institutes/causes";
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
    <ul className="giving-grid" role="list">
      {causes.map((cause) => {
        const title = pageTranslation(cause.title, locale);
        const summary = pageTranslation(cause.summary, locale);
        if (!title || !summary) return null;
        return (
          <li className="giving-card" key={cause.id}>
            <p className="giving-kicker">{copy.kinds[cause.cause_type]}</p>
            <Heading
              lang={title.language}
              dir={title.language === "ur" ? "rtl" : "ltr"}
            >
              {title.text}
            </Heading>
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
            <a
              className="button button-outline"
              href={`/${locale}/causes/${cause.slug}`}
            >
              {copy.view}
              <span className="visually-hidden" lang={title.language}>
                {" "}
                {title.text}
              </span>
            </a>
          </li>
        );
      })}
    </ul>
  );
}

export default async function CausesPage({
  params,
}: PageProps<"/[locale]/causes">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const copy = causeCopy[locale];
  const causes = await getPublishedCauses(new Headers(await headers()));
  const current = causes.filter(({ status }) => status !== "archived");
  const past = causes.filter(({ status }) => status === "archived");

  return (
    <section
      className="shell giving-causes"
      aria-labelledby="giving-causes-title"
    >
      <a className="giving-back" href={`/${locale}`}>
        {copy.backHome}
      </a>
      <header className="giving-heading">
        <h1 id="giving-causes-title">{copy.title}</h1>
        <p>{copy.intro}</p>
      </header>
      {current.length > 0 && <CauseGrid causes={current} locale={locale} />}
      {past.length > 0 && (
        <section className="giving-past" aria-labelledby="past-causes-title">
          <h2 id="past-causes-title">{copy.past}</h2>
          <CauseGrid causes={past} locale={locale} past />
        </section>
      )}
      {causes.length === 0 && <p className="giving-card">{copy.noCauses}</p>}
    </section>
  );
}
