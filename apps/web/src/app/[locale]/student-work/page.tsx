import { routing } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { institute } from "@/institutes/markaz-al-azeem";
import { getPublicOverview } from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import { WorkList } from "../work-list";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/student-work">) {
  const locale = requireLocale((await params).locale);
  const t = await getTranslations({ locale, namespace: "common" });
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: "/student-work",
    title: `${t("public.studentWorkTitle")} · ${institute.name[locale]}`,
    description: t("public.studentWorkIntro"),
  });
}

export default async function StudentWorkPage({
  params,
  searchParams,
}: PageProps<"/[locale]/student-work">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const overview = await getPublicOverview(new Headers(await headers()));
  if (overview && !overview.modules.includes("student_hub")) notFound();
  return (
    <WorkList
      locale={locale}
      audience="student"
      searchParams={await searchParams}
    />
  );
}
