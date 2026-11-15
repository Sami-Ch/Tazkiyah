import Image from "next/image";
import { headers } from "next/headers";
import { routing } from "@tazkiyah/i18n/routing";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { Icon } from "@/components/icon";
import {
  CampusCredit,
  CampusMovie,
  CampusPicture,
} from "@/components/campus-media";
import { requireLocale } from "@/i18n/locale";
import { campusMedia, hasCampusSection } from "@/institutes/campus-media";
import { institute } from "@/institutes/markaz-al-azeem";
import { defaultHomeFacts } from "@/institutes/home-facts";
import { pageTranslation } from "@/institutes/site-pages";
import { readPublishedPages } from "@/server/public-pages";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import { AddressMap } from "@/components/address-map";
import { StarRule } from "@/design/ornament";
import { showSampleBadge } from "@/institutes/public-story";
import { HomeLedger } from "./home-ledger";
import { HomeStory } from "./home-story";

export async function generateMetadata({ params }: PageProps<"/[locale]">) {
  const locale = requireLocale((await params).locale);
  const [t, pages, requestHeaders] = await Promise.all([
    getTranslations({ locale, namespace: "common" }),
    readPublishedPages(),
    headers(),
  ]);
  const introduction = pages.find(({ slug }) => slug === "home");
  const title = introduction?.title[locale] ?? institute.name[locale];
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(requestHeaders)),
    locale,
    locales: routing.locales,
    title: `${title} · ${t("metadata.titleSuffix")}`,
    description: introduction?.body[locale] ?? t("home.summary"),
  });
}

const trustItems = [
  ["shield", "story.chipTraced"],
  ["coins", "story.chipFees"],
  ["scale", "story.chipZakat"],
] as const;

