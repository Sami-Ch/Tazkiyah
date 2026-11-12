"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import Image from "next/image";
import { Fragment, useEffect, useState } from "react";
import { flushSync } from "react-dom";
import { authRequest } from "@/components/auth-request";
import { givingCopy } from "@/institutes/giving-copy";
import { institute } from "@/institutes/markaz-al-azeem";
import { formatPkr, type DonationType } from "@/institutes/manual-donations";
import {
  pageTranslation,
  type LocalizedPageText,
} from "@/institutes/site-pages";
import { donationState } from "./donation-state";
import { trailCopy } from "./trail-copy";

type TrailCursor = { recorded_at: string; id: string };
type TrailEvent = {
  event_type: "received" | "allocated";
  occurred_on: string;
  amount_paisa: string;
  cause_title: LocalizedPageText | null;
};
type TrailDonation = TrailCursor & {
  receipt_number: string;
  credited_on: string;
  amount_paisa: string;
  donation_type: DonationType;
  status: "recorded" | "reversed";
  reversal_reason: string | null;
  receipt_locale: Locale;
  public_ref?: string;
  bank_reference_tail: string | null;
  cause_title: LocalizedPageText | null;
  events: TrailEvent[];
};
type TrailPage = { donations: TrailDonation[]; nextCursor: TrailCursor | null };
type TrailResult =
  | { state: "loading" | "invalid" | "unavailable" }
  | { state: "ready"; page: TrailPage };

const tokenPattern = /^[A-Za-z0-9_-]{43}$/;

function useTrailToken() {
  const [token, setToken] = useState<string | null>(null);
  useEffect(() => {
    function consumeFragment() {
      const fragment = window.location.hash.slice(1);
      if (fragment) {
        // Keep the token out of the URL shown on browser-generated print pages.
        window.history.replaceState(
          window.history.state,
          "",
          window.location.pathname + window.location.search,
        );
      }
      setToken(tokenPattern.test(fragment) ? fragment : "");
    }

    const initial = window.setTimeout(consumeFragment, 0);
    window.addEventListener("hashchange", consumeFragment);
    return () => {
      window.clearTimeout(initial);
      window.removeEventListener("hashchange", consumeFragment);
    };
  }, []);
  return token;
}

async function readTrail(
  token: string | undefined,
  donationRef: string | undefined,
  cursor: TrailCursor | null,
  signal: AbortSignal,
): Promise<TrailResult> {
  try {
    const response = await fetch(
      token ? "/api/auth/donor-trail" : "/api/auth/account-trail",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token,
          donationRef,
          cursor: cursor ?? undefined,
        }),
        cache: "no-store",
        credentials: token ? "omit" : "same-origin",
        mode: "same-origin",
        redirect: "error",
        referrerPolicy: "no-referrer",
        signal,
      },
    );
    if (
      response.status === 404 ||
      response.status === 400 ||
      response.status === 403
    )
      return { state: "invalid" };
    if (!response.ok) return { state: "unavailable" };
    const page: TrailPage = await response.json();
    return Array.isArray(page?.donations)
      ? { state: "ready", page }
      : { state: "unavailable" };
  } catch {
    return { state: "unavailable" };
  }
}

function TrailDate({
  value,
  locale,
  issueDate = false,
}: {
  value: string;
  locale: Locale;
  issueDate?: boolean;
}) {
  const formatted = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "long",
    timeZone: issueDate ? "Asia/Karachi" : "UTC",
  }).format(new Date(value));
  return <time dateTime={value}>{formatted}</time>;
}

function CauseTitle({
  title,
  locale,
}: {
  title: LocalizedPageText | null;
  locale: Locale;
}) {
  const translated = pageTranslation(title ?? undefined, locale);
  return translated ? (
    <bdi lang={translated.language}>{translated.text}</bdi>
  ) : (
    trailCopy[locale].allNeeds
  );
}

