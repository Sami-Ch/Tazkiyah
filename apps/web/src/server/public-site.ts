import { getCloudflareContext } from "@opennextjs/cloudflare";
import { routing, type Locale } from "@tazkiyah/i18n/routing";
import type { Metadata } from "next";
import { institute } from "@/institutes/markaz-al-azeem";
import type { PublishedSitePage } from "@/institutes/site-pages";
import { authOriginHeader, forwardedHttpsOrigin } from "./auth-origin";

type PublicBindings = { PUBLIC_SITE_ORIGINS?: string };

function workerBindings(): PublicBindings | undefined {
  try {
    return getCloudflareContext().env as PublicBindings;
  } catch {
    return undefined;
  }
}

function secureOrigin(value: string | null) {
  if (!value || !URL.canParse(value)) return undefined;
  const url = new URL(value);
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash
  ) {
    return undefined;
  }
  return url.origin;
}

export function publicSiteOrigin(requestHeaders: Headers) {
  const bindings = workerBindings();
  const configured =
    bindings?.PUBLIC_SITE_ORIGINS ?? process.env.PUBLIC_SITE_ORIGINS;
  if (!configured) return undefined;

  const origin = bindings
    ? secureOrigin(requestHeaders.get(authOriginHeader))
    : forwardedHttpsOrigin(requestHeaders);

  return origin &&
    configured.split(",").some((value) => secureOrigin(value.trim()) === origin)
    ? origin
    : undefined;
}

export function publishedLocales(page: PublishedSitePage) {
  return routing.locales.filter(
    (locale) => page.title[locale]?.trim() && page.body[locale]?.trim(),
  );
}

export function localeUrl(origin: string, locale: Locale, path = "") {
  return new URL(`/${locale}${path}`, origin).href;
}

export function languageAlternates(
  origin: string,
  locales: readonly Locale[],
  path = "",
) {
  const links = Object.fromEntries(
    locales.map((locale) => [locale, localeUrl(origin, locale, path)]),
  );
  const preferred = locales.includes(routing.defaultLocale)
    ? routing.defaultLocale
    : locales[0];
  return preferred
    ? { ...links, "x-default": localeUrl(origin, preferred, path) }
    : links;
}

function descriptionExcerpt(value: string) {
  const characters = [...value.trim().replace(/\s+/g, " ")];
  return characters.length > 160
    ? `${characters.slice(0, 159).join("").trimEnd()}…`
    : characters.join("");
}

export function publicPageMetadata({
  origin,
  locale,
  locales,
  path = "",
  title,
  description: rawDescription,
}: {
  origin: string | undefined;
  locale: Locale;
  locales: readonly Locale[];
  path?: string;
  title: string;
  description: string;
}): Metadata {
  const description = descriptionExcerpt(rawDescription);
  if (!origin || !locales.includes(locale)) {
    return { title, description, robots: { index: false, follow: false } };
  }

  const canonical = localeUrl(origin, locale, path);
  const logo = new URL(institute.logo.large, origin).href;
  return {
    title,
    description,
    robots: { index: true, follow: true },
    alternates: {
      canonical,
      languages: languageAlternates(origin, locales, path),
    },
    openGraph: {
      type: "website",
      title,
      description,
      url: canonical,
      siteName: institute.name[locale],
      locale: `${locale}_PK`,
      alternateLocale: locales
        .filter((language) => language !== locale)
        .map((language) => `${language}_PK`),
      images: [
        { url: logo, width: 512, height: 512, alt: institute.name[locale] },
      ],
    },
    twitter: { card: "summary", title, description, images: [logo] },
  };
}
