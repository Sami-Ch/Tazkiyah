import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAccountAccess } from "@/server/auth";
import { AccountFormPage } from "../sign-in/account-form-page";
import "../sign-in/sign-in.css";

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

  return (
    <section className="shell sign-in-section" aria-labelledby="account-title">
      <div className="sign-in-card">
        <h1 id="account-title">{account.heading}</h1>
        {access.state === "allowed" ? (
          <>
            <p>
              <bdi>{access.name}</bdi>
            </p>
            {access.email && (
              <p>
                <bdi>{access.email}</bdi>
              </p>
            )}
            <p>
              {access.roles
                .map((role) => account.roles[role])
                .join(locale === "ur" ? "، " : ", ")}
            </p>
            {staff && <a href={`/${locale}/admin`}>{admin.heading}</a>}
          </>
        ) : (
          <p role="status">{account.unavailable}</p>
        )}
        <a href={`/${locale}/sign-in`}>{signIn.backToSignIn}</a>
      </div>
    </section>
  );
}
