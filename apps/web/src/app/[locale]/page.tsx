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

  return (
    <>
      <section className="hero" aria-labelledby="hero-title">
        <div className="shell hero-inner">
          <div className="hero-copy">
            <p className="eyebrow hero-eyebrow">
              {t("home.location")}
              <span>{t("home.established")}</span>
            </p>
            <h1
              id="hero-title"
              lang={headline?.language}
              dir={
                headline
                  ? headline.language === "ur"
                    ? "rtl"
                    : "ltr"
                  : undefined
              }
            >
              {headline?.text ?? t("story.heroHeadline")}
            </h1>
            <p className="hero-tagline">{t("story.heroTagline")}</p>
            <p
              className="hero-summary published-page-copy"
              lang={homeBody?.language}
              dir={
                homeBody
                  ? homeBody.language === "ur"
                    ? "rtl"
                    : "ltr"
                  : undefined
              }
            >
              {homeBody?.text ?? t("home.summary")}
            </p>
            {[headline, homeBody].some(
              (field) => field && field.language !== locale,
            ) && (
              <p className="published-page-note">{t("sitePages.fallback")}</p>
            )}
            <ul className="hero-chips">
              <li>{t("story.chipTraced")}</li>
              <li>{t("story.chipFees")}</li>
              <li>{t("story.chipZakat")}</li>
            </ul>
            <ul className="hero-stats">
              {heroFacts.map((fact) => (
                <li key={fact.key}>
                  <bdi>{number.format(fact.value)}</bdi>
                  <span>{fact.label}</span>
                </li>
              ))}
            </ul>
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
          </div>
          {leadPhoto ? (
            <figure className="hero-visual hero-photo">
              <CampusPicture photo={leadPhoto} locale={locale} lead />
              {sample && (
                <span className="sample-badge">{t("campus.samplePhoto")}</span>
              )}
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
              <div className="hero-medallion">
                <svg
                  className="medallion-frame"
                  viewBox="0 0 400 400"
                  aria-hidden="true"
                >
                  <g fill="none" stroke="currentColor">
                    <path d="M200 14 258 64 336 64 336 142 386 200 336 258 336 336 258 336 200 386 142 336 64 336 64 258 14 200 64 142 64 64 142 64Z" />
                    <path d="M200 30 320 80 370 200 320 320 200 370 80 320 30 200 80 80Z" />
                    <circle cx="200" cy="200" r="155" />
                  </g>
                  <g fill="currentColor">
                    <path d="M200 2 206 14 200 26 194 14ZM200 374 206 386 200 398 194 386Z" />
                    <path d="M2 200 14 194 26 200 14 206ZM374 200 386 194 398 200 386 206Z" />
                  </g>
                </svg>
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

      <div className="shell content">
        <section className="about" id="about" aria-labelledby="about-title">
          <div>
            <p className="eyebrow">{t("story.missionLabel")}</p>
            <StarRule />
            <h2
              id="about-title"
              lang={aboutTitle?.language}
              dir={
                aboutTitle
                  ? aboutTitle.language === "ur"
                    ? "rtl"
                    : "ltr"
                  : undefined
              }
            >
              {aboutTitle?.text ?? t("story.missionHeading")}
            </h2>
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
              dir={
                aboutBody
                  ? aboutBody.language === "ur"
                    ? "rtl"
                    : "ltr"
                  : undefined
              }
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
            <p className="eyebrow">{t("campus.label")}</p>
            <h2 id="campus-title">
              {t(sample ? "campus.previewHeading" : "campus.heading")}
            </h2>
            {sample && <p className="campus-note">{t("campus.previewNote")}</p>}
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
          <div>
            <p className="eyebrow">{t("visit.label")}</p>
            <h2 id="visit-title">{t("visit.heading")}</h2>
            <address>
              {institute.mosque[locale]}
              <br />
              <bdi dir="ltr">{institute.address.roadNumber}</bdi>{" "}
              {institute.address.roadLabel[locale]}
              <br />
              {institute.address.region[locale]}
            </address>
          </div>
          <div className="visit-actions">
            <a className="button button-outline" href={`/${locale}/contact`}>
              {t("navigation.visit")}
            </a>
            <a className="button button-primary" href={institute.mapUrl}>
              <Icon name="map" />
              {t("visit.directions")}
            </a>
          </div>
          <div className="visit-extra">
            {showSampleBadge() && (
              <p className="sample-flag">{t("story.sampleBadge")}</p>
            )}
            <h3>{t("story.hoursLabel")}</h3>
            <p>{t("story.hoursBody")}</p>
            <AddressMap
              query={`${institute.mosque.en}, ${institute.address.roadNumber} ${institute.address.roadLabel.en}, ${institute.address.region.en}`}
              title={t("story.mapTitle")}
            />
          </div>
        </section>
      </div>
      <section className="give-band" aria-labelledby="give-band-title">
        <div className="shell give-band-inner">
          <div>
            <h2 id="give-band-title">{t("story.ctaHeading")}</h2>
            <p>{t("story.ctaBody")}</p>
          </div>
          <a className="button button-primary" href={`/${locale}/donate`}>
            {t("story.ctaButton")}
            <Icon name="arrow" />
          </a>
        </div>
      </section>
    </>
  );
}
