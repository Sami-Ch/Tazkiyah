import { sql } from "drizzle-orm";
import { isCauseSlug } from "@/institutes/causes";
import { listWindow } from "@/design/paging";
import {
  causeMoney,
  donorWallEntry,
  postTypes,
  publicModules,
  themeFromSettings,
  type DonorWallEntry,
  type PublicModule,
  type PublicOverview,
  type PublicPost,
  type PublicPostType,
  type PublicSpend,
  type PublicTeacher,
} from "@/institutes/public-ledger";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

function pageOf<T>(rows: T[], take: number) {
  return { items: rows.slice(0, take), hasMore: rows.length > take };
}

function modules(value: unknown): PublicModule[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is PublicModule =>
    publicModules.some((name) => name === item),
  );
}

export async function readPublicOverview(tx: AuthQuery) {
  const {
    rows: [settings],
  } = await tx.execute<{ theme: unknown; enabled_modules: unknown }>(sql`
    select theme, enabled_modules from public_api.institute_public
  `);
  const { rows: causes } = await tx.execute<Record<string, unknown>>(sql`
    select id, slug, cause_type, title, status,
      target_paisa::text, raised_paisa::text, lifetime_raised_paisa::text,
      spent_paisa::text, unspent_paisa::text, accepts_zakat, ends_on::text
    from public_api.cause_summary
    where status in ('active', 'closed')
    order by display_order, slug
  `);
  const { rows: spending } = await tx.execute<Record<string, unknown>>(sql`
    select id, cause_id, spent_on::text, amount_paisa::text, description, status
    from public_api.cause_spending
    order by spent_on desc, id desc
    limit 20
  `);
  const { rows: wall } = await tx.execute<Record<string, unknown>>(sql`
    select w.public_ref, w.amount_paisa::text, w.given_on::text, w.donor_label,
      c.slug as cause_slug, c.title as cause_title
    from public_api.donor_wall w
    left join public_api.causes c on c.id = w.cause_id
    order by w.given_on desc, w.public_ref desc
    limit 5
  `);
  const body: PublicOverview = {
    theme: themeFromSettings(settings?.theme),
    modules: modules(settings?.enabled_modules),
    causes: causes.flatMap((row) => {
      const cause = causeMoney(row);
      return cause ? [cause] : [];
    }),
    spending: spending.flatMap((row) => {
      const entry = spendRow(row);
      return entry ? [entry] : [];
    }),
    wall: wall.flatMap((row) => {
      const entry = donorWallEntry(row);
      return entry ? [entry] : [];
    }),
  };
  return privateJson(body);
}

function spendRow(row: Record<string, unknown>): PublicSpend | undefined {
  if (typeof row.id !== "string" || typeof row.cause_id !== "string")
    return undefined;
  if (typeof row.spent_on !== "string" || typeof row.amount_paisa !== "string")
    return undefined;
  if (row.status !== "recorded" && row.status !== "reversed") return undefined;
  const description =
    row.description && typeof row.description === "object"
      ? (row.description as PublicSpend["description"])
      : {};
  return {
    id: row.id,
    cause_id: row.cause_id,
    spent_on: row.spent_on,
    amount_paisa: row.amount_paisa,
    description,
    status: row.status,
  };
}

