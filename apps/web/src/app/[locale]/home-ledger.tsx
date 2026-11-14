import type { Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { getTranslations } from "next-intl/server";
import { formatDate } from "@/design/format";
import { Amount, Button, EmptyState } from "@/design/ui";
import { causeCopy } from "@/institutes/cause-copy";
import { pageTranslation } from "@/institutes/site-pages";
import {
  getPublicOverview,
  getPublicWork,
  getPublishedCauses,
} from "@/server/auth";
import { CauseProgress } from "./causes/cause-progress";
import { WallName } from "./donor-wall/wall-name";

export async function HomeLedger({ locale }: { locale: Locale }) {
  const t = await getTranslations("common.public");
  const requestHeaders = new Headers(await headers());
  const [causes, overview] = await Promise.all([
    getPublishedCauses(requestHeaders),
    getPublicOverview(requestHeaders),
  ]);
  const active = causes
    .filter((cause) => cause.status === "active")
    .slice(0, 6);
  const copy = causeCopy[locale];
  const [students, teachers] = await Promise.all([
    overview?.modules.includes("student_hub")
      ? getPublicWork(
          requestHeaders,
          new URLSearchParams({ audience: "student" }),
        )
      : Promise.resolve(null),
    overview?.modules.includes("teacher_hub")
      ? getPublicWork(
          requestHeaders,
          new URLSearchParams({ audience: "teacher" }),
        )
      : Promise.resolve(null),
  ]);
  const spending = (overview?.spending ?? []).slice(0, 3);
  const wall = overview?.wall ?? [];
  const causeName = (id: string) => {
    const cause = overview?.causes.find((item) => item.id === id);
    return pageTranslation(cause?.title, locale)?.text;
  };

  return (
    <>
      <section aria-labelledby="home-causes-title">
        <div className="section-head">
          <h2 id="home-causes-title">{copy.title}</h2>
          <Button href={`/${locale}/causes`} variant="quiet">
            {t("seeCauses")}
          </Button>
        </div>
        {active.length === 0 ? (
          <EmptyState title={copy.title}>{t("causesSoon")}</EmptyState>
        ) : (
          <ul className="cause-grid">
            {active.map((cause) => {
              const title = pageTranslation(cause.title, locale);
              if (!title) return null;
              return (
                <li className="ui-card" key={cause.id}>
                  <div className="ui-pattern" aria-hidden="true" />
                  <h3
                    lang={title.language}
                    dir={title.language === "ur" ? "rtl" : "ltr"}
                  >
                    {title.text}
                  </h3>
                  <CauseProgress cause={cause} locale={locale} />
                  <Button
                    href={`/${locale}/donate/${cause.slug}`}
                    variant="secondary"
                  >
                    {copy.donate}
                  </Button>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {spending.length > 0 && (
        <section aria-labelledby="home-spent-title">
          <div className="section-head">
            <h2 id="home-spent-title">{t("whereMoneyWent")}</h2>
            <Button href={`/${locale}/transparency`} variant="quiet">
              {t("transparencyTitle")}
            </Button>
          </div>
          <p className="measure">{t("whereMoneyBody")}</p>
          <ul className="wall-list">
            {spending.map((entry) => (
              <li className="wall-row" key={entry.id}>
                <span>{causeName(entry.cause_id)}</span>
                <time dateTime={entry.spent_on}>
                  {formatDate(entry.spent_on, locale)}
                </time>
                <Amount paisa={entry.amount_paisa} locale={locale} />
              </li>
            ))}
          </ul>
        </section>
      )}

      {students && students.items.length > 0 && (
        <section aria-labelledby="home-students-title">
          <div className="section-head">
            <h2 id="home-students-title">{t("studentWorkTitle")}</h2>
            <Button href={`/${locale}/student-work`} variant="quiet">
              {t("read")}
            </Button>
          </div>
          <ul className="wall-list">
            {students.items.slice(0, 3).map((post) => (
              <li key={post.id}>
                <a href={`/${locale}/student-work/${post.id}`}>
                  <bdi>{post.persona_name}</bdi>
                  {" · "}
                  {post.title || post.body.slice(0, 80)}
                </a>
              </li>
            ))}
          </ul>
        </section>
      )}

      {teachers && teachers.items.length > 0 && (
        <section aria-labelledby="home-teachers-title">
          <div className="section-head">
            <h2 id="home-teachers-title">{t("teacherWorkTitle")}</h2>
            <Button href={`/${locale}/teacher-work`} variant="quiet">
              {t("read")}
            </Button>
          </div>
          <ul className="wall-list">
            {teachers.items.slice(0, 3).map((post) => (
              <li key={post.id}>
                <a href={`/${locale}/teacher-work/${post.id}`}>
                  {post.title || post.body.slice(0, 80)}
                </a>
              </li>
            ))}
          </ul>
        </section>
      )}

      {wall.length > 0 && (
        <section aria-labelledby="home-wall-title">
          <div className="section-head">
            <h2 id="home-wall-title">{t("donorWallTitle")}</h2>
            <Button href={`/${locale}/donor-wall`} variant="quiet">
              {t("donorWallTitle")}
            </Button>
          </div>
          <ul className="wall-list">
            {wall.map((entry) => (
              <li className="wall-row" key={entry.public_ref}>
                <WallName
                  locale={locale}
                  label={entry.donor_label}
                  anonymous={t("anonymous")}
                  profileRef={entry.profile_ref}
                  trailPublic={entry.trail_public}
                  publicRef={entry.public_ref}
                  viewTrail={t("viewTrail")}
                />
                <Amount paisa={entry.amount_paisa} locale={locale} />
                <time dateTime={entry.given_on}>
                  {formatDate(entry.given_on, locale)}
                </time>
              </li>
            ))}
          </ul>
        </section>
      )}
    </>
  );
}
