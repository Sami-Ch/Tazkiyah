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
    <nav className="staff-nav" aria-label={label}>
      <ul>
        {links.map((link) => {
          const current = staffLinkIsCurrent(pathname, link.href);
          return (
            <li key={link.id}>
              <a href={link.href} aria-current={current ? "page" : undefined}>
                {names[link.id]}
              </a>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
