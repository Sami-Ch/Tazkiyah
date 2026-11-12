import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { AcceptStaffInvitation } from "./accept-staff-invitation";
import "../sign-in/sign-in.css";

export default async function StaffInvitationPage({
  params,
}: PageProps<"/[locale]/staff-invite">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const { common } = await getMessages({ locale });
  const { staffInvite: copy } = common;

  return (
    <section
      className="shell sign-in-section"
      aria-labelledby="staff-setup-title"
    >
      <div className="sign-in-card">
        <h1 id="staff-setup-title">{copy.setupHeading}</h1>
        <AcceptStaffInvitation copy={copy} signInHref={`/${locale}/sign-in`} />
      </div>
    </section>
  );
}
