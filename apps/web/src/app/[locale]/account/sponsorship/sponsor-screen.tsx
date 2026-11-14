"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useEffect, useState } from "react";
import { authRequest } from "@/components/auth-request";
import {
  pageTranslation,
  type LocalizedPageText,
} from "@/institutes/site-pages";
import { sponsorCopy } from "./sponsor-copy";

type Update = {
  id: string;
  body: LocalizedPageText;
  published_at: string;
};
type Child = {
  sponsorship_id: string;
  persona_name: string;
  age_years: number | null;
  updates: Update[];
  full_profile: boolean;
  full_name: string | null;
  class_names: LocalizedPageText[];
};
type Message = {
  id: string;
  direction: "to_madrasa" | "to_sponsor";
  body: string;
  language: string;
  created_at: string;
};

export function SponsorScreen({ locale }: { locale: Locale }) {
  const copy = sponsorCopy[locale];
  const [children, setChildren] = useState<Child[] | null>(null);
  const [error, setError] = useState("");
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    const request = new AbortController();
    void authRequest("sponsor", { action: "children" })
      .then(async (response) => {
        const result = await response.json();
        if (
          !response.ok ||
          result.code !== "ok" ||
          !Array.isArray(result.children)
        )
          throw new Error();
        if (!request.signal.aborted) setChildren(result.children);
      })
      .catch(() => {
        if (!request.signal.aborted) setError(copy.unavailable);
      });
    return () => request.abort();
  }, [copy.unavailable, retry]);

  if (error) {
    return (
      <div className="community-message">
        <p role="alert">{error}</p>
        <button
          type="button"
          className="ui-button ui-button-secondary"
          onClick={() => {
            setError("");
            setChildren(null);
            setRetry((value) => value + 1);
          }}
        >
          {copy.retry}
        </button>
      </div>
    );
  }
  if (!children) return <p role="status">{copy.loading}</p>;
  if (!children.length) return <p role="status">{copy.empty}</p>;

  return (
    <div className="sponsor-list">
      {children.map((child) => (
        <ChildCard key={child.sponsorship_id} child={child} locale={locale} />
      ))}
    </div>
  );
}

function ChildCard({ child, locale }: { child: Child; locale: Locale }) {
  const copy = sponsorCopy[locale];
  const [messages, setMessages] = useState<Message[] | null>(null);
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [language, setLanguage] = useState<Locale>(locale);

  useEffect(() => {
    void authRequest("sponsor", {
      action: "messages",
      sponsorshipId: child.sponsorship_id,
    })
      .then(async (response) => {
        const result = await response.json();
        if (response.ok && Array.isArray(result.messages))
          setMessages(result.messages);
      })
      .catch(() => setMessages([]));
  }, [child.sponsorship_id, notice]);

  async function send(form: FormData) {
    if (busy) return;
    setBusy(true);
    setNotice("");
    try {
      const response = await authRequest("sponsor", {
        action: "send",
        sponsorshipId: child.sponsorship_id,
        body: String(form.get("body") ?? ""),
        language,
      });
      const result = await response.json();
      setNotice(
        result.code === "sent"
          ? copy.sent
          : result.code === "contact_details"
            ? copy.contactBlocked
            : copy.sendUnavailable,
      );
    } catch {
      setNotice(copy.sendUnavailable);
    } finally {
      setBusy(false);
    }
  }

  return (
    <article className="ui-card sponsor-card">
      <header>
        <h2>
          <bdi>{child.persona_name}</bdi>
        </h2>
        <p>
          {child.age_years === null
            ? copy.ageUnknown
            : copy.age.replace("{years}", String(child.age_years))}
        </p>
      </header>
      <section aria-labelledby={`updates-${child.sponsorship_id}`}>
        <h3 id={`updates-${child.sponsorship_id}`}>{copy.updates}</h3>
        {child.updates.length ? (
          <ul className="sponsor-updates">
            {child.updates.map((update) => {
              const text = pageTranslation(update.body, locale);
              return (
                <li key={update.id}>
                  <time dateTime={update.published_at}>
                    {new Intl.DateTimeFormat(`${locale}-PK`, {
                      dateStyle: "medium",
                      timeZone: "Asia/Karachi",
                    }).format(new Date(update.published_at))}
                  </time>
                  {text && (
                    <p lang={text.language} dir="auto">
                      {text.text}
                    </p>
                  )}
                </li>
              );
            })}
          </ul>
        ) : (
          <p>{copy.noUpdates}</p>
        )}
      </section>
      <section aria-labelledby={`profile-${child.sponsorship_id}`}>
        <h3 id={`profile-${child.sponsorship_id}`}>{copy.fullProfile}</h3>
        {child.full_profile ? (
          <>
            {child.full_name && (
              <p>
                <bdi>{child.full_name}</bdi>
              </p>
            )}
            <h4>{copy.classes}</h4>
            {child.class_names.length ? (
              <ul>
                {child.class_names.map((name, index) => {
                  const text = pageTranslation(name, locale);
                  return (
                    <li key={index}>
                      {text ? (
                        <bdi lang={text.language}>{text.text}</bdi>
                      ) : null}
                    </li>
                  );
                })}
              </ul>
            ) : (
              <p>{copy.noClasses}</p>
            )}
            <p className="donate-note">{copy.photoHeld}</p>
          </>
        ) : (
          <p>{copy.limited}</p>
        )}
      </section>
      <section aria-labelledby={`messages-${child.sponsorship_id}`}>
        <h3 id={`messages-${child.sponsorship_id}`}>{copy.messages}</h3>
        {messages?.length ? (
          <ol className="sponsor-messages">
            {messages.map((message) => (
              <li key={message.id} lang={message.language} dir="auto">
                <strong>
                  {message.direction === "to_madrasa"
                    ? copy.fromYou
                    : copy.fromMadrasa}
                </strong>
                <p>{message.body}</p>
              </li>
            ))}
          </ol>
        ) : (
          <p>{copy.noMessages}</p>
        )}
        <form
          className="community-form"
          onSubmit={(event) => {
            event.preventDefault();
            const form = event.currentTarget;
            void send(new FormData(form)).then(() => form.reset());
          }}
        >
          <fieldset>
            <legend>{copy.language}</legend>
            {(
              [
                ["ur", copy.urdu],
                ["en", copy.english],
              ] as const
            ).map(([value, label]) => (
              <label key={value}>
                <input
                  type="radio"
                  name="language"
                  checked={language === value}
                  onChange={() => setLanguage(value)}
                />
                {label}
              </label>
            ))}
          </fieldset>
          <label>
            {copy.write}
            <textarea
              name="body"
              required
              maxLength={2000}
              rows={4}
              dir="auto"
              placeholder={copy.placeholder}
            />
          </label>
          <button
            className="ui-button ui-button-primary"
            type="submit"
            disabled={busy}
          >
            {busy ? copy.sending : copy.send}
          </button>
          {notice && <p role="status">{notice}</p>}
        </form>
      </section>
    </article>
  );
}
