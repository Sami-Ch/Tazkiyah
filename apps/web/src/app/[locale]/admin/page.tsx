import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAdminAccess } from "@/server/auth";
import { StaffInvitationForm } from "./staff-invitation-form";
import { TwoFactorSetup } from "./two-factor-setup";
import "../sign-in/sign-in.css";

export const dynamic = "force-dynamic";

export default async function AdminPage({
  params,
}: PageProps<"/[locale]/admin">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const access = await getAdminAccess(new Headers(await headers()));
  const signInHref = `/${locale}/sign-in`;
  if (access.state === "signed-out") redirect(signInHref);

  const { common } = await getMessages({ locale });
  const { admin: copy } = common;
  return (
    <section className="shell sign-in-section" aria-labelledby="admin-title">
      <div className="sign-in-card">
        <h1 id="admin-title">
          {access.state === "enroll" ? copy.setupHeading : copy.heading}
        </h1>
        {access.state === "allowed" ? (
          <>
            <p>
              {copy.welcome} <bdi>{access.name}</bdi>
            </p>
            {access.twoFactorVerified && <p>{copy.verified}</p>}
            {access.canEditPages && (
              <a
                className="button button-outline"
                href={`/${locale}/admin/pages`}
              >
                {common.sitePages.heading}
              </a>
            )}
            {access.canRecordTransfers && (
              <a
                className="button button-primary"
                href={`/${locale}/admin/donations`}
              >
                {common.manualDonations.heading}
              </a>
            )}
            {access.canInvite && (
              <>
                <a
                  className="button button-outline"
                  href={`/${locale}/admin/users`}
                >
                  {common.staffDirectory.heading}
                </a>
                <a
                  className="button button-outline"
                  href={`/${locale}/admin/causes`}
                >
                  {common.giving.manage}
                </a>
                <a
                  className="button button-outline"
                  href={`/${locale}/admin/audit`}
                >
                  {common.auditLog.heading}
                </a>
                <a
                  className="button button-outline"
                  href={`/${locale}/admin/bank-accounts`}
                >
                  {common.bankSettings.heading}
                </a>
                <a
                  className="button button-outline"
                  href={`/${locale}/admin/donor-links`}
                >
                  {common.donorLinks.heading}
                </a>
                <StaffInvitationForm
                  copy={common.staffInvite}
                  locale={locale}
                />
              </>
            )}
          </>
        ) : access.state === "enroll" ? (
          <TwoFactorSetup copy={copy} workspaceHref={`/${locale}/admin`} />
        ) : (
          <p>
            {access.state === "denied"
              ? copy.denied
              : common.signIn.unavailable}
          </p>
        )}
        <a href={signInHref}>{common.signIn.backToSignIn}</a>
      </div>
    </section>
  );
}
