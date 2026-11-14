import type { Locale } from "@tazkiyah/i18n/routing";
import en from "@tazkiyah/i18n/messages/en/trail.json";
import ur from "@tazkiyah/i18n/messages/ur/trail.json";

/** Private trail labels. The sentences live in the trail catalogues. */
export const trailCopy = { en, ur } satisfies Record<Locale, typeof en>;
