"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";

export function StaffInvitationForm({
  copy,
  locale,
}: {
  copy: typeof common.staffInvite;
  locale: "en" | "ur";
}) {
  const [link, setLink] = useState("");
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    const fields = new FormData(event.currentTarget);
    setBusy(true);
    setLink("");
    setNotice("");
    setError("");
    try {
      const response = await authRequest("staff-invite", {
        name: String(fields.get("name")),
        email: String(fields.get("email")),
        role: String(fields.get("role")),
        language: String(fields.get("language")),
      });
      if (!response.ok) {
        setError(response.status === 409 ? copy.conflict : copy.issueError);
        return;
      }
      const result: { link: string } = await response.json();
      setLink(result.link);
    } catch {
      setError(copy.issueError);
    } finally {
      setBusy(false);
    }
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(link);
      setNotice(copy.copied);
    } catch {
      setNotice(copy.copyManually);
    }
  }

  return (
    <section
      className="sign-in-form"
      aria-labelledby="staff-invitation-heading"
    >
      <h2 id="staff-invitation-heading">{copy.heading}</h2>
      <form
        className="sign-in-form"
        method="post"
        onSubmit={submit}
        aria-busy={busy}
      >
        <label>
          {copy.name}
          <input
            name="name"
            autoComplete="off"
            dir="auto"
            maxLength={120}
            required
          />
        </label>
        <label>
          {copy.email}
          <input
            name="email"
            type="email"
            autoComplete="off"
            dir="ltr"
            maxLength={254}
            required
          />
        </label>
        <label>
          {copy.role}
          <select name="role" required defaultValue="">
            <option value="" disabled>
              {copy.selectRole}
            </option>
            <option value="teacher">{copy.teacher}</option>
            <option value="editor">{copy.editor}</option>
            <option value="finance_officer">{copy.finance}</option>
          </select>
        </label>
        <label>
          {copy.language}
          <select name="language" defaultValue={locale} required>
            <option value="en">{copy.english}</option>
            <option value="ur">{copy.urdu}</option>
          </select>
        </label>
        {error && (
          <p className="sign-in-error" role="alert">
            {error}
          </p>
        )}
        <button className="button button-primary" disabled={busy}>
          {copy.issue}
        </button>
      </form>
      {link && (
        <div className="sign-in-form">
          <p role="status">{copy.share}</p>
          <label>
            {copy.link}
            <input
              value={link}
              readOnly
              dir="ltr"
              onFocus={(event) => event.currentTarget.select()}
            />
          </label>
          <button
            className="button button-outline"
            type="button"
            onClick={copyLink}
          >
            {copy.copy}
          </button>
          {notice && <p role="status">{notice}</p>}
        </div>
      )}
    </section>
  );
}