export async function readDonorWall(tx: AuthQuery, search: URLSearchParams) {
  const cause = search.get("cause");
  const month = search.get("month");
  if ((cause && !isCauseSlug(cause)) || (month && !/^\d{4}-\d{2}$/.test(month)))
    return privateJson({ items: [], hasMore: false });
  const { take } = listWindow(search.get("shown"));
  const { rows } = await tx.execute<Record<string, unknown>>(sql`
    select w.public_ref, w.amount_paisa::text, w.given_on::text, w.donor_label,
      c.slug as cause_slug, c.title as cause_title
    from public_api.donor_wall w
    left join public_api.causes c on c.id = w.cause_id
    where (${cause}::text is null or c.slug = ${cause})
      and (${month}::text is null or to_char(w.given_on, 'YYYY-MM') = ${month})
    order by w.given_on desc, w.public_ref desc
    limit ${take + 1}
  `);
  const entries = rows.flatMap((row) => {
    const entry = donorWallEntry(row);
    return entry ? [entry] : [];
  });
  return privateJson(pageOf<DonorWallEntry>(entries, take));
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function postRow(row: Record<string, unknown>): PublicPost | undefined {
  if (typeof row.id !== "string" || typeof row.body !== "string")
    return undefined;
  if (!postTypes.some((type) => type === row.post_type)) return undefined;
  if (row.language !== "en" && row.language !== "ur") return undefined;
  if (row.author_kind !== "persona" && row.author_kind !== "teacher")
    return undefined;
  return {
    id: row.id,
    post_type: row.post_type as PublicPostType,
    language: row.language,
    title: typeof row.title === "string" ? row.title : null,
    body: row.body,
    published_at:
      typeof row.published_at === "string" ? row.published_at : null,
    author_kind: row.author_kind,
    persona_name:
      row.author_kind === "persona" && typeof row.persona_name === "string"
        ? row.persona_name
        : null,
    teacher_name:
      row.author_kind === "teacher" && typeof row.teacher_name === "string"
        ? row.teacher_name
        : null,
    teacher_id:
      row.author_kind === "teacher" && typeof row.teacher_id === "string"
        ? row.teacher_id
        : null,
    is_verified: row.is_verified === true,
    verified_by_name:
      typeof row.verified_by_name === "string" ? row.verified_by_name : null,
  };
}

export async function readPublicWork(tx: AuthQuery, search: URLSearchParams) {
  const audience = search.get("audience");
  if (audience !== "student" && audience !== "teacher")
    return privateJson({ items: [], teachers: [], hasMore: false }, 400);
  const id = search.get("id");
  if (id && !uuid.test(id))
    return privateJson({ items: [], teachers: [], hasMore: false });
  const type = search.get("type");
  const language = search.get("lang");
  const tab = search.get("tab");
  if (
    (type && !postTypes.some((item) => item === type)) ||
    (language && language !== "en" && language !== "ur") ||
    (tab &&
      !["verified", "article", "audio", "video", "resource"].includes(tab))
  )
    return privateJson({ items: [], teachers: [], hasMore: false });

  const { take } = listWindow(search.get("shown"));
  const { rows } = await tx.execute<Record<string, unknown>>(sql`
    select id, post_type, language, title, body, published_at::text, author_kind,
      persona_name, teacher_name,
      case when author_kind = 'teacher' then teacher_id end as teacher_id,
      is_verified, verified_by_name
    from public_api.public_posts
    where (${audience} = 'student' and author_kind = 'persona'
        or ${audience} = 'teacher' and author_kind = 'teacher')
      and (${id}::uuid is null or id = ${id}::uuid)
      and (${type}::text is null or post_type = ${type})
      and (${language}::text is null or language = ${language})
      and (${tab}::text is null
        or (${tab} = 'verified' and is_verified)
        or (${tab} = 'article' and post_type = 'article')
        or (${tab} = 'audio' and post_type = 'audio')
        or (${tab} = 'video' and post_type in ('video', 'vlog'))
        or (${tab} = 'resource' and post_type = 'slides'))
    order by published_at desc nulls last, id desc
    limit ${id ? 1 : take + 1}
  `);
  const { rows: teachers } = await tx.execute<Record<string, unknown>>(sql`
    select teacher_id, public_name, public_bio
    from public_api.public_teachers
    order by public_name
  `);
  const posts = rows.flatMap((row) => {
    const post = postRow(row);
    return post ? [post] : [];
  });
  const people: PublicTeacher[] = teachers.flatMap((row) =>
    typeof row.teacher_id === "string" && typeof row.public_name === "string"
      ? [
          {
            teacher_id: row.teacher_id,
            public_name: row.public_name,
            public_bio:
              row.public_bio && typeof row.public_bio === "object"
                ? (row.public_bio as PublicTeacher["public_bio"])
                : null,
          },
        ]
      : [],
  );
  return privateJson({
    ...pageOf(posts, id ? 1 : take),
    teachers: audience === "teacher" ? people : [],
  });
}
