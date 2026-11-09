"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import { useState, useSyncExternalStore, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";

function subscribe(onChange: () => void) {
  window.addEventListener("hashchange", onChange);
  return () => window.removeEventListener("hashchange", onChange);
}

function getToken() {
  return window.location.hash.slice(1);
}

export function AcceptStaffInvitation({
  copy,
  signInHref,
}: {
  copy: typeof common.staffInvite;
  signInHref: string;
}) {
  const token = useSyncExternalStore(subscribe, getToken, () => null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!token || busy) return;
    const fields = new FormData(event.currentTarget);
    const password = String(fields.get("password"));
    if (password !== fields.get("confirmation")) {
      setError(copy.mismatch);
      return;
    }

    setBusy(true);
    setError("");
    try {
      const response = await authRequest("staff-invite/accept", {
        token,
        password,
      });
      if (!response.ok) {
        setError(response.status === 410 ? copy.expired : copy.acceptError);
        return;
      }
      setDone(true);
      window.history.replaceState(
        window.history.state,
        "",
        window.location.pathname,
      );
    } catch {
      setError(copy.acceptError);
    } finally {
      setBusy(false);
    }
  }

  if (done) {
    return (
      <>
        <p role="status">{copy.done}</p>
        <a className="button button-primary" href={signInHref}>
          {copy.signIn}
        </a>
      </>
    );
  }
  if (token === null) return <p role="status">{copy.loading}</p>;
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) return <p>{copy.expired}</p>;

  return (
    <form
      className="sign-in-form"
      method="post"
      onSubmit={submit}
      aria-busy={busy}
    >
      <p>{copy.passwordInstructions}</p>
      <label>
        {copy.password}
        <input
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={16}
          maxLength={128}
          required
        />
      </label>
      <label>
        {copy.confirmation}
        <input
          name="confirmation"
          type="password"
          autoComplete="new-password"
          minLength={16}
          maxLength={128}
          required
        />
      </label>
      {error && (
        <p className="sign-in-error" role="alert">
          {error}
        </p>
      )}
      <button className="button button-primary" disabled={busy}>
        {copy.accept}
      </button>
    </form>
  );
}
