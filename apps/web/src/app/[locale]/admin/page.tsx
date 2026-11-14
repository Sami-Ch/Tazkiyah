import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAdminAccess } from "@/server/auth";
import { StaffInvitationForm } from "./staff-invitation-form";
import { TwoFactorSetup } from "./two-factor-setup";
import "../sign-in/sign-in.css";
import "./staff-workspace.css";

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
  const workspace = common.staffWorkspace;
  if (access.state === "allowed") {
    return (
      <section className="shell staff-dashboard" aria-labelledby="admin-title">
        <h1 id="admin-title">{copy.heading}</h1>
        <p className="staff-lead">
          {copy.welcome} <bdi>{access.name}</bdi>. {workspace.intro}
        </p>
        <div className="staff-actions">
          {access.canRecordTransfers && (
            <a
              className="button button-primary"
              href={`/${locale}/admin/donations`}
            >
              {workspace.recordDonation}
            </a>
          )}
          {access.canRecordSpending && (
            <a
              className="button button-outline"
              href={`/${locale}/admin/spending`}
            >
              {workspace.recordSpending}
            </a>
          )}
        </div>
        {access.canInvite && (
          <StaffInvitationForm copy={common.staffInvite} locale={locale} />
        )}
      </section>
    );
  }
  return (
    <section className="shell sign-in-section" aria-labelledby="admin-title">
      <div className="sign-in-card">
        <h1 id="admin-title">{copy.setupHeading}</h1>
        {access.state === "enroll" ? (
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
