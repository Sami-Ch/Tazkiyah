import type { Locale } from "@tazkiyah/i18n/routing";
import { getMessages, setRequestLocale } from "next-intl/server";
import { AccountForm, type AccountFormMode } from "./account-form";
import "./sign-in.css";

export async function AccountFormPage({
  locale,
  mode,
  token,
}: {
  locale: Locale;
  mode: AccountFormMode;
  token?: string;
}) {
  setRequestLocale(locale);
  const {
    common: { account, signIn },
  } = await getMessages({ locale });
  const heading =
    mode === "signup"
      ? signIn.createDonorAccount
      : mode === "forgot"
        ? account.recoveryHeading
        : account.choosePassword;
  const intro =
    mode === "signup"
      ? account.signupIntro
      : mode === "forgot"
        ? account.recoveryIntro
        : mode === "first"
          ? account.firstPassword
          : undefined;
  return (
    <section className="shell sign-in-section" aria-labelledby="account-title">
      <div className="sign-in-card">
        <h1 id="account-title">{heading}</h1>
        {intro && <p>{intro}</p>}
        <AccountForm
          mode={mode}
          locale={locale}
          token={token}
          copy={account}
          signIn={signIn}
        />
      </div>
    </section>
  );
}
