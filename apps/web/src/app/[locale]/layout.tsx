import { nightAndPaper } from "@tazkiyah/core/theme";
import { routing } from "@tazkiyah/i18n/routing";
import type { Metadata } from "next";
import { headers } from "next/headers";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { LanguageSwitch } from "@/components/language-switch";
import {
  PatternBand,
  SiteFooter,
  SiteHeader,
  shellLinks,
} from "@/design/shell";
import { themeStyle } from "@/design/theme-style";
import { requireLocale } from "@/i18n/locale";
import { institute } from "@/institutes/markaz-al-azeem";
import { themeFromSettings } from "@/institutes/public-ledger";
import { getPublicOverview, getPublishedInstituteContact } from "@/server/auth";
import "./styles.css";
import "@/design/design.css";

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: LayoutProps<"/[locale]">): Promise<Metadata> {
  const locale = requireLocale((await params).locale);
  const t = await getTranslations({ locale, namespace: "common" });

  return {
    title: `${institute.name[locale]} · ${t("metadata.titleSuffix")}`,
    description: t("home.summary"),
    icons: { icon: { url: institute.logo.small, type: "image/webp" } },
    robots: { index: false, follow: false },
  };
}

export default async function LocaleLayout({
  children,
  params,
}: LayoutProps<"/[locale]">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const t = await getTranslations("common");
  const requestHeaders = new Headers(await headers());
  const [overview, contact] = await Promise.all([
    getPublicOverview(requestHeaders),
    getPublishedInstituteContact(requestHeaders),
  ]);
  const switchLabels = {
    label: t("navigation.language"),
    accessibleLabel: t("navigation.languageLabel"),
  };
  const labels = {
    about: t("navigation.about"),
    causes: t("navigation.causes"),
    transparency: t("navigation.transparency"),
    donorWall: t("navigation.donorWall"),
    studentWork: t("navigation.studentWork"),
    teacherWork: t("navigation.teacherWork"),
    visit: t("navigation.visit"),
  };
  const links = shellLinks(locale, labels, {
    students: overview ? overview.modules.includes("student_hub") : true,
    teachers: overview ? overview.modules.includes("teacher_hub") : true,
  });
  const footerLinks = [
    ...links,
    { href: `/${locale}/sign-in`, label: t("signIn.heading") },
    ...(contact?.phone
      ? [{ href: contact.phone.href, label: contact.phone.label }]
      : []),
    ...(contact?.email
      ? [{ href: contact.email.href, label: contact.email.label }]
      : []),
  ];
  const language = <LanguageSwitch locale={locale} {...switchLabels} />;

  return (
    <html
      lang={locale}
      dir={locale === "ur" ? "rtl" : "ltr"}
      style={themeStyle(themeFromSettings(overview?.theme ?? nightAndPaper))}
    >
      <body>
        <a className="skip-link" href="#main">
          {t("navigation.skip")}
        </a>
        <SiteHeader
          homeHref={`/${locale}`}
          name={institute.name[locale]}
          mosque={institute.mosque[locale]}
          logoSrc={institute.logo.small}
          logoAlt=""
          links={links}
          donateHref={`/${locale}/donate`}
          donateLabel={t("navigation.donate")}
          menuLabel={t("navigation.menu")}
          language={language}
        />
        <PatternBand />
        <main id="main" tabIndex={-1}>
          {children}
        </main>
        <SiteFooter
          name={institute.name[locale]}
          platform={t("footer.platform")}
          address={
            <>
              {institute.mosque[locale]}
              {", "}
              <bdi dir="ltr">{institute.address.roadNumber}</bdi>{" "}
              {institute.address.roadLabel[locale]}
              {", "}
              {contact?.address[locale] ?? institute.address.region[locale]}
            </>
          }
          links={footerLinks}
          language={language}
        />
      </body>
    </html>
  );
}
