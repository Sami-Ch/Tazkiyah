import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { AuthFrame } from "./auth-frame";
import { SignInForm } from "./sign-in-form";

export default async function SignInPage({
  params,
}: PageProps<"/[locale]/sign-in">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const { common } = await getMessages({ locale });

  return (
    <AuthFrame locale={locale} labelledBy="sign-in-title">
      <h1 id="sign-in-title">{common.signIn.heading}</h1>
      <SignInForm copy={common.signIn} locale={locale} />
    </AuthFrame>
  );
}
