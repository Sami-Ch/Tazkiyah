import type { Locale } from "@tazkiyah/i18n/routing";
import en from "@tazkiyah/i18n/messages/en/hub.json";
import ur from "@tazkiyah/i18n/messages/ur/hub.json";

/** Walkthrough, profile and post-type labels. The sentences live in the hub catalogues. */
export const hubUiCopy = {
  en: en.ui,
  ur: ur.ui,
} satisfies Record<Locale, typeof en.ui>;
