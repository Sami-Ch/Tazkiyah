"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";

type Enrollment = { key: string; backupCodes: string[] };

export function TwoFactorSetup({
  copy,
  workspaceHref,
}: {
  copy: typeof common.admin;
  workspaceHref: string;
}) {
  const [enrollment, setEnrollment] = useState<Enrollment>();
  const [verified, setVerified] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    const fields = new FormData(event.currentTarget);
    setBusy(true);
    setError("");
    try {
      if (!enrollment) {
        const response = await authRequest("two-factor/enable", {
          password: String(fields.get("password")),
        });
        if (!response.ok) throw new Error();
        const { totpURI, backupCodes } = await response.json();
        const key = new URL(totpURI).searchParams.get("secret");
        if (!key || !Array.isArray(backupCodes)) throw new Error();
        setEnrollment({ key, backupCodes });
      } else {
        const response = await authRequest("two-factor/verify-totp", {
          code: String(fields.get("code")).trim(),
        });
        if (!response.ok) throw new Error();
        setVerified(true);
      }
    } catch {
      setError(enrollment ? copy.codeError : copy.setupError);
    } finally {
      setBusy(false);
    }
  }

  if (verified && enrollment) {
    return (
      <div className="sign-in-form">
        <h2>{copy.recoveryHeading}</h2>
        <p>{copy.recoveryInstructions}</p>
        <ul className="auth-recovery-codes" dir="ltr">
          {enrollment.backupCodes.map((code) => (
            <li key={code}>
              <code>{code}</code>
            </li>
          ))}
        </ul>
        <a className="button button-primary" href={workspaceHref}>
          {copy.openWorkspace}
        </a>
      </div>
    );
  }

  return (
    <form
      className="sign-in-form"
      key={String(Boolean(enrollment))}
      method="post"
      onSubmit={submit}
      aria-busy={busy}
    >
      {enrollment ? (
        <>
          <p>{copy.setupInstructions}</p>
          <code className="auth-setup-key" dir="ltr">
            {enrollment.key}
          </code>
          <label>
            {copy.code}
            <input
              name="code"
              dir="ltr"
              autoComplete="one-time-code"
              inputMode="numeric"
              pattern="[0-9]{6}"
              maxLength={6}
              required
            />
          </label>
        </>
      ) : (
        <>
          <p>{copy.setupIntro}</p>
          <label>
            {copy.password}
            <input
              name="password"
              type="password"
              autoComplete="current-password"
              dir="auto"
              maxLength={128}
              required
            />
          </label>
        </>
      )}
      {error && (
        <p className="sign-in-error" role="alert">
          {error}
        </p>
      )}
      <button className="button button-primary" disabled={busy}>
        {enrollment ? copy.verify : copy.startSetup}
      </button>
    </form>
  );
}
