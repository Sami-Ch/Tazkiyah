import type { Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { getAccountAccess } from "@/server/auth";
import { AccountDonorTrail } from "../../trail/donor-trail";
import { trailCopy } from "../../trail/trail-copy";
import "../../trail/trail.css";

export async function AccountDonations({
  locale,
  donationRef,
}: {
  locale: Locale;
  donationRef?: string;
}) {
  setRequestLocale(locale);
  const account = await getAccountAccess(new Headers(await headers()));
  if (account.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (account.state === "enroll") redirect(`/${locale}/admin`);
  if (account.state === "allowed" && account.mustChangePassword)
    redirect(`/${locale}/account`);
  if (account.state === "allowed" && !account.roles.includes("donor"))
    notFound();

  const copy = trailCopy[locale];
  return (
    <section
      className="shell private-trail"
      aria-labelledby="account-donations-title"
    >
      <header className="trail-heading">
        <a href={`/${locale}/account${donationRef ? "/donations" : ""}`}>
          {donationRef ? copy.accountList : copy.accountBack}
        </a>
        <h1 id="account-donations-title">
          {donationRef ? copy.viewTrail : copy.accountTitle}
        </h1>
      </header>
      {account.state === "allowed" ? (
        <AccountDonorTrail locale={locale} donationRef={donationRef} />
      ) : (
        <p role="status">{copy.unavailable}</p>
      )}
    </section>
  );
}
