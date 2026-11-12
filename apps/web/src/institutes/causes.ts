import { routing } from "@tazkiyah/i18n/routing";
import type { LocalizedPageText } from "./site-pages";

export const causeKinds = ["campaign", "ongoing", "yearly_stock"] as const;
export type CauseKind = (typeof causeKinds)[number];
export type CauseStatus = "draft" | "active" | "closed" | "archived";

export const causeLimits = {
  slug: 80,
  title: 120,
  summary: 360,
  body: 12_000,
  scholar: 120,
};

export function isCauseSlug(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length <= causeLimits.slug &&
    /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value)
  );
}

export type CauseListing = {
  id: string;
  slug: string;
  cause_type: CauseKind;
  title: LocalizedPageText;
  status: CauseStatus;
  starts_on: string | null;
  ends_on: string | null;
};

type CauseDetails = CauseListing & {
  summary: LocalizedPageText;
  body: LocalizedPageText | null;
  target_paisa: string | null;
  target_period: "monthly" | "yearly" | null;
  stock_year_start_month: number | null;
  accepts_zakat: boolean;
  zakat_approved_by: LocalizedPageText | null;
};

export type EditableCause = CauseDetails & {
  revision: string;
  has_recorded_allocations: boolean;
  receipt_public_by_default: boolean;
};

export type PublishedCause = CauseDetails & {
  status: Exclude<CauseStatus, "draft">;
  raised_paisa: string;
  lifetime_raised_paisa: string;
};

export function publishedCauseLocales(cause: PublishedCause) {
  return routing.locales.filter(
    (locale) => cause.title[locale] && cause.summary[locale],
  );
}
