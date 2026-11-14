import type { Locale } from "@tazkiyah/i18n/routing";
import { getTranslations } from "next-intl/server";
import { CountUp } from "@/design/count-up";
import { StarRule } from "@/design/ornament";
import type { HomeFacts } from "@/institutes/site-pages";

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

export async function HomeStory({
  locale,
  facts,
}: {
  locale: Locale;
  facts: HomeFacts;
}) {
  const t = await getTranslations("common");
  const number = new Intl.NumberFormat(`${locale}-PK`, {
    numberingSystem: "latn",
  });
  const programmes = [
    {
      key: "education" as const,
      sample: true,
      title: t("story.educationTitle"),
      body: t("story.educationBody"),
    },
    {
      key: "meals" as const,
      sample: false,
      title: t("story.mealsTitle"),
      body: t("story.mealsBody"),
    },
    {
      key: "clinic" as const,
      sample: false,
      title: t("story.clinicTitle"),
      body: t("story.clinicBody"),
    },
  ];

  return (
    <>
      <section
        className="story-block reveal"
        id="programmes"
        aria-labelledby="programmes-title"
      >
        <p className="eyebrow">{t("story.programmesLabel")}</p>
        <h2 id="programmes-title">{t("story.programmesHeading")}</h2>
        <StarRule />
        <ol className="programme-list">
          {programmes.map((programme, index) => (
            <li key={programme.key}>
              <p className="programme-index">
                <bdi>{String(index + 1).padStart(2, "0")}</bdi>
              </p>
              <div>
                <h3>{programme.title}</h3>
                {programme.sample && (
                  <p className="sample-flag">{t("story.sampleBadge")}</p>
                )}
                <p>{programme.body}</p>
                <p className="programme-stat">
                  <CountUp
                    value={facts[programme.key].value}
                    label={number.format(facts[programme.key].value)}
                  />
                  <span>{facts[programme.key].label[locale]}</span>
                </p>
              </div>
            </li>
          ))}
          <li>
            <p className="programme-index">
              <bdi>04</bdi>
            </p>
            <div>
              <h3>{t("story.orphansTitle")}</h3>
              <p>{t("story.orphansBody")}</p>
            </div>
          </li>
        </ol>
        <a className="button button-outline" href={`/${locale}/causes`}>
          {t("giving.explore")}
        </a>
      </section>

      <section
        className="story-block reveal"
        id="gift-path"
        aria-labelledby="flow-title"
      >
        <p className="eyebrow">{t("story.flowLabel")}</p>
        <h2 id="flow-title">{t("story.flowHeading")}</h2>
        <StarRule />
        <ol className="flow-list">
          {steps.map(([title, body], index) => (
            <li key={title}>
              <p className="programme-index">
                <bdi>{index + 1}</bdi>
              </p>
              <h3>{t(title)}</h3>
              <p>{t(body)}</p>
            </li>
          ))}
        </ol>
      </section>

      <section
        className="story-block reveal"
        id="zakat"
        aria-labelledby="zakat-title"
      >
        <p className="eyebrow">{t("story.zakatLabel")}</p>
        <h2 id="zakat-title">{t("story.zakatHeading")}</h2>
        <StarRule />
        <div className="giving-kinds">
          <article>
            <h3>{t("story.zakatName")}</h3>
            <p>{t("story.zakatBody")}</p>
          </article>
          <article>
            <h3>{t("story.sadaqahName")}</h3>
            <p>{t("story.sadaqahBody")}</p>
          </article>
          <article>
            <h3>{t("story.generalName")}</h3>
            <p>{t("story.generalBody")}</p>
          </article>
        </div>
      </section>

      <section className="verse reveal" aria-labelledby="verse-title">
        <p className="eyebrow" id="verse-title">
          {t("story.verseLabel")}
        </p>
        <StarRule />
        <p className="verse-arabic" lang="ar" dir="rtl">
          {t("story.verseArabic")}
        </p>
        <blockquote>
          <p>{t("story.verseText")}</p>
        </blockquote>
        <p className="verse-ref">{t("story.verseRef")}</p>
      </section>

      <section
        className="story-block reveal"
        id="voices"
        aria-labelledby="voices-title"
      >
        <p className="eyebrow">{t("story.quotesLabel")}</p>
        <h2 id="voices-title">{t("story.quotesHeading")}</h2>
        <p className="sample-flag">{t("story.sampleBadge")}</p>
        <StarRule />
        <ul className="quote-list">
          {quotes.map(([text, role]) => (
            <li key={text}>
              <blockquote>
                <p>{t(text)}</p>
              </blockquote>
              <p className="quote-role">{t(role)}</p>
            </li>
          ))}
        </ul>
      </section>

      <section
        className="story-block reveal"
        id="questions"
        aria-labelledby="faq-title"
      >
        <p className="eyebrow">{t("story.faqLabel")}</p>
        <h2 id="faq-title">{t("story.faqHeading")}</h2>
        <StarRule />
        <div className="faq-list">
          {faqs.map(([question, answer]) => (
            <details key={question}>
              <summary>{t(question)}</summary>
              <p>{t(answer)}</p>
            </details>
          ))}
        </div>
      </section>
    </>
  );
}
