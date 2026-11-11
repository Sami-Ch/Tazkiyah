import { requireLocale } from "@/i18n/locale";
import { AccountFormPage } from "../sign-in/account-form-page";

export default async function ForgotPasswordPage({
  params,
}: PageProps<"/[locale]/forgot-password">) {
  return (
    <AccountFormPage
      locale={requireLocale((await params).locale)}
      mode="forgot"
    />
  );
}
