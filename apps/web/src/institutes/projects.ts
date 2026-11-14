import type { Locale } from "@tazkiyah/i18n/routing";
import type { CauseKind } from "./causes";
import type { LocalizedPageText } from "./site-pages";

export const projectCategories = [
  "facilities",
  "education",
  "community",
  "technology",
] as const;
export type ProjectCategory = (typeof projectCategories)[number];

export type ProjectStage = "raising" | "funded" | "closed";

export type PublicProject = {
  id: string;
  slug: string;
  cause_type: CauseKind;
  title: LocalizedPageText;
  summary: LocalizedPageText;
  category: ProjectCategory;
  planned_start: string | null;
  why_it_matters: LocalizedPageText | null;
  cost_lines: LocalizedPageText | null;
  accepts_zakat: boolean;
  target_paisa: string | null;
  status: "active" | "closed" | "archived";
  raised_paisa: string;
  spent_paisa: string;
};

export function isProjectCategory(value: unknown): value is ProjectCategory {
  return projectCategories.some((category) => category === value);
}

/** Stage is worked out from status and money. It is not stored (05 §10.1). */
export function projectStage(project: {
  status: PublicProject["status"];
  target_paisa: string | null;
  raised_paisa: string;
}): ProjectStage {
  if (project.status === "closed" || project.status === "archived")
    return "closed";
  if (
    project.target_paisa &&
    BigInt(project.raised_paisa) >= BigInt(project.target_paisa)
  )
    return "funded";
  return "raising";
}

export function projectMonth(value: string | null, locale: Locale) {
  if (!value || !/^[0-9]{4}-[0-9]{2}-01$/.test(value)) return null;
  const [year, month] = value.split("-").map(Number);
  return new Intl.DateTimeFormat(`${locale}-PK`, {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(Date.UTC(year, month - 1, 1));
}
