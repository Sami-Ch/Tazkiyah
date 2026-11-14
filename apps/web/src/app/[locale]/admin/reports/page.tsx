import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { karachiDate } from "@/institutes/manual-donations";
import { getReportWorkspace } from "@/server/auth";
import { ReportsBoard } from "./reports-board";

export const dynamic = "force-dynamic";

export default async function ReportsPage({
  params,
}: PageProps<"/[locale]/admin/reports">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getReportWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();
  const { common } = await getMessages({ locale });
  const copy = common.staffReports;
  return (
    <section className="staff-stack" aria-labelledby="reports-title">
      <div className="public-intro">
        <h1 id="reports-title">{copy.heading}</h1>
        <p>{copy.intro}</p>
      </div>
      {workspace.state === "allowed" ? (
        <ReportsBoard
          locale={locale}
          copy={copy}
          today={karachiDate()}
          entries={workspace.entries}
          reports={workspace.reports}
          causes={workspace.causes}
        />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
