import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { SignInForm } from "./sign-in-form";
import "./sign-in.css";

export default async function SignInPage({
  params,
}: PageProps<"/[locale]/sign-in">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const { common } = await getMessages({ locale });

  return (
    <section className="shell sign-in-section" aria-labelledby="sign-in-title">
      <div className="sign-in-card">
        <h1 id="sign-in-title">{common.signIn.heading}</h1>
        <SignInForm copy={common.signIn} locale={locale} />
      </div>
    </section>
  );
}
