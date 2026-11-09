import { routing } from "@tazkiyah/i18n/routing";
import type { Metadata } from "next";
import Image from "next/image";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { LanguageSwitch } from "@/components/language-switch";
import { requireLocale } from "@/i18n/locale";
import { campusMedia, hasCampusSection } from "@/institutes/campus-media";
import { givingCopy } from "@/institutes/giving-copy";
import { institute } from "@/institutes/markaz-al-azeem";
import "./styles.css";

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
  const switchLabels = {
    label: t("navigation.language"),
    accessibleLabel: t("navigation.languageLabel"),
  };

  return (
    <html
      lang={locale}
      dir={locale === "ur" ? "rtl" : "ltr"}
      style={institute.theme}
    >
      <body>
        <a className="skip-link" href="#main">
          {t("navigation.skip")}
        </a>
        <header className="site-header">
          <div className="shell header-inner">
            <a className="wordmark" href={`/${locale}`}>
              <Image
                src={institute.logo.small}
                alt=""
                width={48}
                height={48}
                unoptimized
              />
              <span>
                <strong>{institute.name[locale]}</strong>
                <small>{institute.mosque[locale]}</small>
              </span>
            </a>
            <nav className="site-nav" aria-label={t("navigation.label")}>
              <a href={`/${locale}#about`}>{t("navigation.about")}</a>
              <a href={`/${locale}#community`}>{t("navigation.community")}</a>
              {hasCampusSection(campusMedia) && (
                <a href={`/${locale}#campus`}>{t("campus.label")}</a>
              )}
              <a href={`/${locale}/contact`}>{t("navigation.visit")}</a>
              <a className="site-give" href={`/${locale}/donate`}>
                {givingCopy[locale].label}
              </a>
            </nav>
            <LanguageSwitch locale={locale} {...switchLabels} />
          </div>
        </header>
        <main id="main" tabIndex={-1}>
          {children}
        </main>
        <footer className="site-footer">
          <div className="shell footer-inner">
            <div>
              <p className="footer-name">{institute.name[locale]}</p>
              <p className="footer-platform">{t("footer.platform")}</p>
            </div>
            <LanguageSwitch locale={locale} {...switchLabels} />
          </div>
        </footer>
      </body>
    </html>
  );
}
