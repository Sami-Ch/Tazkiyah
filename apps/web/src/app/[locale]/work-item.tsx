import type { Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { formatDate } from "@/design/format";
import { Alert, Badge, Button } from "@/design/ui";
import { pageTranslation } from "@/institutes/site-pages";
import { getPublicWork } from "@/server/auth";

export async function WorkItem({
  locale,
  audience,
  id,
}: {
  locale: Locale;
  audience: "student" | "teacher";
  id: string;
}) {
  const t = await getTranslations("common.public");
  const work = await getPublicWork(
    new Headers(await headers()),
    new URLSearchParams({ audience, id }),
  );
  const post = work.items[0];
  if (!post) notFound();
  const base = audience === "student" ? "student-work" : "teacher-work";
  const teacher = work.teachers.find(
    (person) => person.teacher_id === post.teacher_id,
  );
  const bio = pageTranslation(teacher?.public_bio ?? undefined, locale);

  return (
    <article className="shell public-stack" aria-labelledby="work-item-title">
      <Button href={`/${locale}/${base}`} variant="quiet">
        {audience === "student" ? t("studentWorkTitle") : t("teacherWorkTitle")}
      </Button>
      <header className="public-intro">
        <p className="giving-kicker">{t(`postTypes.${post.post_type}`)}</p>
        <h1 id="work-item-title" lang={post.language} dir="auto">
          {post.title || t(`postTypes.${post.post_type}`)}
        </h1>
        <p>
          <bdi>
            {post.author_kind === "persona"
              ? post.persona_name
              : post.teacher_name}
          </bdi>
        </p>
        {post.is_verified && post.verified_by_name && (
          <Badge tone="verified">
            {t("verifiedBy", { name: post.verified_by_name })}
          </Badge>
        )}
        {post.published_at && (
          <time dateTime={post.published_at}>
            {formatDate(post.published_at, locale)}
          </time>
        )}
      </header>
      {post.language !== locale && (
        <Alert tone="warning">{t("fallback")}</Alert>
      )}
      {post.summary && (
        <p lang={post.language} dir="auto">
          {post.summary}
        </p>
      )}
      <p
        className="measure published-page-copy"
        lang={post.language}
        dir="auto"
      >
        {post.body}
      </p>
      {post.youtube_id && (
        <p>
          <a
            href={`https://www.youtube-nocookie.com/embed/${post.youtube_id}`}
            rel="noreferrer"
          >
            YouTube
          </a>
        </p>
      )}
      {bio && (
        <p lang={bio.language} dir={bio.language === "ur" ? "rtl" : "ltr"}>
          {bio.text}
        </p>
      )}
      <section className="ui-card" aria-label={t("report")}>
        <h2>{t("report")}</h2>
        <p>{t("reportBody")}</p>
        <Button href={`/${locale}/contact`} variant="secondary">
          {t("contactInstead")}
        </Button>
      </section>
    </article>
  );
}
