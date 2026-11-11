"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";

export type AccountFormMode = "signup" | "forgot" | "reset" | "first";

export function AccountForm({
  mode,
  locale,
  token,
  copy,
  signIn,
}: {
  mode: AccountFormMode;
  locale: Locale;
  token?: string;
  copy: typeof common.account;
  signIn: typeof common.signIn;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [status, setStatus] = useState("");
  const needsEmail = mode === "signup" || mode === "forgot";
  const signInHref = `/${locale}/sign-in`;
  const needsNewLink =
    mode === "reset" && (!token || error === copy.resetInvalid);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || status || needsNewLink) return;
    const fields = new FormData(event.currentTarget);
    const email = String(fields.get("email") ?? "").trim();
    const newPassword = String(fields.get("newPassword") ?? "");
    const name = String(fields.get("name") ?? "").trim();
    if (mode === "signup" && !name) {
      setError(copy.invalid);
      return;
    }
    setError("");
    setBusy(true);

    try {
      let response: Response;
      switch (mode) {
        case "signup":
          response = await authRequest("sign-up/email", {
            name,
            email,
            password: newPassword,
            preferredLanguage: locale,
            callbackURL: signInHref,
          });
          break;
        case "forgot":
          response = await authRequest("request-password-reset", {
            email,
            redirectTo: `/${locale}/reset-password`,
          });
          break;
        case "reset":
          response = await authRequest("reset-password", {
            token,
            newPassword,
          });
          break;
        case "first":
          response = await authRequest("first-password", {
            currentPassword: String(fields.get("currentPassword")),
            newPassword,
          });
          break;
      }

      if (!response.ok) {
        const result = await response.json().catch(() => null);
        if (mode === "first" && response.status === 403) {
          window.location.replace(`/${locale}/account`);
        } else if (response.status === 429) {
          setError(signIn.rateLimited);
        } else if (response.status === 404 || response.status >= 500) {
          setError(copy.unavailable);
        } else if (mode === "reset" && result?.code === "INVALID_TOKEN") {
          setError(copy.resetInvalid);
        } else {
          setError(copy.invalid);
        }
        return;
      }

      if (mode === "first") {
        window.location.replace(`/${locale}/account?continue=1`);
        return;
      }
      if (mode === "reset")
        window.history.replaceState(null, "", `/${locale}/reset-password`);
      setStatus(
        mode === "signup"
          ? copy.signupSent
          : mode === "forgot"
            ? copy.resetSent
            : copy.resetDone,
      );
    } catch {
      setError(copy.unavailable);
    } finally {
      setBusy(false);
    }
  }

  if (needsNewLink) {
    return (
      <>
        <p role="alert">{copy.resetInvalid}</p>
        <a href={`/${locale}/forgot-password`}>{copy.sendReset}</a>
      </>
    );
  }

  return (
    <>
      {status ? (
        <p role="status">{status}</p>
      ) : (
        <form
          className="sign-in-form"
          method="post"
          onSubmit={submit}
          aria-busy={busy}
        >
          {mode === "signup" && (
            <label>
              {copy.name}
              <input
                name="name"
                autoComplete="name"
                maxLength={120}
                dir="auto"
                required
              />
            </label>
          )}
          {needsEmail && (
            <label>
              {copy.email}
              <input
                name="email"
                type="email"
                autoComplete="email"
                maxLength={254}
                dir="ltr"
                required
              />
            </label>
          )}
          {mode === "first" && (
            <label>
              {copy.startingPassword}
              <input
                name="currentPassword"
                type="password"
                autoComplete="current-password"
                maxLength={128}
                required
              />
            </label>
          )}
          {mode !== "forgot" && (
            <label>
              {mode === "signup" ? signIn.password : copy.newPassword}
              <input
                name="newPassword"
                type="password"
                autoComplete="new-password"
                minLength={8}
                maxLength={128}
                aria-describedby="account-password-hint"
                required
              />
              <small id="account-password-hint">{copy.passwordHint}</small>
            </label>
          )}
          {error && (
            <p role="alert" className="sign-in-error">
              {error}
            </p>
          )}
          <button className="button button-primary" disabled={busy}>
            {busy
              ? signIn.loading
              : mode === "signup"
                ? signIn.createDonorAccount
                : mode === "forgot"
                  ? copy.sendReset
                  : copy.savePassword}
          </button>
        </form>
      )}
      {mode !== "first" && <a href={signInHref}>{signIn.backToSignIn}</a>}
    </>
  );
}
