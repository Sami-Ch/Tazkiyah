import type { Locale } from "@tazkiyah/i18n/routing";
import en from "@tazkiyah/i18n/messages/en/sponsor.json";
import ur from "@tazkiyah/i18n/messages/ur/sponsor.json";

/** Sponsor-page labels. The sentences live in the sponsor catalogues. */
export const sponsorCopy = { en, ur } satisfies Record<Locale, typeof en>;
