import { routing } from "@tazkiyah/i18n/routing";
import { hasLocale } from "next-intl";
import { notFound } from "next/navigation";

export function requireLocale(value: string) {
  if (!hasLocale(routing.locales, value)) notFound();
  return value;
}
