export type StaffLinkId =
  | "home"
  | "donations"
  | "reconciliation"
  | "spending"
  | "causes"
  | "banks"
  | "users"
  | "audit"
  | "donorLinks"
  | "pages"
  | "classes"
  | "moderation"
  | "sponsorships"
  | "pledges"
  | "settings"
  | "modules";

/** Role flags already resolved by the permission matrix. */
export type StaffLinkAccess = {
  canRecordTransfers: boolean;
  canReconcileTransfers: boolean;
  canRecordSpending: boolean;
  canInvite: boolean;
  canEditPages: boolean;
  canManageClasses: boolean;
  canModerate: boolean;
  canMatchSponsors: boolean;
  canEditSettings: boolean;
  canSwitchModules: boolean;
};

export type StaffLink = { id: StaffLinkId; href: string };

// Menu by role (05 §8.0). A link appears only when this account may open it.
export function staffLinks(
  locale: string,
  access: StaffLinkAccess,
): StaffLink[] {
  const root = `/${locale}/admin`;
  const links: StaffLink[] = [{ id: "home", href: root }];
  if (access.canRecordTransfers) {
    links.push(
      { id: "donations", href: `${root}/donations` },
      { id: "pledges", href: `${root}/pledges` },
    );
  }
  if (access.canReconcileTransfers) {
    links.push({
      id: "reconciliation",
      href: `${root}/donations/reconciliation`,
    });
  }
  if (access.canRecordSpending)
    links.push({ id: "spending", href: `${root}/spending` });
  if (access.canInvite) {
    links.push(
      { id: "causes", href: `${root}/causes` },
      { id: "banks", href: `${root}/bank-accounts` },
      { id: "users", href: `${root}/users` },
      { id: "audit", href: `${root}/audit` },
      { id: "donorLinks", href: `${root}/donor-links` },
    );
  }
  if (access.canEditPages) links.push({ id: "pages", href: `${root}/pages` });
  if (access.canManageClasses)
    links.push({ id: "classes", href: `${root}/classes` });
  if (access.canModerate)
    links.push({ id: "moderation", href: `${root}/moderation` });
  if (access.canMatchSponsors) {
    links.push({ id: "sponsorships", href: `${root}/sponsorships` });
  }
  if (access.canEditSettings)
    links.push({ id: "settings", href: `${root}/settings` });
  if (access.canSwitchModules)
    links.push({ id: "modules", href: `${root}/settings/modules` });
  return links;
}

export function staffLinkIsCurrent(pathname: string, href: string) {
  if (href.endsWith("/admin")) return pathname === href;
  return pathname === href || pathname.startsWith(`${href}/`);
}
