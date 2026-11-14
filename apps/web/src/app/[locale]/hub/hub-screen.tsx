"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import {
  pageTranslation,
  type LocalizedPageText,
} from "@/institutes/site-pages";
import { hubCopy } from "./hub-copy";

type ClassRow = { id: string; name: LocalizedPageText };
type ThreadRow = {
  id: string;
  title: string | null;
  language: string;
  scope: string;
  reply_count: number;
  last_post_at: string;
  locked: boolean;
};
type PostRow = {
  id: string;
  post_type: string;
  language: string;
  title: string | null;
  body: string | null;
  created_at: string;
  parent_post_id: string | null;
  author_name: string;
  author_kind: "persona" | "staff";
  hidden: boolean;
};
type HubResult =
  | { state: "loading" }
  | { state: "error"; code: string }
  | { state: "classes"; classes: ClassRow[] }
  | { state: "threads"; threads: ThreadRow[] }
  | {
      state: "thread";
      title: string | null;
      locked: boolean;
      scope: string;
      posts: PostRow[];
    };

const reportReasons = [
  "personal_details",
  "face_or_name",
  "unkind",
  "wrong_information",
  "other",
] as const;

export function HubScreen({
  locale,
  classId,
  threadId,
}: {
  locale: Locale;
  classId?: string;
  threadId?: string;
}) {
  const copy = hubCopy[locale];
  const router = useRouter();
  const [result, setResult] = useState<HubResult>({ state: "loading" });
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    const request = new AbortController();
    const body = threadId
      ? { action: "read", threadId }
      : classId
        ? {
            action: "read",
            scope: classId === "madrasa" ? "madrasa" : "class",
            classId: classId === "madrasa" ? undefined : classId,
          }
        : { action: "read" };
    void authRequest("hub", body)
      .then(async (response) => {
        const payload = await response.json();
        if (request.signal.aborted) return;
        if (payload.code !== "ok") {
          setResult({ state: "error", code: payload.code ?? "unavailable" });
          return;
        }
        if (payload.thread) {
          setResult({
            state: "thread",
            title: payload.thread.title,
            locked: payload.thread.locked,
            scope: payload.thread.scope,
            posts: payload.posts ?? [],
          });
        } else if (payload.threads) {
          setResult({ state: "threads", threads: payload.threads });
        } else {
          setResult({ state: "classes", classes: payload.classes ?? [] });
        }
      })
      .catch(() => {
        if (!request.signal.aborted)
          setResult({ state: "error", code: "unavailable" });
      });
    return () => request.abort();
  }, [classId, threadId, version]);

  async function submit(
    event: FormEvent<HTMLFormElement>,
    action: "start" | "reply",
  ) {
    event.preventDefault();
    if (busy) return;
    const form = event.currentTarget;
    const fields = new FormData(form);
    setBusy(true);
    setNotice("");
    const language = String(fields.get("language") ?? locale);
    const response = await authRequest(
      "hub",
      action === "start"
        ? {
            action,
            scope: classId === "madrasa" ? "madrasa" : "class",
            classId: classId === "madrasa" ? undefined : classId,
            postType: String(fields.get("postType") ?? "message"),
            language,
            title: String(fields.get("title") ?? ""),
            body: String(fields.get("body") ?? ""),
          }
        : {
            action,
            threadId,
            parentId: String(fields.get("parentId") ?? "") || undefined,
            postType: String(fields.get("postType") ?? "message"),
            language,
            body: String(fields.get("body") ?? ""),
          },
    ).catch(() => null);
    const payload = await response?.json().catch(() => null);
    const code = payload?.code;
    setBusy(false);
    if (code === "posted") {
      form.reset();
      setNotice(classId === "madrasa" ? copy.postedMadrasa : copy.posted);
      if (action === "start" && payload.thread_id) {
        router.push(`/${locale}/hub?thread=${payload.thread_id}`);
        return;
      }
      setVersion((value) => value + 1);
      return;
    }
    setNotice(
      code === "contact_details" ? copy.contactBlocked : copy.unavailable,
    );
  }

  if (result.state === "loading") return <p role="status">{copy.loading}</p>;
  if (result.state === "error") {
    const message =
      result.code === "module_off"
        ? copy.moduleOff
        : result.code === "denied"
          ? copy.denied
          : copy.unavailable;
    return (
      <div className="community-message">
        <p role="alert">{message}</p>
        {result.code !== "module_off" && result.code !== "denied" && (
          <button
            type="button"
            className="ui-button ui-button-secondary"
            onClick={() => {
              setResult({ state: "loading" });
              setVersion((value) => value + 1);
            }}
          >
            {copy.retry}
          </button>
        )}
      </div>
    );
  }

  if (result.state === "classes") {
    return (
      <>
        <p className="community-note">{copy.consent}</p>
        {result.classes.length ? (
          <ul className="hub-list">
            {result.classes.map((item) => {
              const name = pageTranslation(item.name, locale);
              return (
                <li key={item.id}>
                  <a
                    className="ui-card hub-card"
                    href={`/${locale}/hub?class=${item.id}`}
                  >
                    {name ? (
                      <bdi lang={name.language}>{name.text}</bdi>
                    ) : (
                      item.id
                    )}
                  </a>
                </li>
              );
            })}
          </ul>
        ) : (
          <p role="status">{copy.emptyClasses}</p>
        )}
        <a
          className="ui-button ui-button-secondary"
          href={`/${locale}/hub?class=madrasa`}
        >
          {copy.madrasa}
        </a>
      </>
    );
  }

  if (result.state === "threads") {
    return (
      <>
        <a href={`/${locale}/hub`}>{copy.back}</a>
        <p>{classId === "madrasa" ? copy.whoMadrasa : copy.whoClass}</p>
        <form
          className="community-form"
          onSubmit={(event) => void submit(event, "start")}
        >
          <h2>{copy.newPost}</h2>
          <div className="hub-choices">
            <label>
              <input
                type="radio"
                name="postType"
                value="message"
                defaultChecked
              />
              {copy.message}
            </label>
            <label>
              <input type="radio" name="postType" value="question" />
              {copy.question}
            </label>
          </div>
          <LanguageFields locale={locale} />
          <label>
            {copy.questionTitle}
            <input name="title" maxLength={200} dir="auto" />
          </label>
          <label>
            {copy.details}
            <textarea name="body" required maxLength={4000} dir="auto" />
          </label>
          <button
            className="ui-button ui-button-primary"
            type="submit"
            disabled={busy}
          >
            {busy ? copy.posting : copy.post}
          </button>
          {notice && <p role="status">{notice}</p>}
        </form>
        {result.threads.length ? (
          <ul className="hub-list">
            {result.threads.map((thread) => (
              <li key={thread.id}>
                <a
                  className="ui-card hub-card"
                  href={`/${locale}/hub?thread=${thread.id}`}
                >
                  <bdi lang={thread.language} dir="auto">
                    {thread.title || copy.message}
                  </bdi>
                  <small>
                    {copy.replies.replace(
                      "{count}",
                      String(thread.reply_count),
                    )}
                  </small>
                </a>
              </li>
            ))}
          </ul>
        ) : (
          <p role="status">{copy.emptyThreads}</p>
        )}
      </>
    );
  }

  return (
    <>
      <a href={`/${locale}/hub`}>{copy.back}</a>
      <h2 lang={result.posts[0]?.language} dir="auto">
        <bdi>{result.title || copy.threads}</bdi>
      </h2>
      <p>{result.scope === "madrasa" ? copy.whoMadrasa : copy.whoClass}</p>
      <ol className="hub-posts">
        {result.posts.map((post) => (
          <li key={post.id} lang={post.language} dir="auto">
            <strong>
              <bdi>{post.author_name}</bdi>
              {post.author_kind === "staff" ? ` · ${copy.teacher}` : ""}
            </strong>
            {post.hidden && <p>{copy.hidden}</p>}
            {post.title && <h3>{post.title}</h3>}
            {post.body && <p>{post.body}</p>}
            <ReportForm locale={locale} postId={post.id} />
          </li>
        ))}
      </ol>
      {result.locked ? (
        <p>{copy.locked}</p>
      ) : (
        <form
          className="community-form"
          onSubmit={(event) => void submit(event, "reply")}
        >
          <LanguageFields locale={locale} />
          <label>
            {copy.reply}
            <textarea
              name="body"
              required
              maxLength={4000}
              dir="auto"
              placeholder={copy.replyPlaceholder}
            />
          </label>
          <button
            className="ui-button ui-button-primary"
            type="submit"
            disabled={busy}
          >
            {busy ? copy.posting : copy.reply}
          </button>
          {notice && <p role="status">{notice}</p>}
        </form>
      )}
    </>
  );
}

