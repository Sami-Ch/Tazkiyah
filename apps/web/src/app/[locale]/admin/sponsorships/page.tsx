import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getSponsorshipWorkspace } from "@/server/auth";
import { SponsorshipBoard } from "./sponsorship-board";

export const dynamic = "force-dynamic";

export default async function SponsorshipsPage({
  params,
}: PageProps<"/[locale]/admin/sponsorships">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getSponsorshipWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.staffSponsorships;
  return (
    <section className="staff-stack" aria-labelledby="sponsorships-title">
      <div className="public-intro">
        <h1 id="sponsorships-title">{copy.heading}</h1>
        <p>{copy.intro}</p>
      </div>
      {workspace.state === "allowed" ? (
        <SponsorshipBoard
          locale={locale}
          copy={copy}
          isPrincipal={workspace.is_principal}
          unread={workspace.unread}
          matches={workspace.matches}
          orphans={workspace.orphans}
          sponsors={workspace.sponsors}
          causes={workspace.causes}
          teachers={workspace.teachers}
          messages={workspace.messages}
        />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
