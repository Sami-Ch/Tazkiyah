import type { Locale } from "@tazkiyah/i18n/routing";

export const sitePageSlugs = [
  "home",
  "about",
  "facilities",
  "daily-life",
] as const;
export type SitePageSlug = (typeof sitePageSlugs)[number];
export type LocalizedPageText = Partial<Record<Locale, string>>;

export const homeFactKeys = ["education", "meals", "clinic"] as const;
export const maxHomeFactValue = 999_999;
export type HomeFacts = Record<
  (typeof homeFactKeys)[number],
  { value: number; label: Record<Locale, string> }
>;

export type PublishedSitePage = {
  slug: SitePageSlug;
  title: LocalizedPageText;
  body: LocalizedPageText;
  facts: HomeFacts | null;
};

export type EditableSitePage = {
  slug: SitePageSlug;
  title: LocalizedPageText | null;
  body: LocalizedPageText | null;
  facts: HomeFacts | null;
  revision: string | null;
  pending: boolean;
  published: boolean;
};

export function isSitePageSlug(value: unknown): value is SitePageSlug {
  return sitePageSlugs.some((slug) => slug === value);
}

export function pageTranslation(
  text: LocalizedPageText | undefined,
  locale: Locale,
) {
  const alternate = locale === "en" ? "ur" : "en";
  if (text?.[locale]) return { text: text[locale], language: locale };
  if (text?.[alternate]) return { text: text[alternate], language: alternate };
  return undefined;
}
