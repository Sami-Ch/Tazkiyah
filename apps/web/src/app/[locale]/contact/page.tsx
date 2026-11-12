import { routing, type Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { setRequestLocale } from "next-intl/server";
import { Icon } from "@/components/icon";
import { requireLocale } from "@/i18n/locale";
import { contactCopy, contactMethods } from "@/institutes/contact";
import { institute } from "@/institutes/markaz-al-azeem";
import { getPublishedInstituteContact } from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import "./contact.css";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/contact">) {
  const locale = requireLocale((await params).locale);
  const copy = contactCopy[locale];
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: "/contact",
    title: `${copy.title} · ${institute.name[locale]}`,
    description: copy.intro,
  });
}

function fallbackAddress(locale: Locale) {
  return (
    <>
      <bdi dir="ltr">{institute.address.roadNumber}</bdi>{" "}
      {institute.address.roadLabel[locale]}, {institute.address.region[locale]}
    </>
  );
}

export default async function ContactPage({
  params,
}: PageProps<"/[locale]/contact">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const copy = contactCopy[locale];
  const contact = await getPublishedInstituteContact(
    new Headers(await headers()),
  );
  const methods = contactMethods.filter((method) => contact?.[method]);
  const languages = [locale, locale === "en" ? "ur" : "en"] as const;
  const configuredLanguages = languages.filter(
    (language) => contact?.address[language],
  );
  const addressLanguages = configuredLanguages.length
    ? configuredLanguages
    : languages;
  const addressQuery = contact?.address.en || contact?.address.ur;
  const directions =
    contact?.mapUrl ??
    (addressQuery
      ? `https://www.google.com/maps/search/?${new URLSearchParams({ api: "1", query: addressQuery })}`
      : institute.mapUrl);

  return (
    <section className="shell contact-page" aria-labelledby="contact-title">
      <a className="contact-back" href={`/${locale}`}>
        {copy.back}
      </a>
      <header className="contact-heading">
        <h1 id="contact-title">{copy.title}</h1>
        <p>{copy.intro}</p>
      </header>
      <div className="contact-grid">
        <section
          className="contact-card contact-location"
          aria-labelledby="contact-location"
        >
          <p className="contact-kicker">
            <Icon name="map" />
            {copy.location}
          </p>
          <h2 id="contact-location">{institute.mosque[locale]}</h2>
          <address aria-label={copy.address}>
            {addressLanguages.map((language) => (
              <p
                key={language}
                lang={language}
                dir={language === "ur" ? "rtl" : "ltr"}
              >
                {contact?.address[language] ?? fallbackAddress(language)}
              </p>
            ))}
          </address>
          <a className="button button-outline" href={directions}>
            <Icon name="map" />
            {copy.directions}
          </a>
        </section>
        {methods.length > 0 && (
          <section className="contact-card" aria-labelledby="contact-reach">
            <h2 id="contact-reach">{copy.reachUs}</h2>
            <ul className="contact-methods" role="list">
              {methods.map((method) => {
                const channel = contact?.[method];
                if (!channel) return null;
                return (
                  <li key={method}>
                    <a href={channel.href}>
                      <strong>{copy[method]}</strong>
                      <bdi dir="ltr">{channel.label}</bdi>
                    </a>
                  </li>
                );
              })}
            </ul>
          </section>
        )}
      </div>
    </section>
  );
}
