"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import {
  Alert,
  Badge,
  Button,
  EmptyState,
  SelectField,
  TextAreaField,
} from "@/design/ui";
import { pageTranslation } from "@/institutes/site-pages";
import type { ProgressChild, ProgressUpdate } from "@/server/progress";

type Copy = typeof common.staffProgress;

export function ProgressBoard({
  locale,
  copy,
  isAdmin,
  pupils,
  updates,
}: {
  locale: Locale;
  copy: Copy;
  isAdmin: boolean;
  pupils: ProgressChild[];
  updates: ProgressUpdate[];
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [warning, setWarning] = useState("");

  async function send(body: Record<string, unknown>) {
    setBusy(true);
    setMessage("");
    setWarning("");
    const response = await authRequest("progress", body);
    const result = (await response.json().catch(() => null)) as {
      code?: string;
    } | null;
    setBusy(false);
    const code = result?.code;
    if (code === "published") setMessage(isAdmin ? copy.published : copy.published);
    else if (code === "waiting") setMessage(copy.waiting);
    else if (code === "hidden") setMessage(copy.hiddenNow);
    else if (code === "contact_details") setWarning(copy.contactBlocked);
    else if (code === "real_name") setWarning(copy.realNameBlocked);
    else if (code === "denied") setWarning(copy.denied);
    else if (code === "invalid") setWarning(copy.invalid);
    else setWarning(copy.unavailable);
    router.refresh();
  }

  function onWrite(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    void send({
      action: "write",
      personaId: String(data.get("personaId") ?? ""),
      urdu: String(data.get("urdu") ?? ""),
      english: String(data.get("english") ?? ""),
    });
  }

  return (
    <>
      <section className="ui-card" aria-labelledby="progress-form">
        <h2 id="progress-form">{copy.composer}</h2>
        <p>{copy.noPhoto}</p>
        {pupils.length ? (
          <form className="ui-form" onSubmit={onWrite}>
            <SelectField id="progress-child" name="personaId" label={copy.child} required defaultValue="">
              <option value="">{copy.choose}</option>
              {pupils.map((child) => (
                <option key={child.persona_id} value={child.persona_id}>
                  {child.persona}
                  {child.real_name ? ` · ${child.real_name}` : ""}
                </option>
              ))}
            </SelectField>
            <TextAreaField id="progress-ur" name="urdu" label={copy.urdu} maxLength={2000} lang="ur" dir="rtl" />
            <TextAreaField id="progress-en" name="english" label={copy.english} maxLength={2000} lang="en" dir="ltr" />
            <p className="ui-hint">{copy.oneLanguage}</p>
            <Button type="submit" disabled={busy}>
              {busy ? copy.pending : copy.save}
            </Button>
          </form>
        ) : (
          <EmptyState title={copy.noChildren}>{copy.intro}</EmptyState>
        )}
      </section>
      <section className="ui-card" aria-labelledby="progress-list">
        <h2 id="progress-list">{copy.updates}</h2>
        {updates.length ? (
          <ul className="cause-grid">
            {updates.map((update) => {
              const text = pageTranslation(update.body, locale);
              return (
                <li className="ui-card" key={update.id}>
                  <h3>
                    <bdi>{update.persona}</bdi>
                  </h3>
                  <Badge tone={update.published && !update.hidden ? "verified" : "warning"}>
                    {update.hidden
                      ? copy.hidden
                      : update.published
                        ? copy.publishedState
                        : copy.waitingState}
                  </Badge>
                  {text && (
                    <p lang={text.language} dir="auto">
                      {text.text}
                    </p>
                  )}
                  {isAdmin && !update.published && !update.hidden && (
                    <Button disabled={busy} onClick={() => void send({ action: "publish", updateId: update.id })}>
                      {copy.publish}
                    </Button>
                  )}
                  {isAdmin && update.published && !update.hidden && (
                    <Button variant="danger" disabled={busy} onClick={() => void send({ action: "hide", updateId: update.id })}>
                      {copy.hide}
                    </Button>
                  )}
                </li>
              );
            })}
          </ul>
        ) : (
          <EmptyState title={copy.noUpdates}>{copy.updatesIntro}</EmptyState>
        )}
      </section>
      {message && <Alert tone="success">{message}</Alert>}
      {warning && <Alert tone="danger">{warning}</Alert>}
    </>
  );
}
