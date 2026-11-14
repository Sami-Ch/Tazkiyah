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
  const currentHref = links
    .filter((link) => staffLinkIsCurrent(pathname, link.href))
    .sort((left, right) => right.href.length - left.href.length)[0]?.href;
  return (
    <nav className="filter-row" aria-label={label}>
      {links.map((link) => {
        const current = link.href === currentHref;
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
