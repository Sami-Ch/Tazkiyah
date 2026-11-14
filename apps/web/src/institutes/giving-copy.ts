import type { Locale } from "@tazkiyah/i18n/routing";
import en from "@tazkiyah/i18n/messages/en/donate.json";
import ur from "@tazkiyah/i18n/messages/ur/donate.json";

/** Giving-page labels. The sentences live in the donate catalogues. */
export const givingCopy = { en, ur } satisfies Record<Locale, typeof en>;
