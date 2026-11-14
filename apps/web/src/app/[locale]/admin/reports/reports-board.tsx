"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { formatAmount, formatDate } from "@/design/format";
import { pageTranslation } from "@/institutes/site-pages";
import type { ReportEntry, SpendingReport } from "@/server/transparency";

type Copy = {
  kind: string;
  kinds: { daily: string; weekly: string; custom: string };
  start: string;
  end: string;
  titleUr: string;
  titleEn: string;
  notesUr: string;
  notesEn: string;
  notesHint: string;
  entries: string;
  noEntries: string;
  save: string;
  publish: string;
  saved: string;
  published: string;
  publishedNone: string;
  notReady: string;
  entriesTaken: string;
  invalid: string;
  denied: string;
  unavailable: string;
  pending: string;
  drafts: string;
  publishedList: string;
  none: string;
};

export function ReportsBoard({
  locale,
  copy,
  today,
  entries,
  reports,
  causes,
}: {
  locale: Locale;
  copy: Copy;
  today: string;
  entries: ReportEntry[];
  reports: SpendingReport[];
  causes: { id: string; title: Partial<Record<Locale, string>> }[];
}) {
  const router = useRouter();
  const [kind, setKind] = useState<"daily" | "weekly" | "custom">("daily");
  const [start, setStart] = useState(today);
  const [end, setEnd] = useState(today);
  const [titleUr, setTitleUr] = useState("");
  const [titleEn, setTitleEn] = useState("");
  const [notesUr, setNotesUr] = useState("");
  const [notesEn, setNotesEn] = useState("");
  const [selected, setSelected] = useState<string[]>([]);
  const [notice, setNotice] = useState<string>();
  const [pending, setPending] = useState(false);
  const causeTitle = (id: string) =>
    pageTranslation(causes.find((cause) => cause.id === id)?.title, locale)?.text ??
    "";

  function periodEnd(nextKind: typeof kind, nextStart: string) {
    if (nextKind === "daily") return nextStart;
    if (nextKind !== "weekly") return end;
    const date = new Date(`${nextStart}T00:00:00Z`);
    if (Number.isNaN(date.getTime())) return nextStart;
    date.setUTCDate(date.getUTCDate() + 6);
    return date.toISOString().slice(0, 10);
  }

  async function save(event: FormEvent) {
    event.preventDefault();
    setPending(true);
    const response = await authRequest("spending-report", {
      action: "save",
      kind,
      start,
      end: kind === "custom" ? end : periodEnd(kind, start),
      titleUr,
      titleEn,
      notesUr,
      notesEn,
      entryIds: selected,
    });
    const body = (await response.json().catch(() => null)) as { code?: string } | null;
    setPending(false);
    setNotice(
      body?.code === "saved"
        ? copy.saved
        : body?.code === "entries"
          ? copy.entriesTaken
          : body?.code === "denied"
            ? copy.denied
            : body?.code === "invalid"
              ? copy.invalid
              : copy.unavailable,
    );
    if (body?.code === "saved") router.refresh();
  }

  async function publish(reportId: string) {
    setPending(true);
    const response = await authRequest("spending-report", {
      action: "publish",
      reportId,
    });
    const body = (await response.json().catch(() => null)) as {
      code?: string;
      events?: number | null;
    } | null;
    setPending(false);
    setNotice(
      body?.code === "published"
        ? body.events
          ? copy.published
          : copy.publishedNone
        : body?.code === "not_ready"
          ? copy.notReady
          : body?.code === "denied"
            ? copy.denied
            : copy.unavailable,
    );
    if (body?.code === "published") router.refresh();
  }

  const drafts = reports.filter((report) => report.status === "draft");
  const published = reports.filter((report) => report.status === "published");

  return (
    <>
      <form className="ui-card" onSubmit={(event) => void save(event)}>
        <label className="ui-field" htmlFor="report-kind">
          {copy.kind}
          <select
            id="report-kind"
            value={kind}
            onChange={(event) => {
              const next =
                event.target.value === "weekly" || event.target.value === "custom"
                  ? event.target.value
                  : "daily";
              setKind(next);
              if (next !== "custom") setEnd(periodEnd(next, start));
            }}
          >
            <option value="daily">{copy.kinds.daily}</option>
            <option value="weekly">{copy.kinds.weekly}</option>
            <option value="custom">{copy.kinds.custom}</option>
          </select>
        </label>
        <label className="ui-field" htmlFor="report-start">
          {copy.start}
          <input
            id="report-start"
            type="date"
            value={start}
            onChange={(event) => {
              setStart(event.target.value);
              if (kind !== "custom") setEnd(periodEnd(kind, event.target.value));
            }}
          />
        </label>
        {kind === "custom" && (
          <label className="ui-field" htmlFor="report-end">
            {copy.end}
            <input
              id="report-end"
              type="date"
              value={end}
              onChange={(event) => setEnd(event.target.value)}
            />
          </label>
        )}
        <label className="ui-field" htmlFor="report-title-ur">
          {copy.titleUr}
          <input
            id="report-title-ur"
            lang="ur"
            dir="rtl"
            maxLength={120}
            value={titleUr}
            onChange={(event) => setTitleUr(event.target.value)}
          />
        </label>
        <label className="ui-field" htmlFor="report-title-en">
          {copy.titleEn}
          <input
            id="report-title-en"
            lang="en"
            dir="ltr"
            maxLength={120}
            value={titleEn}
            onChange={(event) => setTitleEn(event.target.value)}
          />
        </label>
        <p>{copy.notesHint}</p>
        <label className="ui-field" htmlFor="report-notes-ur">
          {copy.notesUr}
          <textarea
            id="report-notes-ur"
            lang="ur"
            dir="rtl"
            maxLength={500}
            value={notesUr}
            onChange={(event) => setNotesUr(event.target.value)}
          />
        </label>
        <label className="ui-field" htmlFor="report-notes-en">
          {copy.notesEn}
          <textarea
            id="report-notes-en"
            lang="en"
            dir="ltr"
            maxLength={500}
            value={notesEn}
            onChange={(event) => setNotesEn(event.target.value)}
          />
        </label>
        <fieldset>
          <legend>{copy.entries}</legend>
          {entries.length === 0 ? (
            <p>{copy.noEntries}</p>
          ) : (
            entries.map((entry) => (
              <label key={entry.id}>
                <input
                  type="checkbox"
                  checked={selected.includes(entry.id)}
                  onChange={(event) =>
                    setSelected(
                      event.target.checked
                        ? [...selected, entry.id]
                        : selected.filter((id) => id !== entry.id),
                    )
                  }
                />
                <time dateTime={entry.spent_on}>{formatDate(entry.spent_on, locale)}</time>{" "}
                {causeTitle(entry.cause_id)}{" "}
                {formatAmount(BigInt(entry.amount_paisa), locale)}{" "}
                {pageTranslation(entry.description, locale)?.text}
              </label>
            ))
          )}
        </fieldset>
        {notice && <p role="status">{notice}</p>}
        <button className="ui-button ui-button-primary" type="submit" disabled={pending}>
          {pending ? copy.pending : copy.save}
        </button>
      </form>
      <section aria-labelledby="report-drafts-title">
        <h2 id="report-drafts-title">{copy.drafts}</h2>
        {drafts.length === 0 ? (
          <p>{copy.none}</p>
        ) : (
          <ul className="wall-list">
            {drafts.map((report) => (
              <li className="wall-row" key={report.id}>
                <span>{pageTranslation(report.title, locale)?.text}</span>
                <time dateTime={report.period_start}>{formatDate(report.period_start, locale)}</time>
                <button
                  type="button"
                  className="ui-button ui-button-secondary"
                  disabled={pending}
                  onClick={() => void publish(report.id)}
                >
                  {copy.publish}
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
      <section aria-labelledby="report-published-title">
        <h2 id="report-published-title">{copy.publishedList}</h2>
        {published.length === 0 ? (
          <p>{copy.none}</p>
        ) : (
          <ul className="wall-list">
            {published.map((report) => (
              <li className="wall-row" key={report.id}>
                <span>{pageTranslation(report.title, locale)?.text}</span>
                <time dateTime={report.period_end}>{formatDate(report.period_end, locale)}</time>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
