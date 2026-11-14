import { headers } from "next/headers";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAdminAccess } from "@/server/auth";
import { staffLinks, type StaffLinkId } from "./staff-links";
import { StaffNav } from "./staff-nav";

export default async function AdminLayout({
  children,
  params,
}: LayoutProps<"/[locale]/admin">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const access = await getAdminAccess(new Headers(await headers()));
  if (access.state !== "allowed") return children;

  const { common } = await getMessages({ locale });
  const names = common.staffWorkspace.links;
  return (
    <div className="shell public-stack">
      <StaffNav
        label={common.staffWorkspace.navLabel}
        links={staffLinks(locale, access)}
        names={names as Record<StaffLinkId, string>}
      />
      {children}
    </div>
  );
}
