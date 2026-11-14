import { sql } from "drizzle-orm";
import {
  isProjectCategory,
  type PublicProject,
} from "@/institutes/projects";
import type { LocalizedPageText } from "@/institutes/site-pages";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

function localized(value: unknown): LocalizedPageText | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const pair = {
    ...(typeof record.en === "string" ? { en: record.en } : {}),
    ...(typeof record.ur === "string" ? { ur: record.ur } : {}),
  };
  return pair.en || pair.ur ? pair : null;
}

export async function readPublishedProjects(tx: AuthQuery) {
  const { rows } = await tx.execute<Record<string, unknown>>(sql`
    select id, slug, cause_type, title, summary, category, planned_start::text,
      why_it_matters, cost_lines, accepts_zakat, target_paisa::text, status,
      raised_paisa::text, spent_paisa::text
    from public_api.projects
    order by case status when 'active' then 0 when 'closed' then 1 else 2 end,
      planned_start nulls last, slug
  `);
  const projects = rows.flatMap((row) => {
    const title = localized(row.title);
    const summary = localized(row.summary);
    if (
      typeof row.id !== "string" ||
      typeof row.slug !== "string" ||
      !title ||
      !summary ||
      !isProjectCategory(row.category) ||
      (row.cause_type !== "campaign" &&
        row.cause_type !== "ongoing" &&
        row.cause_type !== "yearly_stock") ||
      (row.status !== "active" &&
        row.status !== "closed" &&
        row.status !== "archived")
    )
      return [];
    const project: PublicProject = {
      id: row.id,
      slug: row.slug,
      cause_type: row.cause_type,
      title,
      summary,
      category: row.category,
      planned_start:
        typeof row.planned_start === "string" ? row.planned_start : null,
      why_it_matters: localized(row.why_it_matters),
      cost_lines: localized(row.cost_lines),
      accepts_zakat: row.accepts_zakat === true,
      target_paisa:
        typeof row.target_paisa === "string" ? row.target_paisa : null,
      status: row.status,
      raised_paisa:
        typeof row.raised_paisa === "string" ? row.raised_paisa : "0",
      spent_paisa: typeof row.spent_paisa === "string" ? row.spent_paisa : "0",
    };
    return [project];
  });
  return privateJson(projects);
}
