import { routing, type Locale } from "@tazkiyah/i18n/routing";
import type { MetadataRoute } from "next";
import { headers } from "next/headers";
import { publishedCauseLocales } from "@/institutes/causes";
import { getPublishedCauses, getPublishedSitePages } from "@/server/auth";
import {
  languageAlternates,
  localeUrl,
  publicSiteOrigin,
  publishedLocales,
} from "@/server/public-site";

export const dynamic = "force-dynamic";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const requestHeaders = new Headers(await headers());
  const origin = publicSiteOrigin(requestHeaders);
  if (!origin) return [];

  const entries = (
    path: string,
    locales: readonly Locale[],
  ): MetadataRoute.Sitemap => {
    const languages = languageAlternates(origin, locales, path);
    return locales.map((locale) => ({
      url: localeUrl(origin, locale, path),
      alternates: { languages },
    }));
  };

  const [pages, causes] = await Promise.all([
    getPublishedSitePages(requestHeaders),
    getPublishedCauses(requestHeaders),
  ]);
  return [
    ...entries("", routing.locales),
    ...entries("/contact", routing.locales),
    ...entries("/causes", routing.locales),
    ...entries("/donate", routing.locales),
    ...pages
      .filter(({ slug }) => slug !== "home")
      .flatMap((page) => entries(`/${page.slug}`, publishedLocales(page))),
    ...causes.flatMap((cause) =>
      entries(`/causes/${cause.slug}`, publishedCauseLocales(cause)),
    ),
  ];
}
