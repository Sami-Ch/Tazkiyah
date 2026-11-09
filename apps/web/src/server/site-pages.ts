import { sql } from "drizzle-orm";
import {
  isSitePageSlug,
  homeFactKeys,
  maxHomeFactValue,
  type HomeFacts,
  type EditableSitePage,
  type PublishedSitePage,
} from "@/institutes/site-pages";
import { privateJson } from "./staff-invitations";
import type { AdminAccess, AuthQuery } from "./workspace-access";

export type SitePageWorkspace =
  | { state: "allowed"; pages: EditableSitePage[] }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

export async function readPublishedSitePages(tx: AuthQuery) {
  const { rows } = await tx.execute<PublishedSitePage>(sql`
    select slug, title::jsonb, body::jsonb, facts from public_api.site_pages
    where slug in ('home', 'about', 'facilities', 'daily-life')
  `);
  return privateJson(rows);
}

export async function readSitePageWorkspace(tx: AuthQuery, sessionId: string) {
  const { rows } = await tx.execute<EditableSitePage>(
    sql`select * from identity.read_site_pages(${sessionId})`,
  );
  if (!rows.length) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    pages: rows,
  } satisfies SitePageWorkspace);
}

function localizedPair(input: unknown, maxLength: number) {
  if (!input || typeof input !== "object") return null;
  const { en, ur } = input as Record<string, unknown>;
  if (typeof en !== "string" || typeof ur !== "string") return null;
  const pair = { en: en.trim(), ur: ur.trim() };
  if (
    Object.values(pair).some(
      (value) => !value || value.length > maxLength || value.includes("\u0000"),
    )
  ) {
    return null;
  }
  return pair;
}

function homeFacts(input: unknown): HomeFacts | null {
  if (!input || typeof input !== "object") return null;
  const raw = input as Record<string, unknown>;
  const entries = [];
  for (const key of homeFactKeys) {
    const card = raw[key];
    if (!card || typeof card !== "object") return null;
    const { value, label: rawLabel } = card as Record<string, unknown>;
    const label = localizedPair(rawLabel, 120);
    if (
      typeof value !== "number" ||
      !Number.isInteger(value) ||
      value < 0 ||
      value > maxHomeFactValue ||
      !label
    ) {
      return null;
    }
    entries.push([key, { value, label }] as const);
  }
  return Object.fromEntries(entries) as HomeFacts;
}

export async function writeSitePage(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object")
    return privateJson({ code: "invalid" }, 400);

  const { slug, revision, action } = input as Record<string, unknown>;
  if (
    !isSitePageSlug(slug) ||
    (revision !== null &&
      (typeof revision !== "string" ||
        !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(revision))) ||
    (action !== "save" && action !== "publish")
  ) {
    return privateJson({ code: "invalid" }, 400);
  }

  let query;
  if (action === "save") {
    const fields = input as Record<string, unknown>;
    const title = localizedPair(fields.title, 120);
    const body = localizedPair(fields.body, 12_000);
    if (!title || !body) return privateJson({ code: "invalid" }, 400);
    if (fields.facts !== undefined) {
      const facts = slug === "home" ? homeFacts(fields.facts) : null;
      if (!facts) return privateJson({ code: "invalid" }, 400);
      query = sql`select identity.save_home_page(
        ${sessionId}, ${revision}, ${sql.param(title)}::jsonb, ${sql.param(body)}::jsonb, ${sql.param(facts)}::jsonb
      ) as outcome`;
    } else {
      query = sql`select identity.save_site_page(
        ${sessionId}, ${slug}, ${revision}, ${sql.param(title)}::jsonb, ${sql.param(body)}::jsonb
      ) as outcome`;
    }
  } else {
    query = sql`select identity.publish_site_page(${sessionId}, ${slug}, ${revision}) as outcome`;
  }

  const {
    rows: [result],
  } = await tx.execute<{ outcome: string }>(query);
  if (result.outcome === "stale") return privateJson({ code: "stale" }, 409);
  if (result.outcome === "invalid")
    return privateJson({ code: "invalid" }, 400);
  if (result.outcome !== "saved" && result.outcome !== "published")
    return privateJson({ code: "denied" }, 403);
  return privateJson({ outcome: result.outcome });
}
