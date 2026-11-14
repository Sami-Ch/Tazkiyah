import type { Metadata } from "next";
import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAccountAccess } from "@/server/auth";
import { HubScreen } from "./hub-screen";
import { hubCopy } from "./hub-copy";
import "../account/sponsorship/sponsor.css";
import "./hub.css";

export const dynamic = "force-dynamic";

const uuidPattern = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/hub">): Promise<Metadata> {
  const locale = requireLocale((await params).locale);
  return {
    title: hubCopy[locale].title,
    robots: { index: false, follow: false, noarchive: true },
  };
}

export default async function HubPage({
  params,
  searchParams,
}: PageProps<"/[locale]/hub">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const access = await getAccountAccess(new Headers(await headers()));
  if (access.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (access.state === "enroll") redirect(`/${locale}/admin`);
  if (access.state === "allowed" && access.mustChangePassword)
    redirect(`/${locale}/account`);
  const member =
    access.state === "allowed" &&
    access.roles.some(
      (role) => role === "student" || role === "teacher" || role === "admin",
    );
  if (access.state === "allowed" && !member) notFound();

  const query = await searchParams;
  const classValue = Array.isArray(query.class) ? query.class[0] : query.class;
  const threadValue = Array.isArray(query.thread)
    ? query.thread[0]
    : query.thread;
  const classId =
    classValue === "madrasa" || (classValue && uuidPattern.test(classValue))
      ? classValue
      : undefined;
  const threadId =
    threadValue && uuidPattern.test(threadValue) ? threadValue : undefined;
  const copy = hubCopy[locale];

  return (
    <section className="shell community" aria-labelledby="hub-title">
      <header className="community-heading">
        <a href={`/${locale}/account`}>{copy.account}</a>
        <h1 id="hub-title">{copy.title}</h1>
        <p>{copy.intro}</p>
      </header>
      {access.state === "allowed" ? (
        <HubScreen locale={locale} classId={classId} threadId={threadId} />
      ) : (
        <p role="status">{copy.unavailable}</p>
      )}
    </section>
  );
}
