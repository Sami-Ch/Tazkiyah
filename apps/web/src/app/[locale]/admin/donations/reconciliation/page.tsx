import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { karachiDate } from "@/institutes/manual-donations";
import { getStatementWorkspace } from "@/server/auth";
import { BankReconciliation } from "./bank-reconciliation";
import "../../../sign-in/sign-in.css";
import "../manual-donations.css";

export const dynamic = "force-dynamic";

export default async function ReconciliationPage({
  params,
}: PageProps<"/[locale]/admin/donations/reconciliation">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getStatementWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();

  const {
    common: { bankReconciliation: copy },
  } = await getMessages({ locale });
  return (
    <section
      className="shell manual-donations"
      aria-labelledby="reconciliation-title"
    >
      <a href={`/${locale}/admin/donations`}>{copy.back}</a>
      <h1 id="reconciliation-title">{copy.heading}</h1>
      {workspace.state === "allowed" ? (
        workspace.banks.length ? (
          <BankReconciliation
            banks={workspace.banks}
            locale={locale}
            today={karachiDate()}
            copy={copy}
          />
        ) : (
          <p role="status">{copy.noBanks}</p>
        )
      ) : (
        <p role="status">{copy.unavailable}</p>
      )}
    </section>
  );
}
