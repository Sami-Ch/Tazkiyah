"use client";

import { usePathname } from "next/navigation";
import {
  staffLinkIsCurrent,
  type StaffLink,
  type StaffLinkId,
} from "./staff-links";

export function StaffNav({
  label,
  links,
  names,
}: {
  label: string;
  links: StaffLink[];
  names: Record<StaffLinkId, string>;
}) {
  const pathname = usePathname();
  return (
    <nav className="filter-row" aria-label={label}>
      {links.map((link) => {
        const current = staffLinkIsCurrent(pathname, link.href);
        return (
          <a
            key={link.id}
            href={link.href}
            aria-current={current ? "page" : undefined}
          >
            {names[link.id]}
          </a>
        );
      })}
    </nav>
  );
}
