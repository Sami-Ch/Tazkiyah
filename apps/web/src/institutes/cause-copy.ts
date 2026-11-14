import type { Locale } from "@tazkiyah/i18n/routing";
import en from "@tazkiyah/i18n/messages/en/causes.json";
import ur from "@tazkiyah/i18n/messages/ur/causes.json";

/** Cause directory and cause-admin labels. The sentences live in the causes catalogues. */
export const causeCopy = { en, ur } satisfies Record<Locale, typeof en>;
