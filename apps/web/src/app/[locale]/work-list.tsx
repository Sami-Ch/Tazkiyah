import type { Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { getTranslations } from "next-intl/server";
import { formatDate } from "@/design/format";
import { nextPageHref } from "@/design/paging";
import { Badge, Button, EmptyState } from "@/design/ui";
import { postTypes, type PublicPost } from "@/institutes/public-ledger";
import { getPublicWork } from "@/server/auth";

function one(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function excerpt(post: PublicPost) {
  const source = post.title?.trim() || post.body.trim();
  const characters = [...source];
  return characters.length > 140
    ? `${characters.slice(0, 139).join("")}…`
    : source;
}

export async function WorkList({
  locale,
  audience,
  searchParams,
}: {
  locale: Locale;
  audience: "student" | "teacher";
  searchParams: Record<string, string | string[] | undefined>;
}) {
  const t = await getTranslations("common.public");
  const type = one(searchParams.type);
  const lang = one(searchParams.lang);
  const tab = one(searchParams.tab);
  const shown = one(searchParams.shown);
  const filters = new URLSearchParams({ audience });
  if (type) filters.set("type", type);
  if (lang) filters.set("lang", lang);
  if (tab) filters.set("tab", tab);
  if (shown) filters.set("shown", shown);
  const work = await getPublicWork(new Headers(await headers()), filters);
  const base = audience === "student" ? "student-work" : "teacher-work";
  const title =
    audience === "student" ? t("studentWorkTitle") : t("teacherWorkTitle");
  const intro =
    audience === "student" ? t("studentWorkIntro") : t("teacherWorkIntro");
  const empty =
    audience === "student" ? t("studentWorkEmpty") : t("teacherWorkEmpty");
  const tabs = ["verified", "article", "audio", "video", "resource"] as const;

  return (
    <section className="shell public-stack" aria-labelledby="work-title">
      <header className="public-intro">
        <h1 id="work-title">{title}</h1>
        <p>{intro}</p>
      </header>
      {audience === "teacher" ? (
        <nav className="filter-row" aria-label={title}>
          <a
            href={`/${locale}/${base}`}
            aria-current={!tab ? "true" : undefined}
          >
            {t("filterAll")}
          </a>
          {tabs.map((item) => (
            <a
              key={item}
              href={`/${locale}/${base}?tab=${item}`}
              aria-current={tab === item ? "true" : undefined}
            >
              {t(`tabs.${item}`)}
            </a>
          ))}
        </nav>
      ) : (
        <nav className="filter-row" aria-label={title}>
          <a
            href={`/${locale}/${base}`}
            aria-current={!type ? "true" : undefined}
          >
            {t("filterAll")}
          </a>
          {postTypes.map((item) => (
            <a
              key={item}
              href={`/${locale}/${base}?type=${item}`}
              aria-current={type === item ? "true" : undefined}
            >
              {t(`postTypes.${item}`)}
            </a>
          ))}
        </nav>
      )}
      {work.items.length === 0 ? (
        <EmptyState title={title}>{empty}</EmptyState>
      ) : (
        <ul className="work-grid">
          {work.items.map((post) => (
            <li className="ui-card" key={post.id}>
              <p className="giving-kicker">
                {t(`postTypes.${post.post_type}`)}
              </p>
              <h2>
                <a href={`/${locale}/${base}/${post.id}`}>{excerpt(post)}</a>
              </h2>
              <p>
                <bdi>
                  {post.author_kind === "persona"
                    ? post.persona_name
                    : post.teacher_name}
                </bdi>
              </p>
              {post.language !== locale && <Badge>{post.language}</Badge>}
              {post.is_verified && (
                <Badge tone="verified">
                  {post.verified_by_name
                    ? t("verifiedBy", { name: post.verified_by_name })
                    : t("tabs.verified")}
                </Badge>
              )}
              {post.published_at && (
                <time dateTime={post.published_at}>
                  {formatDate(post.published_at, locale)}
                </time>
              )}
            </li>
          ))}
        </ul>
      )}
      {work.hasMore && (
        <Button
          href={nextPageHref(
            `/${locale}/${base}`,
            { type, lang, tab, shown },
            Number(shown && /^\d+$/.test(shown) ? shown : 20) + 20,
          )}
          variant="secondary"
        >
          {t("showMore")}
        </Button>
      )}
    </section>
  );
}
