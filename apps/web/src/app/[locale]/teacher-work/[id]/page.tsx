import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getPublicOverview } from "@/server/auth";
import { WorkItem } from "../../work-item";

export const dynamic = "force-dynamic";

export default async function TeacherWorkItem({
  params,
}: PageProps<"/[locale]/teacher-work/[id]">) {
  const { locale: requested, id } = await params;
  const locale = requireLocale(requested);
  setRequestLocale(locale);
  const overview = await getPublicOverview(new Headers(await headers()));
  if (overview && !overview.modules.includes("teacher_hub")) notFound();
  return <WorkItem locale={locale} audience="teacher" id={id} />;
}
