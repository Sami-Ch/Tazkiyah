import { routing } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { formatDate } from "@/design/format";
import { Amount, Badge, DataTable, EmptyState } from "@/design/ui";
import { requireLocale } from "@/i18n/locale";
import { institute } from "@/institutes/markaz-al-azeem";
import { pageTranslation } from "@/institutes/site-pages";
import { getPublicOverview } from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/transparency">) {
  const locale = requireLocale((await params).locale);
  const t = await getTranslations({ locale, namespace: "common" });
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: "/transparency",
    title: `${t("public.transparencyTitle")} · ${institute.name[locale]}`,
    description: t("public.transparencyIntro"),
  });
}

export default async function TransparencyPage({
  params,
}: PageProps<"/[locale]/transparency">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const t = await getTranslations("common.public");
  const overview = await getPublicOverview(new Headers(await headers()));
  const causes = overview?.causes ?? [];
  const name = (id: string) =>
    pageTranslation(causes.find((cause) => cause.id === id)?.title, locale)
      ?.text ?? "";

  return (
    <section
      className="shell public-stack"
      aria-labelledby="transparency-title"
    >
      <header className="public-intro">
        <h1 id="transparency-title">{t("transparencyTitle")}</h1>
        <p>{t("transparencyIntro")}</p>
      </header>
      {causes.length === 0 ? (
        <EmptyState title={t("transparencyTitle")}>
          {t("noSpendingYet")}
        </EmptyState>
      ) : (
        <DataTable
          columns={[
            { key: "cause", label: t("filterCause") },
            { key: "raised", label: t("raised") },
            { key: "spent", label: t("spent") },
            { key: "unspent", label: t("unspent") },
          ]}
          rows={causes.map((cause) => {
            const title = pageTranslation(cause.title, locale);
            return {
              cause: (
                <a href={`/${locale}/causes/${cause.slug}`}>
                  {title?.text ?? cause.slug}
                </a>
              ),
              raised: (
                <Amount paisa={cause.lifetime_raised_paisa} locale={locale} />
              ),
              spent: <Amount paisa={cause.spent_paisa} locale={locale} />,
              unspent: <Amount paisa={cause.unspent_paisa} locale={locale} />,
            };
          })}
        />
      )}
      <section aria-labelledby="published-spending">
        <h2 id="published-spending">{t("whereMoneyWent")}</h2>
        {(overview?.spending.length ?? 0) === 0 ? (
          <p>{t("noSpendingYet")}</p>
        ) : (
          <ul className="wall-list">
            {overview?.spending.map((entry) => {
              const description = pageTranslation(entry.description, locale);
              return (
                <li className="wall-row" key={entry.id}>
                  <span>{name(entry.cause_id)}</span>
                  <time dateTime={entry.spent_on}>
                    {formatDate(entry.spent_on, locale)}
                  </time>
                  <Amount paisa={entry.amount_paisa} locale={locale} />
                  {entry.status === "reversed" && (
                    <Badge tone="warning">{t("corrected")}</Badge>
                  )}
                  {description && <p>{description.text}</p>}
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </section>
  );
}
