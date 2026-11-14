import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getConsentWorkspace } from "@/server/auth";
import { ConsentBoard } from "./consent-board";

export const dynamic = "force-dynamic";

export default async function ConsentPage({
  params,
}: PageProps<"/[locale]/admin/consent">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getConsentWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(`/${locale}/admin`);
  if (workspace.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.staffConsent;
  return (
    <section className="staff-stack" aria-labelledby="consent-title">
      <div className="public-intro">
        <h1 id="consent-title">{copy.heading}</h1>
        <p>{copy.intro}</p>
      </div>
      {workspace.state === "allowed" ? (
        <ConsentBoard
          locale={locale}
          copy={copy}
          isPrincipal={workspace.is_principal}
          students={workspace.students}
          teachers={workspace.teachers}
          sponsorships={workspace.sponsorships}
          records={workspace.records}
        />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
