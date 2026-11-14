import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { karachiDate } from "@/institutes/manual-donations";
import { getSpendingWorkspace } from "@/server/auth";
import { SpendingBoard } from "./spending-board";

export const dynamic = "force-dynamic";

export default async function SpendingPage({
  params,
}: PageProps<"/[locale]/admin/spending">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getSpendingWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.staffSpending;
  return (
    <section className="staff-stack" aria-labelledby="spending-title">
      <div className="public-intro">
        <h1 id="spending-title">{copy.heading}</h1>
        {workspace.state === "allowed" && <p>{copy.intro}</p>}
      </div>
      {workspace.state === "allowed" ? (
        <>
          <SpendingBoard
            locale={locale}
            copy={copy}
            today={karachiDate()}
            causes={workspace.causes}
            pools={workspace.pools}
            entries={workspace.entries}
          />
        </>
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
