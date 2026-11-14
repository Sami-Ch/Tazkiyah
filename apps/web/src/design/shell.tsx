import type { Locale } from "@tazkiyah/i18n/routing";
import Image from "next/image";
import type { ReactNode } from "react";

export type ShellLink = { href: string; label: string };

export function SiteHeader({
  homeHref,
  name,
  mosque,
  logoSrc,
  logoAlt,
  links,
  donateHref,
  donateLabel,
  menuLabel,
  language,
}: {
  homeHref: string;
  name: string;
  mosque: string;
  logoSrc: string;
  logoAlt: string;
  links: ShellLink[];
  donateHref: string;
  donateLabel: string;
  menuLabel: string;
  language: ReactNode;
}) {
  const items = links.map((link) => (
    <a key={link.href} href={link.href}>
      {link.label}
    </a>
  ));
  return (
    <header className="site-header">
      <div className="shell header-bar">
        <a className="wordmark" href={homeHref}>
          <Image
            src={logoSrc}
            alt={logoAlt}
            width={48}
            height={48}
            unoptimized
          />
          <span>
            <strong>{name}</strong>
            <small>{mosque}</small>
          </span>
        </a>
        <nav className="site-nav-desktop" aria-label={menuLabel}>
          {items}
        </nav>
        <div className="header-tools">
          <a className="ui-button header-donate" href={donateHref}>
            {donateLabel}
          </a>
          {language}
          <details className="nav-menu">
            <summary className="nav-toggle">{menuLabel}</summary>
            <nav className="nav-panel" aria-label={menuLabel}>
              {items}
            </nav>
          </details>
        </div>
      </div>
    </header>
  );
}

export function PatternBand() {
  return <div className="pattern-band" aria-hidden="true" />;
}

export function SiteFooter({
  name,
  platform,
  tagline,
  address,
  links,
  language,
}: {
  name: string;
  platform: string;
  tagline: string;
  address: ReactNode;
  links: ShellLink[];
  language: ReactNode;
}) {
  return (
    <footer className="site-footer">
      <div className="shell footer-grid">
        <div>
          <p className="footer-name">{name}</p>
          <p className="footer-tagline">{tagline}</p>
          <p className="footer-muted">{address}</p>
          <p className="footer-muted">{platform}</p>
        </div>
        <nav className="footer-links" aria-label={name}>
          {links.map((link) => (
            <a
              key={link.href}
              href={link.href}
              dir={
                link.href.startsWith("tel:") || link.href.startsWith("mailto:")
                  ? "ltr"
                  : undefined
              }
            >
              {link.label}
            </a>
          ))}
        </nav>
        {language}
      </div>
    </footer>
  );
}

export function shellLinks(
  locale: Locale,
  labels: Record<string, string>,
  modules: {
    students: boolean;
    teachers: boolean;
    projects: boolean;
  },
): ShellLink[] {
  const link = (path: string, label: string) => ({
    href: `/${locale}${path}`,
    label,
  });
  return [
    link("/about", labels.about),
    link("/causes", labels.causes),
    ...(modules.projects
      ? [link("/new-projects", labels.newProjects)]
      : []),
    link("/transparency", labels.transparency),
    link("/donor-wall", labels.donorWall),
    ...(modules.students ? [link("/student-work", labels.studentWork)] : []),
    ...(modules.teachers ? [link("/teacher-work", labels.teacherWork)] : []),
    link("/contact", labels.visit),
  ];
}
