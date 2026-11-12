import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAdminAccess } from "@/server/auth";
import { DonorLinkForm } from "./donor-link-form";
import "../../sign-in/sign-in.css";

export const dynamic = "force-dynamic";

export default async function DonorLinksPage({
  params,
}: PageProps<"/[locale]/admin/donor-links">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const admin = `/${locale}/admin`;
  const access = await getAdminAccess(new Headers(await headers()));
  if (access.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (access.state === "enroll") redirect(admin);
  if (
    access.state === "denied" ||
    (access.state === "allowed" && !access.canInvite)
  )
    notFound();
  const { common } = await getMessages({ locale });
  const copy = common.donorLinks;

  return (
    <section
      className="shell sign-in-section"
      aria-labelledby="donor-links-title"
    >
      <div className="sign-in-card">
        <a href={admin}>{copy.back}</a>
        <h1 id="donor-links-title">{copy.heading}</h1>
        {access.state === "allowed" ? (
          <>
            <p>{copy.intro}</p>
            <DonorLinkForm copy={copy} locale={locale} />
          </>
        ) : (
          <p role="status">{common.signIn.unavailable}</p>
        )}
      </div>
    </section>
  );
}
