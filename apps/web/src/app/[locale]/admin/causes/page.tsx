import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { causeCopy } from "@/institutes/cause-copy";
import { getCauseWorkspace } from "@/server/auth";
import { CauseManager } from "./cause-manager";
import "../../sign-in/sign-in.css";
import "../pages/site-page-editor.css";
import "./cause-manager.css";

export const dynamic = "force-dynamic";

export default async function AdminCausesPage({
  params,
}: PageProps<"/[locale]/admin/causes">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const adminHref = `/${locale}/admin`;
  const copy = causeCopy[locale].admin;
  const workspace = await getCauseWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(adminHref);
  if (workspace.state === "denied") notFound();

  return (
    <section
      className="shell page-editor"
      aria-labelledby="cause-manager-title"
    >
      <a className="page-editor-back" href={adminHref}>
        {copy.back}
      </a>
      <h1 id="cause-manager-title">{copy.title}</h1>
      <p>{copy.intro}</p>
      {workspace.state === "allowed" ? (
        <CauseManager locale={locale} causes={workspace.causes} />
      ) : (
        <p role="status">{copy.unavailable}</p>
      )}
    </section>
  );
}
