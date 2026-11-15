import type { Locale } from "@tazkiyah/i18n/routing";
import { getTranslations } from "next-intl/server";
import { Icon } from "@/components/icon";
import { ProgrammeMark } from "@/design/programme-mark";
import { StarRule } from "@/design/ornament";
import { showSampleBadge } from "@/institutes/public-story";

const quotes = [
  ["story.quote1", "story.quote1Role"],
  ["story.quote2", "story.quote2Role"],
  ["story.quote3", "story.quote3Role"],
] as const;
const faqs = [
  ["story.faq1Q", "story.faq1A"],
  ["story.faq2Q", "story.faq2A"],
  ["story.faq3Q", "story.faq3A"],
  ["story.faq4Q", "story.faq4A"],
  ["story.faq5Q", "story.faq5A"],
] as const;
const steps = [
  ["story.flow1Title", "story.flow1Body"],
  ["story.flow2Title", "story.flow2Body"],
  ["story.flow3Title", "story.flow3Body"],
  ["story.flow4Title", "story.flow4Body"],
] as const;
const programmeKeys = [
  ["education", "story.educationTitle", "story.educationBody", true],
  ["meals", "story.mealsTitle", "story.mealsBody", false],
  ["clinic", "story.clinicTitle", "story.clinicBody", false],
  ["orphans", "story.orphansTitle", "story.orphansBody", false],
] as const;
const kinds = [
  ["zakat", "story.zakatName", "story.zakatBody"],
  ["sadaqah", "story.sadaqahName", "story.sadaqahBody"],
  ["general", "story.generalName", "story.generalBody"],
] as const;

function SampleFlag({ label }: { label: string }) {
  if (!showSampleBadge()) return null;
  return <p className="sample-flag">{label}</p>;
}

export async function HomeStory({ locale }: { locale: Locale }) {
  const t = await getTranslations("common");

  return (
    <>
      <section
        className="band band-sunken bleed reveal"
        id="programmes"
        aria-labelledby="programmes-title"
      >
        <div className="section-intro">
          <p className="eyebrow">{t("story.programmesLabel")}</p>
          <h2 id="programmes-title">{t("story.programmesHeading")}</h2>
          <StarRule />
        </div>
        <ol className="programme-cards">
          {programmeKeys.map(([name, title, body, sample], index) => (
            <li key={name}>
              <article className="programme-card">
                <div className="programme-card-head">
                  <ProgrammeMark name={name} />
                  <span className="programme-index">
                    <bdi>{String(index + 1).padStart(2, "0")}</bdi>
                  </span>
                </div>
                <h3>{t(title)}</h3>
                {sample && <SampleFlag label={t("story.sampleBadge")} />}
                <p>{t(body)}</p>
              </article>
            </li>
          ))}
        </ol>
      </section>

      <section
        className="band band-paper reveal"
        id="gift-path"
        aria-labelledby="gift-path-title"
      >
        <div className="section-intro">
          <p className="eyebrow">{t("story.flowLabel")}</p>
          <h2 id="gift-path-title">{t("story.flowHeading")}</h2>
          <StarRule />
        </div>
        <ol className="timeline">
          {steps.map(([title, body], index) => (
            <li key={title}>
              <span className="timeline-node">
                <bdi>{index + 1}</bdi>
              </span>
              <h3>{t(title)}</h3>
              <p>{t(body)}</p>
            </li>
          ))}
        </ol>
      </section>

      <section
        className="band band-paper reveal"
        id="zakat-and-sadaqah"
        aria-labelledby="zakat-title"
      >
        <div className="section-intro">
          <p className="eyebrow">{t("story.zakatLabel")}</p>
          <h2 id="zakat-title">{t("story.zakatHeading")}</h2>
          <StarRule />
        </div>
        <div className="kind-cards">
          {kinds.map(([kind, name, body]) => (
            <article key={kind} className={`kind-card kind-card-${kind}`}>
              <h3>{t(name)}</h3>
              <p>{t(body)}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="verse bleed" aria-labelledby="verse-title">
        <div className="verse-ornament" aria-hidden="true" />
        <p className="eyebrow" id="verse-title">
          {t("story.verseLabel")}
        </p>
        <blockquote>
          <p className="verse-arabic" lang="ar" dir="rtl">
            {t("story.verseArabic")}
          </p>
          <StarRule />
          <p lang={locale}>{t("story.verseText")}</p>
          <footer>
            <cite>{t("story.verseRef")}</cite>
          </footer>
        </blockquote>
      </section>

      <section
        className="band band-paper reveal"
        id="voices"
        aria-labelledby="voices-title"
      >
        <div className="section-intro">
          <p className="eyebrow">{t("story.quotesLabel")}</p>
          <h2 id="voices-title">{t("story.quotesHeading")}</h2>
          <SampleFlag label={t("story.sampleBadge")} />
          <StarRule />
        </div>
        <div className="quote-cards">
          {quotes.map(([quote, role]) => (
            <blockquote key={quote} className="quote-card">
              <span className="quote-mark" aria-hidden="true">
                <Icon name="quote" />
              </span>
              <p>{t(quote)}</p>
              <footer className="quote-role">{t(role)}</footer>
            </blockquote>
          ))}
        </div>
      </section>

      <section
        className="band band-sunken bleed reveal"
        id="questions"
        aria-labelledby="questions-title"
      >
        <div className="faq-layout">
          <div className="section-intro">
            <p className="eyebrow">{t("story.faqLabel")}</p>
            <h2 id="questions-title">{t("story.faqHeading")}</h2>
            <StarRule />
          </div>
          <div className="faq-list">
            {faqs.map(([question, answer]) => (
              <details key={question}>
                <summary>{t(question)}</summary>
                <p>{t(answer)}</p>
              </details>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
