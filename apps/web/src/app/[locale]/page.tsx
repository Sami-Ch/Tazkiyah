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
import { homeFactKeys, pageTranslation } from "@/institutes/site-pages";
import { readPublishedPages } from "@/server/public-pages";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";

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
  const number = new Intl.NumberFormat(`${locale}-PK`, {
    numberingSystem: "latn",
  });
  const [leadPhoto, ...gallery] = campusMedia.photos;
  const { film, sample } = campusMedia;

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
              lang={homeTitle?.language}
              dir={
                homeTitle
                  ? homeTitle.language === "ur"
                    ? "rtl"
                    : "ltr"
                  : undefined
              }
            >
              {homeTitle?.text ?? institute.name[locale]}
            </h1>
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
            {[homeTitle, homeBody].some(
              (field) => field && field.language !== locale,
            ) && (
              <p className="published-page-note">{t("sitePages.fallback")}</p>
            )}
            <div className="hero-actions">
              <a className="button button-primary" href="#community">
                {t("home.explore")}
                <Icon name="arrow" />
              </a>
              <a
                className="button button-outline"
                href={film ? "#campus-film" : "#visit"}
              >
                <Icon name={film ? "play" : "map"} />
                {film
                  ? t(sample ? "campus.watchSample" : "campus.watch")
                  : t("home.visit")}
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
            <p className="eyebrow">{t("about.label")}</p>
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
              {aboutTitle?.text ?? t("about.heading")}
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
              {aboutBody?.text ?? t("about.body")}
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

        <section
          className="community"
          id="community"
          aria-labelledby="community-title"
        >
          <p className="eyebrow">{t("community.label")}</p>
          <h2 id="community-title">{t("community.heading")}</h2>
          <ul className="service-list">
            {homeFactKeys.map((service) => (
              <li className="service" key={service}>
                <span className="service-icon">
                  <Icon name={service} />
                </span>
                <p className="service-stat">
                  <bdi>{number.format(facts[service].value)}</bdi>
                  {facts[service].label[locale]}
                </p>
                <h3>{t(`community.${service}.title`)}</h3>
                <p>{t(`community.${service}.body`)}</p>
              </li>
            ))}
          </ul>
          <a className="button button-outline" href={`/${locale}/causes`}>
            {t("giving.explore")}
          </a>
        </section>

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
        </section>
      </div>
    </>
  );
}
