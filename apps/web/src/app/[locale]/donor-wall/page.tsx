import { routing } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { formatDate } from "@/design/format";
import { nextPageHref } from "@/design/paging";
import { Amount, Button, EmptyState } from "@/design/ui";
import { requireLocale } from "@/i18n/locale";
import { institute } from "@/institutes/markaz-al-azeem";
import { pageTranslation } from "@/institutes/site-pages";
import { getDonorWall, getPublicOverview } from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";

export const dynamic = "force-dynamic";

function one(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/donor-wall">) {
  const locale = requireLocale((await params).locale);
  const t = await getTranslations({ locale, namespace: "common" });
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: "/donor-wall",
    title: `${t("public.donorWallTitle")} · ${institute.name[locale]}`,
    description: t("public.donorWallIntro"),
  });
}

export default async function DonorWallPage({
  params,
  searchParams,
}: PageProps<"/[locale]/donor-wall">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const t = await getTranslations("common.public");
  const query = await searchParams;
  const cause = one(query.cause);
  const month = one(query.month);
  const shown = one(query.shown);
  const requestHeaders = new Headers(await headers());
  const filters = new URLSearchParams();
  if (cause) filters.set("cause", cause);
  if (month) filters.set("month", month);
  if (shown) filters.set("shown", shown);
  const [wall, overview] = await Promise.all([
    getDonorWall(requestHeaders, filters),
    getPublicOverview(requestHeaders),
  ]);

  return (
    <section className="shell public-stack" aria-labelledby="donor-wall-title">
      <header className="public-intro">
        <h1 id="donor-wall-title">{t("donorWallTitle")}</h1>
        <p>{t("donorWallIntro")}</p>
      </header>
      <form className="filter-row" method="get">
        {cause && <input type="hidden" name="cause" value={cause} />}
        <label className="ui-field" htmlFor="donor-month">
          {t("filterMonth")}
          <input
            id="donor-month"
            name="month"
            type="month"
            defaultValue={month}
          />
        </label>
        <button className="ui-button ui-button-secondary" type="submit">
          {t("apply")}
        </button>
      </form>
      <nav className="filter-row" aria-label={t("filterCause")}>
        <a
          href={`/${locale}/donor-wall`}
          aria-current={!cause ? "true" : undefined}
        >
          {t("filterAll")}
        </a>
        {overview?.causes.map((item) => {
          const title = pageTranslation(item.title, locale);
          return (
            <a
              key={item.id}
              href={`/${locale}/donor-wall?cause=${item.slug}`}
              aria-current={cause === item.slug ? "true" : undefined}
            >
              {title?.text ?? item.slug}
            </a>
          );
        })}
      </nav>
      {wall.items.length === 0 ? (
        <EmptyState title={t("donorWallTitle")}>
          {t("donorWallEmpty")}
        </EmptyState>
      ) : (
        <ul className="wall-list">
          {wall.items.map((entry) => {
            const title = pageTranslation(
              entry.cause_title ?? undefined,
              locale,
            );
            return (
              <li className="wall-row" key={entry.public_ref}>
                <Amount paisa={entry.amount_paisa} locale={locale} />
                <bdi>{entry.donor_label ?? t("anonymous")}</bdi>
                <span>
                  {entry.cause_slug ? (
                    <a href={`/${locale}/causes/${entry.cause_slug}`}>
                      {title?.text ?? t("filterCause")}
                    </a>
                  ) : (
                    t("allNeeds")
                  )}
                </span>
                <time dateTime={entry.given_on}>
                  {formatDate(entry.given_on, locale)}
                </time>
              </li>
            );
          })}
        </ul>
      )}
      {wall.hasMore && (
        <Button
          href={nextPageHref(
            `/${locale}/donor-wall`,
            { cause, month, shown },
            Number(shown && /^\d+$/.test(shown) ? shown : 20) + 20,
          )}
          variant="secondary"
        >
          {t("showMore")}
        </Button>
      )}
    </section>
  );
}
