import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { institute } from "@/institutes/markaz-al-azeem";
import { isSitePageSlug, pageTranslation } from "@/institutes/site-pages";
import { readPublishedPages } from "@/server/public-pages";
import {
  publicPageMetadata,
  publicSiteOrigin,
  publishedLocales,
} from "@/server/public-site";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/[contentPage]">) {
  const { locale: requestedLocale, contentPage } = await params;
  const locale = requireLocale(requestedLocale);
  if (!isSitePageSlug(contentPage) || contentPage === "home") return {};

  const [pages, requestHeaders] = await Promise.all([
    readPublishedPages(),
    headers(),
  ]);
  const page = pages.find(({ slug }) => slug === contentPage);
  if (!page) return {};
  const title = pageTranslation(page.title, locale)?.text;
  const description = pageTranslation(page.body, locale)?.text;
  if (!title || !description) return {};

  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(requestHeaders)),
    locale,
    locales: publishedLocales(page),
    path: `/${page.slug}`,
    title: `${title} · ${institute.name[locale]}`,
    description,
  });
}

export default async function PublishedPage({
  params,
}: PageProps<"/[locale]/[contentPage]">) {
  const { locale: requestedLocale, contentPage } = await params;
  const locale = requireLocale(requestedLocale);
  setRequestLocale(locale);
  if (!isSitePageSlug(contentPage) || contentPage === "home") notFound();

  const pages = await readPublishedPages();
  const page = pages.find(({ slug }) => slug === contentPage);
  const title = pageTranslation(page?.title, locale);
  const body = pageTranslation(page?.body, locale);
  if (!title || !body) notFound();

  const t = await getTranslations("common.sitePages");
  return (
    <article
      className="shell published-page"
      aria-labelledby="public-page-title"
    >
      <a href={`/${locale}`}>{t("backHome")}</a>
      <h1
        id="public-page-title"
        lang={title.language}
        dir={title.language === "ur" ? "rtl" : "ltr"}
      >
        {title.text}
      </h1>
      {(title.language !== locale || body.language !== locale) && (
        <p className="published-page-note">{t("fallback")}</p>
      )}
      <p
        className="published-page-copy"
        lang={body.language}
        dir={body.language === "ur" ? "rtl" : "ltr"}
      >
        {body.text}
      </p>
    </article>
  );
}
