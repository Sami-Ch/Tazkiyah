import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAdminAccess, getClassWorkspace } from "@/server/auth";
import { ClassBoard } from "./class-board";

export const dynamic = "force-dynamic";

export default async function ClassesPage({
  params,
}: PageProps<"/[locale]/admin/classes">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getClassWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();

  const access = await getAdminAccess(new Headers(await headers()));
  const { common } = await getMessages({ locale });
  const copy = common.staffClasses;
  return (
    <section className="shell staff-screen" aria-labelledby="classes-title">
      <h1 id="classes-title">{copy.heading}</h1>
      <p className="staff-lead">{copy.intro}</p>
      {workspace.state === "allowed" ? (
        <ClassBoard
          locale={locale}
          copy={copy}
          canCreateStudents={
            access.state === "allowed" && access.canCreateStudents
          }
          classes={workspace.classes}
          students={workspace.students}
          teachers={workspace.teachers}
        />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
