import type { Locale } from "@tazkiyah/i18n/routing";
import { checkTheme, nightAndPaper, type Theme } from "@tazkiyah/core/theme";
import type { CauseKind, CauseStatus } from "./causes";
import type { LocalizedPageText } from "./site-pages";

export const publicModules = [
  "student_hub",
  "teacher_hub",
  "new_projects",
] as const;
export type PublicModule = (typeof publicModules)[number];

export type CauseMoney = {
  id: string;
  slug: string;
  cause_type: CauseKind;
  title: LocalizedPageText;
  status: Exclude<CauseStatus, "draft">;
  target_paisa: string | null;
  raised_paisa: string;
  lifetime_raised_paisa: string;
  spent_paisa: string;
  unspent_paisa: string;
  accepts_zakat: boolean;
  ends_on: string | null;
};

export type PublicSpend = {
  id: string;
  cause_id: string;
  spent_on: string;
  amount_paisa: string;
  description: LocalizedPageText;
  status: "recorded" | "reversed";
};

export type DonorWallEntry = {
  public_ref: string;
  amount_paisa: string;
  given_on: string;
  donor_label: string | null;
  cause_slug: string | null;
  cause_title: LocalizedPageText | null;
};

export const postTypes = [
  "message",
  "question",
  "answer",
  "poll",
  "article",
  "video",
  "vlog",
  "audio",
  "slides",
] as const;
export type PublicPostType = (typeof postTypes)[number];

export type PublicPost = {
  id: string;
  post_type: PublicPostType;
  language: Locale;
  title: string | null;
  body: string;
  published_at: string | null;
  author_kind: "persona" | "teacher";
  persona_name: string | null;
  teacher_name: string | null;
  teacher_id: string | null;
  is_verified: boolean;
  verified_by_name: string | null;
};

export type PublicTeacher = {
  teacher_id: string;
  public_name: string;
  public_bio: LocalizedPageText | null;
};

export type PublicOverview = {
  theme: Theme;
  modules: PublicModule[];
  causes: CauseMoney[];
  spending: PublicSpend[];
  wall: DonorWallEntry[];
};

export function themeFromSettings(value: unknown): Theme {
  return checkTheme(value).length === 0 ? (value as Theme) : nightAndPaper;
}

const localized = (value: unknown): LocalizedPageText => {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const record = value as Record<string, unknown>;
  return {
    ...(typeof record.en === "string" ? { en: record.en } : {}),
    ...(typeof record.ur === "string" ? { ur: record.ur } : {}),
  };
};

const money = (value: unknown) =>
  typeof value === "string" && /^\d+$/.test(value) ? value : "0";

export function causeMoney(
  row: Record<string, unknown>,
): CauseMoney | undefined {
  if (typeof row.id !== "string" || typeof row.slug !== "string")
    return undefined;
  if (
    row.cause_type !== "campaign" &&
    row.cause_type !== "ongoing" &&
    row.cause_type !== "yearly_stock"
  )
    return undefined;
  if (
    row.status !== "active" &&
    row.status !== "closed" &&
    row.status !== "archived"
  )
    return undefined;
  return {
    id: row.id,
    slug: row.slug,
    cause_type: row.cause_type,
    title: localized(row.title),
    status: row.status,
    target_paisa: row.target_paisa === null ? null : money(row.target_paisa),
    raised_paisa: money(row.raised_paisa),
    lifetime_raised_paisa: money(row.lifetime_raised_paisa),
    spent_paisa: money(row.spent_paisa),
    unspent_paisa: money(row.unspent_paisa),
    accepts_zakat: row.accepts_zakat === true,
    ends_on: typeof row.ends_on === "string" ? row.ends_on : null,
  };
}

export function donorWallEntry(
  row: Record<string, unknown>,
): DonorWallEntry | undefined {
  if (
    typeof row.public_ref !== "string" ||
    typeof row.amount_paisa !== "string"
  )
    return undefined;
  if (typeof row.given_on !== "string") return undefined;
  const label = row.donor_label;
  return {
    public_ref: row.public_ref,
    amount_paisa: row.amount_paisa,
    given_on: row.given_on,
    donor_label: typeof label === "string" && label.trim() ? label : null,
    cause_slug: typeof row.cause_slug === "string" ? row.cause_slug : null,
    cause_title: row.cause_title ? localized(row.cause_title) : null,
  };
}
