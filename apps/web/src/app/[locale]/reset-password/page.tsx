import { requireLocale } from "@/i18n/locale";
import { AccountFormPage } from "../sign-in/account-form-page";

export default async function ResetPasswordPage({
  params,
  searchParams,
}: PageProps<"/[locale]/reset-password">) {
  const locale = requireLocale((await params).locale);
  const { token, error } = await searchParams;
  const resetToken =
    !error && typeof token === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(token)
      ? token
      : undefined;
  return <AccountFormPage locale={locale} mode="reset" token={resetToken} />;
}
