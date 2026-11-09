"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import "./donor-link-form.css";

export function DonorLinkForm({
  copy,
  locale,
}: {
  copy: typeof common.donorLinks;
  locale: Locale;
}) {
  const [action, setAction] = useState<"issue" | "revoke">("issue");
  const [pending, setPending] = useState(false);
  const [code, setCode] = useState("");
  const [link, setLink] = useState("");
  const [copyStatus, setCopyStatus] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    const form = event.currentTarget;
    const fields = new FormData(form);
    setPending(true);
    setCode("");
    setLink("");
    setCopyStatus("");
    try {
      const response = await authRequest("donor-link", {
        action,
        receipt: fields.get("receipt"),
        confirm: fields.has("confirm"),
        ...(action === "issue" && {
          email: fields.get("email"),
          language: fields.get("language"),
        }),
      });
      const result = await response.json();
      setCode(
        result.code ?? (response.status === 403 ? "denied" : "unavailable"),
      );
      if (response.ok) {
        form.reset();
        if (result.code === "issued" && typeof result.link === "string")
          setLink(result.link);
      }
    } catch {
      setCode("unavailable");
    } finally {
      setPending(false);
    }
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(link);
      setCopyStatus(copy.copied);
    } catch {
      setCopyStatus(copy.copyManually);
    }
  }

  return (
    <>
      <form
        className="sign-in-form donor-link-form"
        method="post"
        onSubmit={submit}
        onChange={() => {
          setLink("");
          setCode("");
          setCopyStatus("");
        }}
        aria-busy={pending}
      >
        <fieldset disabled={pending}>
          <label>
            {copy.action}
            <select
              value={action}
              onChange={(event) =>
                setAction(event.target.value === "revoke" ? "revoke" : "issue")
              }
            >
              <option value="issue">{copy.issue}</option>
              <option value="revoke">{copy.revoke}</option>
            </select>
          </label>
          <label>
            {copy.receipt}
            <input
              name="receipt"
              required
              maxLength={89}
              dir="ltr"
              autoComplete="off"
            />
          </label>
          {action === "issue" && (
            <>
              <label>
                {copy.email}
                <input
                  name="email"
                  required
                  type="email"
                  maxLength={254}
                  dir="ltr"
                  autoComplete="off"
                />
              </label>
              <label>
                {copy.language}
                <select name="language" defaultValue={locale}>
                  <option value="en" lang="en">
                    English
                  </option>
                  <option value="ur" lang="ur">
                    اردو
                  </option>
                </select>
              </label>
            </>
          )}
          <label className="donor-link-confirm">
            <input key={action} type="checkbox" name="confirm" required />
            {action === "issue" ? copy.confirmIssue : copy.confirmRevoke}
          </label>
        </fieldset>
        <button className="button button-primary" disabled={pending}>
          {pending
            ? copy.pending
            : action === "issue"
              ? copy.issue
              : copy.revoke}
        </button>
        {code && (
          <p
            className={
              code === "issued" || code === "revoked"
                ? undefined
                : "sign-in-error"
            }
            role="status"
          >
            {(copy.results as Record<string, string>)[code] ??
              copy.results.unavailable}
          </p>
        )}
      </form>
      {link && (
        <div className="sign-in-form">
          <label>
            {copy.link}
            <input
              type="text"
              value={link}
              readOnly
              dir="ltr"
              autoComplete="off"
            />
          </label>
          <button
            className="button button-outline"
            type="button"
            onClick={copyLink}
          >
            {copy.copy}
          </button>
          <p role="status">{copyStatus}</p>
        </div>
      )}
    </>
  );
}
