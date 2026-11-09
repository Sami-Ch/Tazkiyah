import type { Metadata } from "next";
import { setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { institute } from "@/institutes/markaz-al-azeem";
import { DonorTrail } from "./donor-trail";
import { trailCopy } from "./trail-copy";
import "./trail.css";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: PageProps<"/[locale]/trail">): Promise<Metadata> {
  const locale = requireLocale((await params).locale);
  return {
    title: `${trailCopy[locale].title} · ${institute.name[locale]}`,
    robots: { index: false, follow: false, noarchive: true },
    referrer: "no-referrer",
  };
}

export default async function TrailPage({
  params,
}: PageProps<"/[locale]/trail">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const copy = trailCopy[locale];

  return (
    <section className="shell private-trail" aria-labelledby="trail-title">
      <header className="trail-heading">
        <p className="eyebrow">{institute.name[locale]}</p>
        <h1 id="trail-title">{copy.title}</h1>
        <p>{copy.intro}</p>
      </header>
      <DonorTrail locale={locale} />
      <noscript>
        <p>{copy.noScript}</p>
      </noscript>
    </section>
  );
}
