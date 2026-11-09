"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { usePathname } from "next/navigation";
import { Icon } from "@/components/icon";

export function LanguageSwitch({
  locale,
  label,
  accessibleLabel,
}: {
  locale: Locale;
  label: string;
  accessibleLabel: string;
}) {
  const pathname = usePathname();
  const alternate = locale === "en" ? "ur" : "en";
  const suffix = pathname?.startsWith(`/${locale}/`)
    ? pathname.slice(locale.length + 1)
    : "";

  return (
    <a
      className="language-switch"
      href={`/${alternate}${suffix}`}
      hrefLang={alternate}
      aria-label={accessibleLabel}
      onClick={(event) => {
        if (suffix === "/staff-invite") {
          event.currentTarget.hash = window.location.hash;
        }
      }}
    >
      <Icon name="globe" />
      <span lang={alternate} dir={alternate === "ur" ? "rtl" : "ltr"}>
        {label}
      </span>
    </a>
  );
}
