import type { Metadata } from "next";
import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAccountAccess } from "@/server/auth";
import { SponsorScreen } from "./sponsor-screen";
import { sponsorCopy } from "./sponsor-copy";
import "../../sign-in/sign-in.css";
import "./sponsor.css";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/account/sponsorship">): Promise<Metadata> {
  const locale = requireLocale((await params).locale);
  return {
    title: sponsorCopy[locale].title,
    robots: { index: false, follow: false, noarchive: true },
  };
}

export default async function SponsorshipPage({
  params,
}: PageProps<"/[locale]/account/sponsorship">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const access = await getAccountAccess(new Headers(await headers()));
  if (access.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (access.state === "enroll") redirect(`/${locale}/admin`);
  if (access.state === "allowed" && access.mustChangePassword)
    redirect(`/${locale}/account`);
  if (access.state === "allowed" && !access.roles.includes("donor")) notFound();
  const copy = sponsorCopy[locale];

  return (
    <section className="shell community" aria-labelledby="sponsor-title">
      <header className="community-heading">
        <a href={`/${locale}/account`}>{copy.back}</a>
        <h1 id="sponsor-title">{copy.title}</h1>
        <p>{copy.intro}</p>
      </header>
      {access.state === "allowed" ? (
        <SponsorScreen locale={locale} />
      ) : (
        <p role="status">{copy.unavailable}</p>
      )}
    </section>
  );
}
