import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getInstituteWorkspace } from "@/server/auth";
import { InstituteSettingsForm } from "./settings-form";
import "./settings.css";

export const dynamic = "force-dynamic";

export default async function InstituteSettingsPage({
  params,
}: PageProps<"/[locale]/admin/settings">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const admin = `/${locale}/admin`;
  const workspace = await getInstituteWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(admin);
  if (workspace.state === "denied") notFound();
  const { common } = await getMessages({ locale });
  const copy = common.instituteSettings;

  return (
    <section className="staff-stack institute-screen" aria-labelledby="institute-settings-title">
      <a href={admin}>{copy.back}</a>
      <h1 id="institute-settings-title">{copy.heading}</h1>
      {workspace.state === "allowed" ? (
        <>
          <p>{copy.intro}</p>
          <InstituteSettingsForm
            settings={workspace.settings}
            copy={copy}
            locale={locale}
            banksHref={`${admin}/bank-accounts`}
          />
        </>
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
