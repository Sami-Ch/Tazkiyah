import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAllNeedsWorkspace } from "@/server/auth";
import { AllNeedsBoard } from "./all-needs-board";

export const dynamic = "force-dynamic";

export default async function AllNeedsPage({
  params,
}: PageProps<"/[locale]/admin/all-needs">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getAllNeedsWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();
  const { common } = await getMessages({ locale });
  const copy = common.staffAllNeeds;
  return (
    <section className="staff-stack" aria-labelledby="all-needs-title">
      <div className="public-intro">
        <h1 id="all-needs-title">{copy.heading}</h1>
        <p>{copy.intro}</p>
      </div>
      {workspace.state === "allowed" ? (
        <AllNeedsBoard
          locale={locale}
          copy={copy}
          pools={workspace.pools}
          gifts={workspace.gifts}
          causes={workspace.causes}
        />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
