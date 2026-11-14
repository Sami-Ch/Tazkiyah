import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getModuleWorkspace } from "@/server/auth";
import { ModuleSwitchForm } from "./module-form";
import "../settings.css";

export const dynamic = "force-dynamic";

export default async function ModuleSwitchesPage({
  params,
}: PageProps<"/[locale]/admin/settings/modules">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const admin = `/${locale}/admin`;
  const workspace = await getModuleWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(admin);
  if (workspace.state === "denied") notFound();
  const { common } = await getMessages({ locale });
  const copy = common.moduleSwitches;

  return (
    <section className="staff-stack institute-screen" aria-labelledby="module-switches-title">
      <a href={admin}>{copy.back}</a>
      <h1 id="module-switches-title">{copy.heading}</h1>
      {workspace.state === "allowed" ? (
        <>
          <p>{copy.intro}</p>
          <ModuleSwitchForm modules={workspace.modules} copy={copy} />
        </>
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
