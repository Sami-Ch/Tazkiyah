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
    <section className="staff-stack" aria-labelledby="moderation-title">
      <div className="public-intro">
        <h1 id="moderation-title">{copy.heading}</h1>
        <p>{copy.intro}</p>
      </div>
      {workspace.state === "allowed" ? (
        <ModerationQueue
          locale={locale}
          copy={copy}
          isAdmin={workspace.is_admin}
          canWiden={workspace.can_widen}
          requests={workspace.requests}
          posts={workspace.posts}
          publicPosts={workspace.public_posts}
          takenDown={workspace.taken_down}
          wideners={workspace.wideners}
        />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
