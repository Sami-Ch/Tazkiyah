import { routing, type Locale } from "@tazkiyah/i18n/routing";
import { headers } from "next/headers";
import { notFound } from "next/navigation";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { Amount, Badge, Button, EmptyState, ProgressBar } from "@/design/ui";
import { percentOf } from "@/design/format";
import { requireLocale } from "@/i18n/locale";
import { institute } from "@/institutes/markaz-al-azeem";
import {
  projectCategories,
  projectMonth,
  projectStage,
  type ProjectCategory,
  type PublicProject,
} from "@/institutes/projects";
import { pageTranslation } from "@/institutes/site-pages";
import { getPublicOverview, getPublishedProjects } from "@/server/auth";
import { publicPageMetadata, publicSiteOrigin } from "@/server/public-site";
import "../causes/causes.css";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/new-projects">) {
  const locale = requireLocale((await params).locale);
  const t = await getTranslations({ locale, namespace: "common" });
  return publicPageMetadata({
    origin: publicSiteOrigin(new Headers(await headers())),
    locale,
    locales: routing.locales,
    path: "/new-projects",
    title: `${t("newProjects.title")} · ${institute.name[locale]}`,
    description: t("newProjects.intro"),
  });
}

function ProjectCard({
  project,
  locale,
  copy,
}: {
  project: PublicProject;
  locale: Locale;
  copy: {
    stages: Record<string, string>;
    planned: string;
    read: string;
    donate: string;
    zakat: string;
    raised: string;
    spent: string;
    categories: Record<ProjectCategory, string>;
  };
}) {
  const title = pageTranslation(project.title, locale);
  const summary = pageTranslation(project.summary, locale);
  const why = pageTranslation(project.why_it_matters ?? undefined, locale);
  if (!title || !summary) return null;
  const stage = projectStage(project);
  const planned = projectMonth(project.planned_start, locale);
  const target = project.target_paisa ? BigInt(project.target_paisa) : 0n;
  const raised = BigInt(project.raised_paisa);
  return (
    <li className="ui-card">
      <div className="ui-pattern" aria-hidden="true" />
      <p className="giving-kicker">{copy.categories[project.category]}</p>
      <h2 lang={title.language} dir={title.language === "ur" ? "rtl" : "ltr"}>
        {title.text}
      </h2>
      <p>
        <Badge tone={stage === "funded" ? "verified" : "neutral"}>
          {copy.stages[stage]}
        </Badge>
        {project.accepts_zakat && <Badge tone="zakat">{copy.zakat}</Badge>}
      </p>
      <p lang={summary.language} dir={summary.language === "ur" ? "rtl" : "ltr"}>
        {summary.text}
      </p>
      {planned && (
        <p>
          {copy.planned}: {planned}
        </p>
      )}
      {why && (
        <p lang={why.language} dir={why.language === "ur" ? "rtl" : "ltr"}>
          {why.text}
        </p>
      )}
      {target > 0n ? (
        <ProgressBar
          value={Number(raised)}
          max={Number(target)}
          label={`${percentOf(raised, target)}%`}
        />
      ) : (
        <p>
          {copy.raised} <Amount paisa={raised} locale={locale} />
        </p>
      )}
      {stage === "closed" && (
        <p>
          {copy.spent} <Amount paisa={project.spent_paisa} locale={locale} />
        </p>
      )}
      <div className="ui-actions">
        <Button href={`/${locale}/causes/${project.slug}`} variant="secondary">
          {copy.read}
        </Button>
        {stage !== "closed" && (
          <Button href={`/${locale}/donate/${project.slug}`}>
            {copy.donate}
          </Button>
        )}
      </div>
    </li>
  );
}

export default async function NewProjectsPage({
  params,
  searchParams,
}: PageProps<"/[locale]/new-projects">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const requestHeaders = new Headers(await headers());
  const overview = await getPublicOverview(requestHeaders);
  if (!overview?.modules.includes("new_projects")) notFound();
  const t = await getTranslations("common.newProjects");
  const pages = await getTranslations("common.sitePages");
  const zakat = await getTranslations("common.public");
  const projects = await getPublishedProjects(requestHeaders);
  const requested = (await searchParams).category;
  const category = projectCategories.find((item) => item === requested);
  const visible = category
    ? projects.filter((project) => project.category === category)
    : projects;
  const active = visible.filter((project) => project.status === "active");
  const past = visible.filter((project) => project.status !== "active");
  const chips = projectCategories.filter((item) =>
    projects.some((project) => project.category === item),
  );
  const technology = projects.filter(
    (project) => project.category === "technology" && project.status === "active",
  );
  const copy = {
    stages: {
      raising: t("stages.raising"),
      funded: t("stages.funded"),
      closed: t("stages.closed"),
    },
    planned: t("planned"),
    read: t("read"),
    donate: t("donate"),
    zakat: zakat("zakatOnly"),
    raised: t("raised"),
    spent: t("spent"),
    categories: {
      facilities: t("categories.facilities"),
      education: t("categories.education"),
      community: t("categories.community"),
      technology: t("categories.technology"),
    },
  };

  return (
    <section className="shell public-stack giving-causes" aria-labelledby="projects-title">
      <a className="giving-back" href={`/${locale}`}>
        {pages("backHome")}
      </a>
      <header className="giving-heading">
        <h1 id="projects-title">{t("title")}</h1>
        <p>{t("intro")}</p>
      </header>
      {projects.length === 0 ? (
        <EmptyState title={t("title")}>{t("empty")}</EmptyState>
      ) : (
        <>
          {chips.length > 0 && (
            <nav className="filter-row" aria-label={t("all")}>
              <a href={`/${locale}/new-projects`} aria-current={category ? undefined : "page"}>
                {t("all")}
              </a>
              {chips.map((item) => (
                <a
                  key={item}
                  href={`/${locale}/new-projects?category=${item}`}
                  aria-current={category === item ? "page" : undefined}
                >
                  {copy.categories[item]}
                </a>
              ))}
            </nav>
          )}
          {active.length > 0 && (
            <ul className="giving-grid">
              {active.map((project) => (
                <ProjectCard
                  key={project.id}
                  project={project}
                  locale={locale}
                  copy={copy}
                />
              ))}
            </ul>
          )}
        </>
      )}
      <section aria-labelledby="technology-costs">
        <h2 id="technology-costs">{t("technologyTitle")}</h2>
        <p>{t("technologyBody")}</p>
        {technology.length === 0 ? (
          <p>{t("noTechnology")}</p>
        ) : (
          <ul className="giving-grid">
            {technology.map((project) => (
              <ProjectCard
                key={project.id}
                project={project}
                locale={locale}
                copy={copy}
              />
            ))}
          </ul>
        )}
      </section>
      <section aria-labelledby="project-updates">
        <h2 id="project-updates">{t("updatesTitle")}</h2>
        <p>{t("updatesBody")}</p>
      </section>
      {past.length > 0 && (
        <details className="giving-past">
          <summary>{t("past")}</summary>
          <ul className="giving-grid">
            {past.map((project) => (
              <ProjectCard
                key={project.id}
                project={project}
                locale={locale}
                copy={copy}
              />
            ))}
          </ul>
        </details>
      )}
    </section>
  );
}
