import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getBankWorkspace } from "@/server/auth";
import { BankSettingsForms } from "./bank-settings-forms";
import "../../sign-in/sign-in.css";
import "./bank-settings.css";

export const dynamic = "force-dynamic";

export default async function BankAccountsPage({
  params,
}: PageProps<"/[locale]/admin/bank-accounts">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const admin = `/${locale}/admin`;
  const workspace = await getBankWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(admin);
  if (workspace.state === "denied") notFound();
  const { common } = await getMessages({ locale });
  const copy = common.bankSettings;

  return (
    <section
      className="shell bank-settings"
      aria-labelledby="bank-settings-title"
    >
      <a href={admin}>{copy.back}</a>
      <h1 id="bank-settings-title">{copy.heading}</h1>
      {workspace.state === "allowed" ? (
        <>
          <p>{copy.intro}</p>
          <BankSettingsForms
            accounts={workspace.accounts}
            copy={copy}
            locale={locale}
          />
        </>
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
