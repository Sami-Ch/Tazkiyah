import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { karachiDate } from "@/institutes/manual-donations";
import { getDonationWorkspace } from "@/server/auth";
import { DonationReversalForm } from "./donation-reversal-form";
import { ManualDonationForm } from "./manual-donation-form";
import "../../sign-in/sign-in.css";
import "./manual-donations.css";

export const dynamic = "force-dynamic";

export default async function DonationsPage({
  params,
}: PageProps<"/[locale]/admin/donations">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const adminHref = `/${locale}/admin`;
  const workspace = await getDonationWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(adminHref);
  if (workspace.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.manualDonations;
  const money = new Intl.NumberFormat(`${locale}-PK`, {
    style: "currency",
    currency: "PKR",
    maximumFractionDigits: 0,
  });
  const day = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "medium",
    timeZone: "UTC",
  });
  return (
    <section
      className="shell manual-donations"
      aria-labelledby="manual-donations-title"
    >
      <a href={adminHref}>{copy.back}</a>
      <h1 id="manual-donations-title">{copy.heading}</h1>
      {workspace.state === "allowed" ? (
        <>
          <p>{copy.intro}</p>
          <a href={`/${locale}/admin/donations/reconciliation`}>
            {common.bankReconciliation.heading}
          </a>
          {workspace.banks.length ? (
            <ManualDonationForm
              copy={copy}
              locale={locale}
              today={karachiDate()}
              banks={workspace.banks}
              causes={workspace.causes}
            />
          ) : (
            <p className="manual-donations-notice" role="status">
              {copy.noBanks}
            </p>
          )}
          <section
            className="manual-donation-recent"
            aria-labelledby="recent-transfers-title"
          >
            <h2 id="recent-transfers-title">{copy.recent}</h2>
            {workspace.recent.length ? (
              <ul>
                {workspace.recent.map((gift) => (
                  <li key={gift.id}>
                    <strong>
                      <bdi>{gift.receipt_number}</bdi>
                    </strong>
                    <time dateTime={gift.credited_on}>
                      {day.format(new Date(gift.credited_on + "T00:00:00Z"))}
                    </time>
                    <span>{copy.types[gift.donation_type]}</span>
                    <bdi>{money.format(BigInt(gift.amount_paisa) / 100n)}</bdi>
                  </li>
                ))}
              </ul>
            ) : (
              <p>{copy.noTransfers}</p>
            )}
          </section>
          <DonationReversalForm
            locale={locale}
            copy={common.donationReversal}
            donationCopy={copy}
          />
        </>
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
