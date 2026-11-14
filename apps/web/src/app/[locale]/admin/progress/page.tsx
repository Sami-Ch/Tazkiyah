import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getProgressWorkspace } from "@/server/auth";
import { ProgressBoard } from "./progress-board";

export const dynamic = "force-dynamic";

export default async function ProgressPage({
  params,
}: PageProps<"/[locale]/admin/progress">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getProgressWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.staffProgress;
  return (
    <section className="staff-stack" aria-labelledby="progress-title">
      <div className="public-intro">
        <h1 id="progress-title">{copy.heading}</h1>
        <p>{copy.intro}</p>
      </div>
      {workspace.state === "allowed" ? (
        <ProgressBoard
          locale={locale}
          copy={copy}
          isAdmin={workspace.is_admin}
          pupils={workspace.children}
          updates={workspace.updates}
        />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
