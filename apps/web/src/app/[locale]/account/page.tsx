import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { Icon } from "@/components/icon";
import { requireLocale } from "@/i18n/locale";
import { getAccountAccess, getDonorProfileWorkspace } from "@/server/auth";
import { AccountFormPage } from "../sign-in/account-form-page";
import { sponsorCopy } from "./sponsorship/sponsor-copy";
import { hubCopy } from "../hub/hub-copy";
import { ReplayHelp } from "./replay-help";
import { SignOutButton } from "./sign-out-button";
import { trailCopy } from "../trail/trail-copy";
import "./account.css";

export const dynamic = "force-dynamic";

export default async function AccountPage({
  params,
  searchParams,
}: PageProps<"/[locale]/account">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const access = await getAccountAccess(new Headers(await headers()));
  if (access.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (access.state === "enroll") redirect(`/${locale}/admin`);

  const profile =
    access.state === "allowed" && access.roles.includes("donor")
      ? await getDonorProfileWorkspace(new Headers(await headers()))
      : null;
  const { common } = await getMessages({ locale });
  const { account, admin, signIn } = common;
  const staff =
    access.state === "allowed" &&
    access.roles.some(
      (role) =>
        role === "admin" || role === "finance_officer" || role === "editor",
    );
  if (access.state === "allowed" && access.mustChangePassword) {
    return <AccountFormPage locale={locale} mode="first" />;
  }
  if ((await searchParams).continue === "1" && access.state === "allowed") {
    redirect(`/${locale}/${staff ? "admin" : "account"}`);
  }

  if (access.state !== "allowed") {
    return (
      <section className="shell account" aria-labelledby="account-title">
        <header className="public-intro">
          <h1 id="account-title">{account.heading}</h1>
          <p role="status">{account.unavailable}</p>
        </header>
        <a href={`/${locale}/sign-in`}>{signIn.backToSignIn}</a>
      </section>
    );
  }

  const isDonor = access.roles.includes("donor");
  const member = access.roles.some(
    (role) => role === "student" || role === "teacher" || role === "admin",
  );
  const spaces = [
    ...(staff
      ? [
          {
            href: `/${locale}/admin`,
            icon: "grid",
            title: admin.heading,
            blurb: account.cards.admin,
          } as const,
        ]
      : []),
    ...(isDonor
      ? [
          {
            href: `/${locale}/account/donations`,
            icon: "receipt",
            title: trailCopy[locale].accountTitle,
            blurb: account.cards.donations,
          } as const,
          {
            href: `/${locale}/account/sponsorship`,
            icon: "heart",
            title: sponsorCopy[locale].title,
            blurb: account.cards.sponsorship,
          } as const,
        ]
      : []),
    ...(profile?.state === "allowed"
      ? [
          {
            href: `/${locale}/account/profile`,
            icon: "user",
            title: account.publicProfile,
            blurb: account.cards.profile,
          } as const,
        ]
      : []),
    ...(member
      ? [
          {
            href: `/${locale}/hub`,
            icon: "chat",
            title: hubCopy[locale].title,
            blurb: account.cards.hub,
          } as const,
        ]
      : []),
  ];
  const initial = Array.from(access.name.trim())[0] ?? "";

  return (
    <section className="shell account" aria-labelledby="account-title">
      <header className="account-head">
        <div className="account-avatar" aria-hidden="true">
          <span>{initial}</span>
        </div>
        <div className="account-identity">
          <p className="eyebrow">{account.heading}</p>
          <h1 id="account-title">
            <bdi>{access.name}</bdi>
          </h1>
          {access.email && (
            <p className="account-email">
              <bdi dir="ltr">{access.email}</bdi>
            </p>
          )}
          <ul className="account-roles" aria-label={account.heading}>
            {access.roles.map((role) => (
              <li key={role} className="ui-badge ui-badge-verified">
                {account.roles[role]}
              </li>
            ))}
          </ul>
        </div>
        <div className="account-tools">
          <SignOutButton
            label={signIn.signOut}
            busyLabel={signIn.loading}
            signInHref={`/${locale}/sign-in`}
          />
        </div>
      </header>

      {spaces.length > 0 && (
        <section className="account-spaces" aria-labelledby="account-spaces">
          <h2 id="account-spaces">{account.spaces}</h2>
          <ul className="account-grid">
            {spaces.map((space) => (
              <li key={space.href}>
                <a href={space.href}>
                  <span className="account-card-icon" aria-hidden="true">
                    <Icon name={space.icon} />
                  </span>
                  <strong>{space.title}</strong>
                  <p>{space.blurb}</p>
                  <span className="account-card-arrow" aria-hidden="true">
                    <Icon name="arrow" />
                  </span>
                </a>
              </li>
            ))}
          </ul>
        </section>
      )}

      {access.roles.some((role) => role === "student" || role === "teacher") && (
        <div className="account-footer">
          <ReplayHelp locale={locale} />
        </div>
      )}
    </section>
  );
}