function Receipt({ donation }: { donation: TrailDonation }) {
  const preferred = donation.receipt_locale;
  const alternate = preferred === "en" ? "ur" : "en";
  return (
    <section className="trail-receipt">
      <Image
        src={institute.logo.small}
        width={72}
        height={72}
        alt=""
        unoptimized
        loading="eager"
      />
      <div className="trail-receipt-languages">
        {([preferred, alternate] as const).map((locale) => {
          const copy = trailCopy[locale];
          return (
            <section
              key={locale}
              lang={locale}
              dir={locale === "ur" ? "rtl" : "ltr"}
            >
              <h2>{institute.name[locale]}</h2>
              <address>
                <bdi dir="ltr">{institute.address.roadNumber}</bdi>{" "}
                {institute.address.roadLabel[locale]},{" "}
                {institute.address.region[locale]}
              </address>
              <h3>{copy.receipt}</h3>
              <p>{copy.anonymous}</p>
              {donation.status === "reversed" && (
                <p className="trail-cancelled">{copy.cancelledNotice}</p>
              )}
              <dl>
                <div>
                  <dt>{copy.receiptNumber}</dt>
                  <dd>
                    <bdi dir="ltr">{donation.receipt_number}</bdi>
                  </dd>
                </div>
                <div>
                  <dt>{copy.amount}</dt>
                  <dd>
                    <bdi>{formatPkr(donation.amount_paisa, locale)}</bdi>
                  </dd>
                </div>
                <div>
                  <dt>{copy.credited}</dt>
                  <dd>
                    <TrailDate value={donation.credited_on} locale={locale} />
                  </dd>
                </div>
                <div>
                  <dt>{copy.issued}</dt>
                  <dd>
                    <TrailDate
                      value={donation.recorded_at}
                      locale={locale}
                      issueDate
                    />
                  </dd>
                </div>
                <div>
                  <dt>{copy.cause}</dt>
                  <dd>
                    <CauseTitle title={donation.cause_title} locale={locale} />
                  </dd>
                </div>
                <div>
                  <dt>{copy.type}</dt>
                  <dd>{givingCopy[locale].purposes[donation.donation_type]}</dd>
                </div>
                {donation.bank_reference_tail && (
                  <div>
                    <dt>{copy.referenceTail}</dt>
                    <dd>
                      <bdi dir="ltr">{donation.bank_reference_tail}</bdi>
                    </dd>
                  </div>
                )}
              </dl>
              <p>{copy.taxNotice}</p>
              {donation.public_ref && (
                <a href={`/${locale}/account/donations/${donation.public_ref}`}>
                  {copy.viewTrail}
                </a>
              )}
            </section>
          );
        })}
      </div>
    </section>
  );
}

// Fills {name} slots in a translated sentence with rendered parts, so
// amounts and cause titles keep their own direction inside Urdu text.
function Sentence({
  template,
  parts,
}: {
  template: string;
  parts: Record<string, React.ReactNode>;
}) {
  return template
    .split(/(\{[a-z]+\})/)
    .map((piece, index) =>
      /^\{[a-z]+\}$/.test(piece) ? (
        <Fragment key={index}>{parts[piece.slice(1, -1)]}</Fragment>
      ) : (
        piece
      ),
    );
}

function DonationStateLine({
  donation,
  locale,
}: {
  donation: TrailDonation;
  locale: Locale;
}) {
  const copy = trailCopy[locale];
  const state = donationState(donation);
  const money = (value: bigint) => (
    <bdi>{formatPkr(value.toString(), locale)}</bdi>
  );
  const causes = (titles: (LocalizedPageText | null)[]) =>
    titles.map((title, index) => (
      <Fragment key={index}>
        {index > 0 && copy.causeSeparator}
        <CauseTitle title={title} locale={locale} />
      </Fragment>
    ));
  let line: React.ReactNode;
  switch (state.kind) {
    case "awaiting_split":
      line = copy.stateAwaitingSplit;
      break;
    case "partly_allocated":
      line = (
        <Sentence
          template={copy.statePartlyAllocated}
          parts={{
            assigned: money(state.assigned),
            waiting: money(state.waiting),
            causes: causes(state.causes),
          }}
        />
      );
      break;
    case "allocated":
      line = (
        <Sentence
          template={copy.stateAllocated}
          parts={{ causes: causes(state.causes) }}
        />
      );
      break;
    case "partly_spent":
      line = (
        <Sentence
          template={copy.statePartlySpent}
          parts={{ spent: money(state.spent), total: money(state.total) }}
        />
      );
      break;
    case "spent":
      line = copy.stateSpent;
      break;
    case "reported":
      line = copy.stateReported;
      break;
    case "reversed":
      line = state.reason ? (
        <Sentence
          template={copy.stateReversedBecause}
          parts={{ reason: copy[`reason_${state.reason}`] }}
        />
      ) : (
        copy.stateReversed
      );
      break;
  }
  return <p className="trail-state">{line}</p>;
}

