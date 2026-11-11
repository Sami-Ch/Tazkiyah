import { requireLocale } from "@/i18n/locale";
import { AccountFormPage } from "../sign-in/account-form-page";

export default async function SignupPage({
  params,
}: PageProps<"/[locale]/signup">) {
  return (
    <AccountFormPage
      locale={requireLocale((await params).locale)}
      mode="signup"
    />
  );
}
