import type { Locale } from "@tazkiyah/i18n/routing";
import { getMessages, setRequestLocale } from "next-intl/server";
import { AccountForm, type AccountFormMode } from "./account-form";
import { AuthFrame } from "./auth-frame";

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
    <AuthFrame locale={locale} labelledBy="account-title">
      <h1 id="account-title">{heading}</h1>
      {intro && <p className="sign-in-intro">{intro}</p>}
      <AccountForm
        mode={mode}
        locale={locale}
        token={token}
        copy={account}
        signIn={signIn}
      />
    </AuthFrame>
  );
}