function DonationRecord({
  donation,
  locale,
  printable,
  onPrint,
  showTrailLink,
}: {
  donation: TrailDonation;
  locale: Locale;
  printable: boolean;
  onPrint: () => void;
  showTrailLink: boolean;
}) {
  const copy = trailCopy[locale];
  return (
    <article
      className="trail-record"
      data-print-current={printable || undefined}
    >
      <div className="trail-record-screen">
        <header className="trail-record-heading">
          <div>
            <p className="eyebrow">{copy.receipt}</p>
            <h3>
              <bdi dir="ltr">{donation.receipt_number}</bdi>
            </h3>
          </div>
          <strong
            className={
              donation.status === "reversed" ? "trail-cancelled" : undefined
            }
          >
            {copy[donation.status]}
          </strong>
        </header>
        <DonationStateLine donation={donation} locale={locale} />
        <dl className="trail-donation-facts">
          <div>
            <dt>{copy.amount}</dt>
            <dd>
              <bdi>{formatPkr(donation.amount_paisa, locale)}</bdi>
            </dd>
          </div>
          <div>
            <dt>{copy.credited}</dt>
            <dd>
              <TrailDate value={donation.credited_on} locale={locale} />
            </dd>
          </div>
          <div>
            <dt>{copy.cause}</dt>
            <dd>
              <CauseTitle title={donation.cause_title} locale={locale} />
            </dd>
          </div>
          <div>
            <dt>{copy.type}</dt>
            <dd>{givingCopy[locale].purposes[donation.donation_type]}</dd>
          </div>
        </dl>
        {donation.events.length > 0 && (
          <details className="trail-events">
            <summary>{copy.activity}</summary>
            <ol>
              {donation.events.map((event, index) => (
                <li key={index}>
                  <strong>{copy[event.event_type]}</strong>
                  <p>
                    <TrailDate value={event.occurred_on} locale={locale} />
                    {" · "}
                    <bdi>{formatPkr(event.amount_paisa, locale)}</bdi>
                    {event.event_type === "allocated" && (
                      <>
                        {" · "}
                        <CauseTitle title={event.cause_title} locale={locale} />
                      </>
                    )}
                  </p>
                </li>
              ))}
            </ol>
          </details>
        )}
        <button
          type="button"
          className="button button-outline"
          aria-label={`${copy.printReceipt} ${donation.receipt_number}`}
          onClick={onPrint}
        >
          {copy.printReceipt}
        </button>
        {showTrailLink && donation.public_ref && (
          <a
            className="button button-outline"
            href={`/${locale}/account/donations/${donation.public_ref}`}
          >
            {copy.viewTrail}
          </a>
        )}
      </div>
      <Receipt donation={donation} />
    </article>
  );
}

