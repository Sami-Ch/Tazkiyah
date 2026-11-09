import english from "@tazkiyah/i18n/messages/en/common.json";
import urdu from "@tazkiyah/i18n/messages/ur/common.json";
import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { defaultHomeFacts } from "@/institutes/home-facts";
import { institute } from "@/institutes/markaz-al-azeem";
import { isSitePageSlug, sitePageSlugs } from "@/institutes/site-pages";
import { getSitePageWorkspace } from "@/server/auth";
import { SitePageForm } from "./site-page-form";
import "../../sign-in/sign-in.css";
import "./site-page-editor.css";

export const dynamic = "force-dynamic";

const defaults = {
  home: {
    title: institute.name,
    body: { en: english.home.summary, ur: urdu.home.summary },
  },
  about: {
    title: { en: english.about.heading, ur: urdu.about.heading },
    body: { en: english.about.body, ur: urdu.about.body },
  },
};

export default async function SitePagesPage({
  params,
  searchParams,
}: PageProps<"/[locale]/admin/pages">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const slug = (await searchParams).page;
  const selected = isSitePageSlug(slug) ? slug : "home";
  const adminHref = `/${locale}/admin`;
  const workspace = await getSitePageWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(adminHref);
  if (workspace.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.sitePages;
  const page =
    workspace.state === "allowed"
      ? workspace.pages.find((page) => page.slug === selected)
      : undefined;
  const fallback =
    selected === "home" || selected === "about"
      ? defaults[selected]
      : undefined;

  return (
    <section className="shell page-editor" aria-labelledby="page-editor-title">
      <a className="page-editor-back" href={adminHref}>
        {copy.back}
      </a>
      <h1 id="page-editor-title">{copy.heading}</h1>
      <nav className="page-editor-nav" aria-label={copy.heading}>
        {sitePageSlugs.map((item) => (
          <a
            className="button button-outline"
            key={item}
            href={`${adminHref}/pages?page=${item}`}
            aria-current={item === selected ? "page" : undefined}
          >
            {copy.slugs[item]}
          </a>
        ))}
      </nav>
      {page ? (
        <SitePageForm
          key={`${page.slug}:${page.revision}`}
          copy={copy}
          page={{
            ...page,
            title: page.title ?? fallback?.title ?? {},
            body: page.body ?? fallback?.body ?? {},
            facts:
              selected === "home" ? (page.facts ?? defaultHomeFacts) : null,
          }}
        />
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