function LanguageFields({ locale }: { locale: Locale }) {
  const copy = hubCopy[locale];
  return (
    <fieldset>
      <legend>{copy.language}</legend>
      <label>
        <input
          type="radio"
          name="language"
          value="ur"
          defaultChecked={locale === "ur"}
        />
        {copy.urdu}
      </label>
      <label>
        <input
          type="radio"
          name="language"
          value="en"
          defaultChecked={locale === "en"}
        />
        {copy.english}
      </label>
    </fieldset>
  );
}

function ReportForm({ locale, postId }: { locale: Locale; postId: string }) {
  const copy = hubCopy[locale];
  const [open, setOpen] = useState(false);
  const [status, setStatus] = useState("");
  if (!open) {
    return (
      <button
        type="button"
        className="ui-button ui-button-secondary"
        onClick={() => setOpen(true)}
      >
        {copy.report}
      </button>
    );
  }
  return (
    <form
      className="community-form"
      onSubmit={async (event) => {
        event.preventDefault();
        const fields = new FormData(event.currentTarget);
        const response = await authRequest("hub", {
          action: "report",
          postId,
          reason: String(fields.get("reason")),
          note: String(fields.get("note") ?? ""),
        }).catch(() => null);
        const payload = await response?.json().catch(() => null);
        setStatus(
          payload?.code === "reported"
            ? copy.reported
            : payload?.code === "already"
              ? copy.alreadyReported
              : payload?.code === "contact_details"
                ? copy.contactBlocked
                : copy.unavailable,
        );
      }}
    >
      <label>
        {copy.reportReason}
        <select name="reason" required defaultValue="unkind">
          {reportReasons.map((reason) => (
            <option key={reason} value={reason}>
              {copy.reasons[reason]}
            </option>
          ))}
        </select>
      </label>
      <label>
        {copy.reportNote}
        <textarea name="note" maxLength={300} dir="auto" />
      </label>
      <button className="ui-button ui-button-secondary" type="submit">
        {copy.sendReport}
      </button>
      {status && <p role="status">{status}</p>}
    </form>
  );
}
