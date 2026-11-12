"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { causeCopy } from "@/institutes/cause-copy";
import {
  causeKinds,
  causeLimits,
  type CauseKind,
  type EditableCause,
} from "@/institutes/causes";
import { pageTranslation } from "@/institutes/site-pages";

const languages = { en: "English", ur: "اردو" } as const;

function targetInRupees(value: string | null | undefined) {
  if (!value) return "";
  const paisa = BigInt(value);
  const rupees = paisa / 100n;
  const remainder = paisa % 100n;
  return remainder
    ? `${rupees}.${String(remainder).padStart(2, "0")}`
    : String(rupees);
}

export function CauseManager({
  locale,
  causes,
}: {
  locale: Locale;
  causes: EditableCause[];
}) {
  const router = useRouter();
  const labels = causeCopy[locale];
  const copy = labels.admin;
  const [kind, setKind] = useState<CauseKind>("campaign");
  const [editing, setEditing] = useState<EditableCause>();
  const [zakat, setZakat] = useState(false);
  const heading = useRef<HTMLHeadingElement>(null);
  const formKind = editing?.cause_type ?? kind;
  const settingsLocked =
    !!editing &&
    (editing.status === "closed" || editing.has_recorded_allocations);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<{
    message: string;
    error: boolean;
    location: "form" | "list";
  }>();
  const month = new Intl.DateTimeFormat(`${locale}-PK`, {
    month: "long",
    timeZone: "UTC",
  });
  useEffect(() => {
    if (editing) heading.current?.focus();
  }, [editing]);

  async function send(
    body: Record<string, unknown>,
    location: "form" | "list",
  ) {
    setPending(true);
    setNotice(undefined);
    try {
      const response = await authRequest("cause", body);
      const result = await response.json();
      if (response.ok) {
        setNotice({
          message: body.action === "create" ? copy.created : copy.updated,
          error: false,
          location,
        });
        router.refresh();
        return true;
      }
      const messages: Record<string, string> = {
        duplicate: copy.duplicate,
        stale: copy.stale,
        invalid: copy.invalid,
        settings_locked: copy.settingsLocked,
        archive_blocked: copy.archiveBlocked,
      };
      const message = messages[result.code] ?? copy.unavailable;
      setNotice({ message, error: true, location });
    } catch {
      setNotice({ message: copy.unavailable, error: true, location });
    } finally {
      setPending(false);
    }
    return false;
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const fields = new FormData(form);
    const pair = (name: string) => ({
      en: fields.get(`${name}-en`),
      ur: fields.get(`${name}-ur`),
    });
    if (
      await send(
        {
          action: editing ? "edit" : "create",
          id: editing?.id,
          revision: editing?.revision,
          kind: formKind,
          slug: fields.get("slug"),
          title: pair("title"),
          summary: pair("summary"),
          body: pair("body"),
          target: fields.get("target"),
          starts: settingsLocked
            ? (editing?.starts_on ?? "")
            : fields.get("starts"),
          ends: settingsLocked
            ? (editing?.ends_on ?? "")
            : (fields.get("ends") ?? ""),
          period: settingsLocked
            ? editing?.target_period
            : fields.get("period"),
          stockMonth: settingsLocked
            ? editing?.stock_year_start_month
            : Number(fields.get("stockMonth")),
          zakat,
          scholar: zakat ? pair("scholar") : null,
          receiptPublicByDefault: fields.has("receiptPublicByDefault"),
        },
        "form",
      )
    ) {
      form.reset();
      setKind("campaign");
      setEditing(undefined);
      setZakat(false);
    }
  }

  function transition(
    cause: EditableCause,
    action: "publish" | "close" | "archive",
  ) {
    if (action === "archive" && !window.confirm(copy.archiveConfirm)) return;
    void send({ action, id: cause.id, revision: cause.revision }, "list");
  }

  return (
    <>
      <form
        key={editing?.id ?? "new"}
        className="sign-in-form page-editor-form"
        onSubmit={save}
      >
        <h2 ref={heading} tabIndex={-1}>
          {editing ? copy.editTitle : copy.new}
        </h2>
        <div className="cause-field-grid">
          <label>
            {copy.slug}
            <input
              name="slug"
              maxLength={causeLimits.slug}
              pattern="[a-z0-9]+(?:-[a-z0-9]+)*"
              autoCapitalize="none"
              spellCheck={false}
              lang="en"
              dir="ltr"
              aria-describedby="cause-slug-help"
              defaultValue={editing?.slug}
              readOnly={!!editing}
              required
            />
            <small id="cause-slug-help">{copy.slugHelp}</small>
          </label>
          <label>
            {copy.kind}
            <select
              name="kind"
              value={formKind}
              disabled={!!editing}
              onChange={(event) => setKind(event.target.value as CauseKind)}
            >
              {causeKinds.map((item) => (
                <option key={item} value={item}>
                  {labels.kinds[item]}
                </option>
              ))}
            </select>
          </label>
        </div>
        <div className="page-editor-languages">
          {(Object.keys(languages) as Locale[]).map((language) => (
            <fieldset key={language}>
              <legend lang={language}>{languages[language]}</legend>
              <label>
                {copy.titleField}
                <input
                  name={`title-${language}`}
                  lang={language}
                  dir={language === "ur" ? "rtl" : "ltr"}
                  maxLength={causeLimits.title}
                  defaultValue={editing?.title[language]}
                  required
                />
              </label>
              <label>
                {copy.summary}
                <textarea
                  name={`summary-${language}`}
                  lang={language}
                  dir={language === "ur" ? "rtl" : "ltr"}
                  maxLength={causeLimits.summary}
                  defaultValue={editing?.summary[language]}
                  rows={3}
                  required
                />
              </label>
              <label>
                {copy.body}
                <textarea
                  name={`body-${language}`}
                  lang={language}
                  dir={language === "ur" ? "rtl" : "ltr"}
                  maxLength={causeLimits.body}
                  defaultValue={editing?.body?.[language]}
                  rows={5}
                />
              </label>
            </fieldset>
          ))}
        </div>
        <div className="cause-field-grid">
          <label>
            {formKind === "campaign" ? copy.target : copy.optionalTarget}
            <input
              name="target"
              inputMode="decimal"
              pattern="[0-9]{1,12}(?:\.[0-9]{1,2})?"
              dir="ltr"
              placeholder="50000"
              defaultValue={targetInRupees(editing?.target_paisa)}
              required={formKind === "campaign"}
            />
          </label>
          <label>
            {copy.starts}
            <input
              type="date"
              name="starts"
              max="9999-12-31"
              defaultValue={editing?.starts_on ?? ""}
              disabled={settingsLocked}
            />
          </label>
          {formKind === "campaign" && (
            <label>
              {copy.ends}
              <input
                type="date"
                name="ends"
                max="9999-12-31"
                defaultValue={editing?.ends_on ?? ""}
                disabled={settingsLocked}
                required
              />
            </label>
          )}
          {formKind === "ongoing" && (
            <label>
              {copy.period}
              <select
                name="period"
                defaultValue={editing?.target_period ?? "monthly"}
                disabled={settingsLocked}
              >
                <option value="monthly">{copy.monthly}</option>
                <option value="yearly">{copy.yearly}</option>
              </select>
            </label>
          )}
          {formKind === "yearly_stock" && (
            <label>
              {copy.stockMonth}
              <select
                name="stockMonth"
                defaultValue={editing?.stock_year_start_month ?? 1}
                disabled={settingsLocked}
              >
                {Array.from({ length: 12 }, (_, index) => (
                  <option key={index} value={index + 1}>
                    {month.format(Date.UTC(2000, index, 1))}
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>
        <label className="cause-zakat">
          <input
            type="checkbox"
            name="zakat"
            checked={zakat}
            onChange={(event) => setZakat(event.target.checked)}
            disabled={settingsLocked}
          />
          {copy.zakat}
        </label>
        <fieldset className="cause-field-grid cause-scholar" hidden={!zakat}>
          <legend>{copy.scholar}</legend>
          {(Object.keys(languages) as Locale[]).map((language) => (
            <label key={language}>
              <span lang={language}>{languages[language]}</span>
              <input
                name={`scholar-${language}`}
                lang={language}
                dir="auto"
                maxLength={causeLimits.scholar}
                defaultValue={editing?.zakat_approved_by?.[language]}
              />
            </label>
          ))}
        </fieldset>
        <label className="cause-zakat">
          <input
            type="checkbox"
            name="receiptPublicByDefault"
            defaultChecked={editing?.receipt_public_by_default}
          />
          {copy.receiptPublicByDefault}
        </label>
        {settingsLocked && <p>{copy.settingsLocked}</p>}
        <div className="sign-in-alternatives">
          <button
            className="button button-primary"
            disabled={pending}
            type="submit"
          >
            {pending ? copy.working : editing ? copy.save : copy.create}
          </button>
          {editing && (
            <button
              className="button button-outline"
              disabled={pending}
              type="button"
              onClick={() => {
                setEditing(undefined);
                setZakat(false);
                setNotice(undefined);
              }}
            >
              {copy.cancel}
            </button>
          )}
        </div>
        {notice?.location === "form" && (
          <p
            role={notice.error ? "alert" : "status"}
            className={notice.error ? "sign-in-error" : undefined}
          >
            {notice.message}
          </p>
        )}
      </form>
      <section aria-labelledby="admin-causes-list">
        <h2 id="admin-causes-list">{copy.list}</h2>
        {causes.length ? (
          <>
            <p>{copy.closeHelp}</p>
            <ul className="admin-cause-list" role="list">
              {causes.map((cause) => {
                const title = pageTranslation(cause.title, locale);
                return (
                  <li key={cause.id} className="admin-cause">
                    <div>
                      <h3
                        lang={title?.language}
                        dir={title?.language === "ur" ? "rtl" : "ltr"}
                      >
                        {title?.text ?? cause.slug}
                      </h3>
                      <p>
                        {labels.kinds[cause.cause_type]} ·{" "}
                        {labels.status[cause.status]}
                      </p>
                      <bdi dir="ltr">{cause.slug}</bdi>
                      {cause.status === "closed" &&
                        cause.has_recorded_allocations && (
                          <p>{copy.archiveBlocked}</p>
                        )}
                    </div>
                    <div className="admin-cause-actions">
                      {cause.status !== "archived" && (
                        <button
                          className="button button-outline"
                          disabled={pending || !!editing}
                          type="button"
                          onClick={() => {
                            setEditing(cause);
                            setZakat(cause.accepts_zakat);
                            setNotice(undefined);
                          }}
                        >
                          {copy.edit}
                        </button>
                      )}
                      {cause.status === "draft" && (
                        <button
                          className="button button-outline"
                          disabled={pending || editing?.id === cause.id}
                          type="button"
                          onClick={() => transition(cause, "publish")}
                        >
                          {copy.publish}
                        </button>
                      )}
                      {cause.status === "active" && (
                        <button
                          className="button button-outline"
                          disabled={pending || editing?.id === cause.id}
                          type="button"
                          onClick={() => transition(cause, "close")}
                        >
                          {copy.close}
                        </button>
                      )}
                      {cause.status === "closed" &&
                        !cause.has_recorded_allocations && (
                          <button
                            className="button button-outline"
                            disabled={pending || editing?.id === cause.id}
                            type="button"
                            onClick={() => transition(cause, "archive")}
                          >
                            {copy.archive}
                          </button>
                        )}
                    </div>
                  </li>
                );
              })}
            </ul>
          </>
        ) : (
          <p>{copy.empty}</p>
        )}
        {notice?.location === "list" && (
          <p
            role={notice.error ? "alert" : "status"}
            className={notice.error ? "sign-in-error" : undefined}
          >
            {notice.message}
          </p>
        )}
      </section>
    </>
  );
}
