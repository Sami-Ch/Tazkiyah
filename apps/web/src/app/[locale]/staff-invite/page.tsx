import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { AuthFrame } from "../sign-in/auth-frame";
import { AcceptStaffInvitation } from "./accept-staff-invitation";

export default async function StaffInvitationPage({
  params,
}: PageProps<"/[locale]/staff-invite">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const { common } = await getMessages({ locale });
  const { staffInvite: copy } = common;

  return (
    <AuthFrame locale={locale} labelledBy="staff-setup-title">
      <h1 id="staff-setup-title">{copy.setupHeading}</h1>
      <AcceptStaffInvitation copy={copy} signInHref={`/${locale}/sign-in`} />
    </AuthFrame>
  );
}
