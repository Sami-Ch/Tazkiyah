import type { Locale } from "@tazkiyah/i18n/routing";
import Image from "next/image";
import type { ReactNode } from "react";
import { Icon } from "@/components/icon";
import { NavLinks } from "@/components/nav-links";

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
  const items = <NavLinks links={links} />;
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
            <summary className="nav-toggle" aria-label={menuLabel}>
              <Icon name="menu" />
              <span className="nav-toggle-label">{menuLabel}</span>
            </summary>
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

function isContactHref(href: string) {
  return href.startsWith("tel:") || href.startsWith("mailto:");
}

export function SiteFooter({
  name,
  logoSrc,
  platform,
  tagline,
  address,
  links,
  contactLinks,
  exploreLabel,
  contactLabel,
  language,
}: {
  name: string;
  logoSrc: string;
  platform: string;
  tagline: string;
  address: ReactNode;
  links: ShellLink[];
  contactLinks: ShellLink[];
  exploreLabel: string;
  contactLabel: string;
  language: ReactNode;
}) {
  return (
    <footer className="site-footer">
      <div className="shell footer-grid">
        <div className="footer-brand">
          <Image src={logoSrc} alt="" width={56} height={56} unoptimized />
          <p className="footer-name">{name}</p>
          <p className="footer-tagline">{tagline}</p>
          <p className="footer-muted">{address}</p>
        </div>
        <nav className="footer-links" aria-label={exploreLabel}>
          <p className="footer-heading">{exploreLabel}</p>
          {links.map((link) => (
            <a key={link.href} href={link.href}>
              {link.label}
            </a>
          ))}
        </nav>
        <div className="footer-links footer-aside">
          <p className="footer-heading">{contactLabel}</p>
          {contactLinks.map((link) => (
            <a
              key={link.href}
              href={link.href}
              dir={isContactHref(link.href) ? "ltr" : undefined}
            >
              {link.label}
            </a>
          ))}
          <div className="footer-language">{language}</div>
        </div>
      </div>
      <div className="shell footer-bottom">
        <p className="footer-muted">{platform}</p>
        <p className="footer-muted">{name}</p>
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