export default async function Home({ params }: PageProps<"/[locale]">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const t = await getTranslations("common");
  const pages = await readPublishedPages();
  const introduction = pages.find(({ slug }) => slug === "home");
  const facts = introduction?.facts ?? defaultHomeFacts;
  const about = pages.find(({ slug }) => slug === "about");
  const homeTitle = pageTranslation(introduction?.title, locale);
  const homeBody = pageTranslation(introduction?.body, locale);
  const aboutTitle = pageTranslation(about?.title, locale);
  const aboutBody = pageTranslation(about?.body, locale);
  const additionalPages = pages.filter(
    ({ slug }) => slug === "facilities" || slug === "daily-life",
  );
  const [leadPhoto, ...gallery] = campusMedia.photos;
  const { film, sample } = campusMedia;
  const namedTitle =
    homeTitle?.text === institute.name.en ||
    homeTitle?.text === institute.name.ur;
  const headline = homeTitle && !namedTitle ? homeTitle : undefined;
  const number = new Intl.NumberFormat(`${locale}-PK`, {
    numberingSystem: "latn",
  });
  const heroFacts = (["education", "meals", "clinic"] as const).map((key) => ({
    key,
    value: facts[key].value,
    label: facts[key].label[locale],
  }));
  const direction = (language?: string) =>
    language ? (language === "ur" ? "rtl" : "ltr") : undefined;

  return (
    <>
      <section className="hero" aria-labelledby="hero-title">
        <div className="hero-ornament" aria-hidden="true" />
        <div className="shell hero-inner">
          <div className="hero-copy">
            <p className="eyebrow hero-eyebrow">
              {t("home.location")}
              <span>{t("home.established")}</span>
            </p>
            <h1
              id="hero-title"
              lang={headline?.language}
              dir={direction(headline?.language)}
            >
              {headline?.text ?? t("story.heroHeadline")}
            </h1>
            <p className="hero-tagline">{t("story.heroTagline")}</p>
            <p
              className="hero-summary published-page-copy"
              lang={homeBody?.language}
              dir={direction(homeBody?.language)}
            >
              {homeBody?.text ?? t("home.summary")}
            </p>
            {[headline, homeBody].some(
              (field) => field && field.language !== locale,
            ) && (
              <p className="published-page-note">{t("sitePages.fallback")}</p>
            )}
            <div className="hero-actions">
              <a className="button button-primary" href={`/${locale}/donate`}>
                {t("navigation.donate")}
                <Icon name="arrow" />
              </a>
              <a
                className="button button-outline"
                href={film ? "#campus-film" : `/${locale}/causes`}
              >
                <Icon name={film ? "play" : "arrow"} />
                {film
                  ? t(sample ? "campus.watchSample" : "campus.watch")
                  : t("giving.explore")}
              </a>
            </div>
            <ul className="hero-stats">
              {heroFacts.map((fact) => (
                <li key={fact.key}>
                  <bdi>{number.format(fact.value)}</bdi>
                  <span>{fact.label}</span>
                </li>
              ))}
            </ul>
          </div>
          {leadPhoto ? (
            <figure className="hero-visual hero-photo">
              <div className="hero-frame">
                <CampusPicture photo={leadPhoto} locale={locale} lead />
                {sample && (
                  <span className="sample-badge">
                    {t("campus.samplePhoto")}
                  </span>
                )}
              </div>
              <figcaption>
                {leadPhoto.caption[locale]}
                {leadPhoto.credit && (
                  <CampusCredit
                    credit={leadPhoto.credit}
                    resized={t("campus.resized")}
                  />
                )}
              </figcaption>
            </figure>
          ) : (
            <div className="hero-visual hero-emblem">
              <div className="hero-frame hero-frame-emblem">
                <picture>
                  <source
                    type="image/webp"
                    srcSet={`${institute.logo.standard} 192w, ${institute.logo.medium} 384w, ${institute.logo.large} 512w`}
                    sizes="(min-width: 960px) 260px, 192px"
                  />
                  <Image
                    src={institute.logo.standard}
                    width={192}
                    height={192}
                    alt={t("home.emblem")}
                    loading="eager"
                    fetchPriority="high"
                    unoptimized
                  />
                </picture>
              </div>
              <p className="emblem-caption">{institute.mosque[locale]}</p>
            </div>
          )}
        </div>
      </section>

      <section className="trust-strip" aria-label={t("story.programmesLabel")}>
        <ul className="shell trust-strip-inner">
          {trustItems.map(([icon, label]) => (
            <li key={icon} className="trust-item">
              <span className="trust-icon">
                <Icon name={icon} />
              </span>
              <span>{t(label)}</span>
            </li>
          ))}
        </ul>
      </section>

      <div className="shell content">
        <section className="about" id="about" aria-labelledby="about-title">
          <div>
            <p className="eyebrow">{t("story.missionLabel")}</p>
            <h2
              id="about-title"
              lang={aboutTitle?.language}
              dir={direction(aboutTitle?.language)}
            >
              {aboutTitle?.text ?? t("story.missionHeading")}
            </h2>
            <StarRule />
            {[aboutTitle, aboutBody].some(
              (field) => field && field.language !== locale,
            ) && (
              <p className="published-page-note">{t("sitePages.fallback")}</p>
            )}
          </div>
          <div className="about-copy">
            <p
              className="published-page-copy"
              lang={aboutBody?.language}
              dir={direction(aboutBody?.language)}
            >
              {aboutBody?.text ?? t("story.missionBody")}
            </p>
            {additionalPages.length > 0 && (
              <div className="published-page-links">
                {additionalPages.map(({ slug }) => (
                  <a
                    key={slug}
                    className="button button-outline"
                    href={`/${locale}/${slug}`}
                  >
                    {t(`sitePages.slugs.${slug}`)}
                    <Icon name="arrow" />
                  </a>
                ))}
              </div>
            )}
          </div>
        </section>

        <HomeStory locale={locale} />

        <HomeLedger locale={locale} />

        {hasCampusSection(campusMedia) && (
          <section
            className="campus"
            id="campus"
            aria-labelledby="campus-title"
          >
            <div className="section-intro">
              <p className="eyebrow">{t("campus.label")}</p>
              <h2 id="campus-title">
                {t(sample ? "campus.previewHeading" : "campus.heading")}
              </h2>
              {sample && (
                <p className="campus-note">{t("campus.previewNote")}</p>
              )}
            </div>
            {film && (
              <figure className="campus-film" id="campus-film">
                <CampusMovie
                  film={film}
                  locale={locale}
                  playLabel={t("campus.play", { title: film.title[locale] })}
                  captionLabels={{
                    en: t("campus.captionsEn"),
                    ur: t("campus.captionsUr"),
                  }}
                />
                <figcaption>
                  {film.title[locale]}
                  {film.kind === "youtube" && (
                    <a
                      className="media-credit"
                      href={`https://www.youtube.com/watch?v=${encodeURIComponent(film.videoId)}`}
                    >
                      {t("campus.openYouTube")}
                    </a>
                  )}
                </figcaption>
              </figure>
            )}
            {gallery.length > 0 && (
              <div className="campus-gallery">
                {gallery.map((photo) => (
                  <figure key={photo.src}>
                    <CampusPicture photo={photo} locale={locale} />
                    <figcaption>
                      {photo.caption[locale]}
                      {photo.credit && (
                        <CampusCredit
                          credit={photo.credit}
                          resized={t("campus.resized")}
                        />
                      )}
                    </figcaption>
                  </figure>
                ))}
              </div>
            )}
          </section>
        )}

        <section className="visit" id="visit" aria-labelledby="visit-title">
          <div className="visit-info">
            <p className="eyebrow">{t("visit.label")}</p>
            <h2 id="visit-title">{t("visit.heading")}</h2>
            <address>
              <strong>{institute.mosque[locale]}</strong>
              <br />
              <bdi dir="ltr">{institute.address.roadNumber}</bdi>{" "}
              {institute.address.roadLabel[locale]}
              <br />
              {institute.address.region[locale]}
            </address>
            <div className="visit-hours">
              <span className="trust-icon">
                <Icon name="clock" />
              </span>
              <div>
                <h3>{t("story.hoursLabel")}</h3>
                <p>{t("story.hoursBody")}</p>
                {showSampleBadge() && (
                  <p className="sample-flag">{t("story.sampleBadge")}</p>
                )}
              </div>
            </div>
            <div className="visit-actions">
              <a className="button button-primary" href={institute.mapUrl}>
                <Icon name="map" />
                {t("visit.directions")}
              </a>
              <a className="button button-outline" href={`/${locale}/contact`}>
                {t("navigation.visit")}
              </a>
            </div>
          </div>
          <div className="visit-map">
            <AddressMap
              query={`${institute.mosque.en}, ${institute.address.roadNumber} ${institute.address.roadLabel.en}, ${institute.address.region.en}`}
              title={t("story.mapTitle")}
            />
          </div>
        </section>
      </div>
      <section className="give-band" aria-labelledby="give-band-title">
        <div className="give-band-ornament" aria-hidden="true" />
        <div className="shell give-band-inner">
          <div>
            <p className="eyebrow">{t("story.zakatLabel")}</p>
            <h2 id="give-band-title">{t("story.ctaHeading")}</h2>
            <p>{t("story.ctaBody")}</p>
          </div>
          <div className="give-band-actions">
            <a className="button button-primary" href={`/${locale}/donate`}>
              {t("story.ctaButton")}
              <Icon name="arrow" />
            </a>
            <a className="button button-outline" href={`/${locale}/causes`}>
              {t("giving.explore")}
            </a>
          </div>
        </div>
      </section>
    </>
  );
}
