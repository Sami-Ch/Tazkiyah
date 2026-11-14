import type { Locale } from "@tazkiyah/i18n/routing";
import en from "@tazkiyah/i18n/messages/en/hub.json";
import ur from "@tazkiyah/i18n/messages/ur/hub.json";

/** Class community labels. The sentences live in the hub catalogues. */
export const hubCopy = {
  en: en.page,
  ur: ur.page,
} satisfies Record<Locale, typeof en.page>;
