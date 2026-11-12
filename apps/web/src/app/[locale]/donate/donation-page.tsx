import type { Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { setRequestLocale } from "next-intl/server";
import { Icon } from "@/components/icon";
import { givingCopy } from "@/institutes/giving-copy";
import { donationPurposes, type DonationPurpose } from "@/institutes/giving";
import { institute } from "@/institutes/markaz-al-azeem";
import { pageTranslation } from "@/institutes/site-pages";
import { getPublishedBankAccounts, getPublishedCauses } from "@/server/auth";
import { CopyBankField } from "./copy-bank-field";
import "./donate.css";

function donationHref(locale: Locale, purpose: DonationPurpose, slug?: string) {
  const path = slug ? `/${locale}/donate/${slug}` : `/${locale}/donate`;
  return purpose === "general" ? path : `${path}?type=${purpose}`;
}

export async function DonationPage({
  locale,
  slug,
  requestedPurpose,
}: {
  locale: Locale;
  slug?: string;
  requestedPurpose?: string | string[];
}) {
  setRequestLocale(locale);
  const copy = givingCopy[locale];
  const purpose =
    donationPurposes.find((type) => type === requestedPurpose) ?? "general";
  const requestHeaders = new Headers(await headers());
  const [bankAccounts, causes] = await Promise.all([
    getPublishedBankAccounts(requestHeaders),
    getPublishedCauses(requestHeaders),
  ]);
  const active = causes.filter((cause) => cause.status === "active");
  const available = active.filter(
    (cause) => purpose !== "zakat" || cause.accepts_zakat,
  );
  const selected = available.find((cause) => cause.slug === slug);
  const accounts = bankAccounts.filter((account) =>
    account.for_donation_types.includes(purpose),
  );

  return (
    <article className="shell donate" aria-labelledby="donate-title">
      <header className="donate-heading">
        <p className="eyebrow">{institute.name[locale]}</p>
        <h1 id="donate-title">{copy.title}</h1>
        <p>{copy.intro}</p>
      </header>
      <div className="donate-grid">
        <section className="donate-panel" aria-labelledby="donate-purpose">
          <h2 id="donate-purpose">{copy.purpose}</h2>
          <ul className="donate-purposes" role="list">
            {donationPurposes.map((type) => (
              <li key={type}>
                <a
                  className="button button-outline"
                  href={donationHref(
                    locale,
                    type,
                    type === "zakat" && !selected?.accepts_zakat
                      ? undefined
                      : selected?.slug,
                  )}
                  aria-current={type === purpose || undefined}
                >
                  {copy.purposes[type]}
                </a>
              </li>
            ))}
          </ul>
          {purpose === "zakat" && (
            <p className="donate-note">{copy.zakatNote}</p>
          )}
          <h2 id="donate-cause">{copy.cause}</h2>
          {slug && !selected && (
            <p className="donate-note">{copy.causeUnavailable}</p>
          )}
          <ul
            className="donate-causes"
            aria-labelledby="donate-cause"
            role="list"
          >
            <li>
              <a
                href={donationHref(locale, purpose)}
                aria-current={!selected || undefined}
              >
                {copy.allNeeds}
              </a>
            </li>
            {available.map((cause) => {
              const title = pageTranslation(cause.title, locale);
              if (!title) return null;
              return (
                <li key={cause.id}>
                  <a
                    href={donationHref(locale, purpose, cause.slug)}
                    aria-current={cause.id === selected?.id || undefined}
                  >
                    <bdi lang={title.language}>{title.text}</bdi>
                  </a>
                </li>
              );
            })}
          </ul>
          <a className="donate-explore" href={`/${locale}/causes`}>
            {copy.exploreCauses}
          </a>
        </section>
        <section className="donate-panel" aria-labelledby="donate-accounts">
          <h2 id="donate-accounts">{copy.accounts}</h2>
          {accounts.length ? (
            <>
              <p>{copy.transferNote}</p>
              {accounts.map((account) => {
                const label = pageTranslation(account.label, locale);
                const fields = [
                  { label: copy.bank, value: account.bank_name },
                  { label: copy.accountTitle, value: account.account_title },
                  {
                    label: copy.accountNumber,
                    value: account.account_number,
                    numeric: true,
                  },
                  { label: copy.iban, value: account.iban, numeric: true },
                  { label: copy.branch, value: account.branch },
                ];
                return (
                  <div className="donate-bank-card" key={account.id}>
                    <h3>
                      {label ? (
                        <bdi lang={label.language}>{label.text}</bdi>
                      ) : (
                        account.bank_name
                      )}
                    </h3>
                    <dl>
                      {fields.map(({ label, value, numeric }) =>
                        value?.trim() ? (
                          <CopyBankField
                            key={label}
                            label={label}
                            value={value}
                            numeric={numeric}
                            copy={copy.copy}
                            copied={copy.copied}
                            copyError={copy.copyError}
                          />
                        ) : null,
                      )}
                    </dl>
                  </div>
                );
              })}
            </>
          ) : (
            <p>
              {bankAccounts.length ? copy.noMatchingAccounts : copy.noAccounts}
            </p>
          )}
          <a className="button button-primary" href={`/${locale}/contact`}>
            <Icon name="map" />
            {copy.visit}
          </a>
        </section>
      </div>
    </article>
  );
}