function TrailResults({
  locale,
  token,
  donationRef,
}: {
  locale: Locale;
  token?: string;
  donationRef?: string;
}) {
  const copy = trailCopy[locale];
  const [cursors, setCursors] = useState<(TrailCursor | null)[]>([null]);
  const [retry, setRetry] = useState(0);
  const [result, setResult] = useState<TrailResult>({ state: "loading" });
  const [printId, setPrintId] = useState<string>();
  const cursor = cursors[cursors.length - 1];
  const nextCursor = result.state === "ready" ? result.page.nextCursor : null;

  useEffect(() => {
    const request = new AbortController();
    void readTrail(token, donationRef, cursor, request.signal).then(
      (loaded) => {
        if (!request.signal.aborted) setResult(loaded);
      },
    );
    return () => request.abort();
  }, [token, donationRef, cursor, retry]);

  useEffect(() => {
    const clear = () => setPrintId(undefined);
    window.addEventListener("afterprint", clear);
    return () => window.removeEventListener("afterprint", clear);
  }, []);

  function moveTo(next: (TrailCursor | null)[]) {
    setPrintId(undefined);
    setResult({ state: "loading" });
    setCursors(next);
  }

  function printReceipt(id: string) {
    flushSync(() => setPrintId(id));
    window.print();
  }

  return (
    <div className="trail-results" aria-busy={result.state === "loading"}>
      {result.state === "ready" ? (
        result.page.donations.length ? (
          <section
            className="trail-records"
            aria-labelledby="trail-records-title"
          >
            <h2 id="trail-records-title">{copy.donations}</h2>
            {result.page.donations.map((donation) => (
              <DonationRecord
                key={donation.id}
                donation={donation}
                locale={locale}
                printable={printId === donation.id}
                onPrint={() => printReceipt(donation.id)}
                showTrailLink={!token && !donationRef}
              />
            ))}
          </section>
        ) : (
          <div className="trail-message">
            <p role="status">{token ? copy.empty : copy.accountEmpty}</p>
            {!token && (
              <a href={`/${locale}/donate`}>{givingCopy[locale].label}</a>
            )}
          </div>
        )
      ) : (
        <div className="trail-message">
          <p role="status">
            {!token && result.state === "invalid"
              ? copy.accountUnavailable
              : copy[result.state]}
          </p>
          {result.state === "unavailable" && (
            <button
              type="button"
              className="button button-outline"
              onClick={() => {
                setResult({ state: "loading" });
                setRetry(retry + 1);
              }}
            >
              {copy.retry}
            </button>
          )}
          {result.state === "invalid" && (
            <a href={`/${locale}/${token ? "contact" : "account"}`}>
              {token ? copy.contact : copy.accountBack}
            </a>
          )}
        </div>
      )}
      {(cursors.length > 1 || nextCursor) && result.state !== "invalid" && (
        <nav className="trail-pagination" aria-label={copy.pages}>
          <button
            type="button"
            className="button button-outline"
            disabled={cursors.length === 1 || result.state === "loading"}
            onClick={() => moveTo(cursors.slice(0, -1))}
          >
            {copy.previous}
          </button>
          <p role="status">
            {copy.page} {new Intl.NumberFormat(locale).format(cursors.length)}
          </p>
          <button
            type="button"
            className="button button-outline"
            disabled={!nextCursor}
            onClick={() => nextCursor && moveTo([...cursors, nextCursor])}
          >
            {copy.next}
          </button>
        </nav>
      )}
    </div>
  );
}

export function DonorTrail({ locale }: { locale: Locale }) {
  const token = useTrailToken();
  const copy = trailCopy[locale];
  const alternate = locale === "en" ? "ur" : "en";
  const alternateCopy = trailCopy[alternate];

  return (
    <div className="trail-client">
      <div className="trail-toolbar">
        <p>{copy.privacy}</p>
        <a href={`/${locale}/signup`}>{copy.createAccount}</a>
        <a
          className="button button-outline"
          href={`/${alternate}/trail${token ? `#${token}` : ""}`}
          hrefLang={alternate}
          lang={alternate}
          dir={alternate === "ur" ? "rtl" : "ltr"}
          aria-label={alternateCopy.language}
          rel="noreferrer"
        >
          {alternateCopy.languageName}
        </a>
      </div>
      {token === null ? (
        <p className="trail-message trail-loading" role="status">
          {copy.loading}
        </p>
      ) : token ? (
        <TrailResults key={token} locale={locale} token={token} />
      ) : (
        <div className="trail-message">
          <p>{copy.invalid}</p>
          <a href={`/${locale}/contact`}>{copy.contact}</a>
        </div>
      )}
    </div>
  );
}

export function AccountDonorTrail({
  locale,
  donationRef,
}: {
  locale: Locale;
  donationRef?: string;
}) {
  const copy = trailCopy[locale];
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");
  const [version, setVersion] = useState(0);

  async function claim() {
    if (busy) return;
    setBusy(true);
    setNotice("");
    try {
      const response = await authRequest("claim-guest-donations", {});
      const result: { code?: string } = await response.json();
      if (response.ok && result.code === "claimed") {
        setNotice(copy.claimed);
        setVersion((previous) => previous + 1);
      } else if (response.ok && result.code === "none") {
        setNotice(copy.noClaim);
      } else {
        setNotice(
          result.code === "conflict"
            ? copy.claimConflict
            : copy.claimUnavailable,
        );
      }
    } catch {
      setNotice(copy.claimUnavailable);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="trail-client">
      {!donationRef && (
        <div className="trail-toolbar">
          <button
            className="button button-outline"
            type="button"
            disabled={busy}
            onClick={() => void claim()}
          >
            {busy ? copy.claiming : copy.claim}
          </button>
          {notice && <p role="status">{notice}</p>}
        </div>
      )}
      <TrailResults key={version} locale={locale} donationRef={donationRef} />
    </div>
  );
}
