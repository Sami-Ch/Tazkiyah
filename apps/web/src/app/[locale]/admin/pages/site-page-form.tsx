"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import { useRouter } from "next/navigation";
import { useState, useTransition, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import {
  homeFactKeys,
  maxHomeFactValue,
  type EditableSitePage,
  type HomeFacts,
  type LocalizedPageText,
} from "@/institutes/site-pages";

type Copy = typeof common.sitePages;
type Field = { en: string; ur: string };
const languages = ["en", "ur"] as const;
type FactKey = (typeof homeFactKeys)[number];
type FactDraft = { value: string; label: Field };
type FactDrafts = Record<FactKey, FactDraft>;

function draftFacts(facts: HomeFacts): FactDrafts {
  return Object.fromEntries(
    homeFactKeys.map((key) => [
      key,
      { ...facts[key], value: String(facts[key].value) },
    ]),
  ) as FactDrafts;
}

function bilingual(value: LocalizedPageText | null): Field {
  return { en: value?.en ?? "", ur: value?.ur ?? "" };
}

export function SitePageForm({
  copy,
  page,
}: {
  copy: Copy;
  page: EditableSitePage;
}) {
  const router = useRouter();
  const [title, setTitle] = useState(() => bilingual(page.title));
  const [body, setBody] = useState(() => bilingual(page.body));
  const [facts, setFacts] = useState(() =>
    page.facts ? draftFacts(page.facts) : null,
  );
  const [busy, setBusy] = useState(false);
  const [refreshing, startTransition] = useTransition();
  const [error, setError] = useState("");
  const factsChanged =
    facts &&
    page.facts &&
    homeFactKeys.some(
      (key) =>
        facts[key].value !== String(page.facts?.[key].value) ||
        languages.some(
          (language) =>
            facts[key].label[language] !== page.facts?.[key].label[language],
        ),
    );
  const dirty =
    factsChanged ||
    languages.some(
      (language) =>
        title[language] !== (page.title?.[language] ?? "") ||
        body[language] !== (page.body?.[language] ?? ""),
    );
  const disabled = busy || refreshing;
  const canPublish = page.pending && page.revision && !dirty;

  async function submit(action: "save" | "publish") {
    if (disabled) return;
    setBusy(true);
    setError("");
    try {
      const response = await authRequest("site-page", {
        slug: page.slug,
        revision: page.revision,
        action,
        ...(action === "save"
          ? {
              title,
              body,
              ...(facts && {
                facts: Object.fromEntries(
                  homeFactKeys.map((key) => [
                    key,
                    { ...facts[key], value: Number(facts[key].value) },
                  ]),
                ),
              }),
            }
          : {}),
      });
      if (!response.ok) {
        setError(
          response.status === 409
            ? copy.stale
            : response.status === 400
              ? facts
                ? copy.facts.invalid
                : copy.invalid
              : copy.error,
        );
        return;
      }
      startTransition(() => router.refresh());
    } catch {
      setError(copy.error);
    } finally {
      setBusy(false);
    }
  }

  function updateFact(key: FactKey, next: FactDraft) {
    setFacts((previous) => previous && { ...previous, [key]: next });
  }

  function saveDraft(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void submit("save");
  }

  return (
    <form
      className="sign-in-form page-editor-form"
      method="post"
      onSubmit={saveDraft}
      aria-busy={disabled}
    >
      <h2>{copy.slugs[page.slug]}</h2>
      <p>
        {page.pending
          ? page.published
            ? copy.pendingLive
            : copy.pending
          : page.published
            ? copy.published
            : copy.unpublished}
      </p>
      <div className="page-editor-languages">
        {languages.map((language) => (
          <fieldset key={language} disabled={disabled}>
            <legend>{copy.languages[language]}</legend>
            <label>
              {copy.title}
              <input
                lang={language}
                dir={language === "ur" ? "rtl" : "ltr"}
                value={title[language]}
                onChange={(event) =>
                  setTitle({ ...title, [language]: event.target.value })
                }
                maxLength={120}
                required
              />
            </label>
            <label>
              {copy.body}
              <textarea
                lang={language}
                dir={language === "ur" ? "rtl" : "ltr"}
                value={body[language]}
                onChange={(event) =>
                  setBody({ ...body, [language]: event.target.value })
                }
                rows={10}
                maxLength={12000}
                required
              />
            </label>
          </fieldset>
        ))}
      </div>
      {facts && (
        <section
          className="page-editor-facts"
          aria-labelledby="page-editor-facts-heading"
        >
          <h3 id="page-editor-facts-heading">{copy.facts.heading}</h3>
          <div className="page-editor-languages">
            {homeFactKeys.map((key) => (
              <fieldset key={key} disabled={disabled}>
                <legend>{copy.facts.cards[key]}</legend>
                <label>
                  {copy.facts.value}
                  <input
                    type="number"
                    inputMode="numeric"
                    dir="ltr"
                    min={0}
                    max={maxHomeFactValue}
                    step={1}
                    value={facts[key].value}
                    onChange={(event) =>
                      updateFact(key, {
                        ...facts[key],
                        value: event.target.value,
                      })
                    }
                    required
                  />
                </label>
                {languages.map((language) => (
                  <label key={language}>
                    {copy.facts.labels[language]}
                    <input
                      lang={language}
                      dir={language === "ur" ? "rtl" : "ltr"}
                      maxLength={120}
                      value={facts[key].label[language]}
                      onChange={(event) =>
                        updateFact(key, {
                          ...facts[key],
                          label: {
                            ...facts[key].label,
                            [language]: event.target.value,
                          },
                        })
                      }
                      required
                    />
                  </label>
                ))}
              </fieldset>
            ))}
          </div>
        </section>
      )}
      <details className="page-editor-preview">
        <summary>{copy.preview}</summary>
        <div className="page-editor-languages">
          {languages.map((language) => (
            <div
              key={language}
              lang={language}
              dir={language === "ur" ? "rtl" : "ltr"}
            >
              <h3>{title[language]}</h3>
              <p className="published-page-copy">{body[language]}</p>
              {facts && (
                <ul>
                  {homeFactKeys.map((key) => (
                    <li key={key}>
                      <bdi>{facts[key].value}</bdi> {facts[key].label[language]}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ))}
        </div>
      </details>
      {error && (
        <p className="sign-in-error" role="alert">
          {error}
        </p>
      )}
      <div className="page-editor-nav">
        <button className="button button-outline" disabled={disabled}>
          {copy.save}
        </button>
        <button
          type="button"
          className="button button-primary"
          disabled={disabled || !canPublish}
          onClick={() => void submit("publish")}
        >
          {copy.publish}
        </button>
      </div>
    </form>
  );
}
