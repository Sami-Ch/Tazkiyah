import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { formatAmount } from "@/design/format";
import { getAdminAccess, getPublicOverview } from "@/server/auth";
import { Button } from "@/design/ui";
import { AuthFrame } from "../sign-in/auth-frame";
import { StaffInvitationForm } from "./staff-invitation-form";
import { staffLinks, type StaffLinkId } from "./staff-links";
import { StaffOverview } from "./staff-overview";
import { SetupChecklist } from "./setup-checklist";
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
  const workspace = common.staffWorkspace;
  if (access.state === "allowed") {
    const overview = await getPublicOverview(new Headers(await headers()));
    const active = overview?.causes.filter(
      (cause) => cause.status === "active",
    );
    const raised = active?.reduce(
      (sum, cause) => sum + BigInt(cause.raised_paisa),
      0n,
    );
    const stats =
      active && raised !== undefined
        ? [
            {
              label: workspace.stats.causes,
              value: String(active.length),
            },
            {
              label: workspace.stats.raised,
              value: formatAmount(raised, locale),
            },
            {
              label: workspace.stats.zakat,
              value: String(active.filter((cause) => cause.accepts_zakat).length),
            },
          ]
        : [];
    const actions =
      access.canRecordTransfers || access.canRecordSpending ? (
        <>
          {access.canRecordTransfers && (
            <Button href={`/${locale}/admin/donations`}>
              {workspace.recordDonation}
            </Button>
          )}
          {access.canRecordSpending && (
            <Button href={`/${locale}/admin/spending`} variant="secondary">
              {workspace.recordSpending}
            </Button>
          )}
        </>
      ) : undefined;
    return (
      <section className="staff-stack" aria-labelledby="admin-title">
        <StaffOverview
          heading={copy.heading}
          eyebrow={workspace.navLabel}
          welcome={copy.welcome}
          name={access.name}
          intro={workspace.intro}
          links={staffLinks(locale, access)}
          names={workspace.links as Record<StaffLinkId, string>}
          blurbs={workspace.blurbs}
          groups={workspace.groups}
          stats={stats}
          actions={actions}
        />
        <SetupChecklist locale={locale} />
        {access.canInvite && (
          <StaffInvitationForm copy={common.staffInvite} locale={locale} />
        )}
      </section>
    );
  }
  return (
    <AuthFrame locale={locale} labelledBy="admin-title">
      <h1 id="admin-title">{copy.setupHeading}</h1>
      {access.state === "enroll" ? (
        <TwoFactorSetup copy={copy} workspaceHref={`/${locale}/admin`} />
      ) : (
        <p className="sign-in-intro">
          {access.state === "denied" ? copy.denied : common.signIn.unavailable}
        </p>
      )}
      <a href={signInHref}>{common.signIn.backToSignIn}</a>
    </AuthFrame>
  );
}
