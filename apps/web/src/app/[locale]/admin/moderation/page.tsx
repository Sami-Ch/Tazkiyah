import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getModerationWorkspace } from "@/server/auth";
import { ModerationQueue } from "./moderation-queue";

export const dynamic = "force-dynamic";

export default async function ModerationPage({
  params,
}: PageProps<"/[locale]/admin/moderation">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getModerationWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.staffModeration;
  return (
    <section className="shell staff-screen" aria-labelledby="moderation-title">
      <h1 id="moderation-title">{copy.heading}</h1>
      <p className="staff-lead">{copy.intro}</p>
      {workspace.state === "allowed" ? (
        <ModerationQueue locale={locale} copy={copy} items={workspace.items} />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
