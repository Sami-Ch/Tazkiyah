"use client";

import { usePathname } from "next/navigation";

export type NavLink = { href: string; label: string };

/** Marks the link for the current section with aria-current. */
export function NavLinks({ links }: { links: NavLink[] }) {
  const pathname = usePathname() ?? "";
  return (
    <>
      {links.map((link) => {
        const current =
          pathname === link.href || pathname.startsWith(`${link.href}/`);
        return (
          <a
            key={link.href}
            href={link.href}
            aria-current={current ? "page" : undefined}
          >
            {link.label}
          </a>
        );
      })}
    </>
  );
}
