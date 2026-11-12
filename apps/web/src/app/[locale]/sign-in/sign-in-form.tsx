"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useEffect, useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";

type Copy = typeof common.signIn;
type Mode = "loading" | "credentials" | "totp" | "backup" | "signed-in";
type AuthResult = { twoFactorRedirect?: boolean; user?: { name: string } };

export function SignInForm({ copy, locale }: { copy: Copy; locale: Locale }) {
  const [mode, setMode] = useState<Mode>("loading");
  const [name, setName] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const continueHref = `/${locale}/account?continue=1`;

  useEffect(() => {
    let mounted = true;
    async function restoreSession() {
      try {
        const response = await authRequest("get-session");
        if (!response.ok) throw new Error();
        const session: AuthResult | null = await response.json();
        if (!mounted) return;
        if (session?.user) {
          setName(session.user.name);
          setMode("signed-in");
        } else {
          setMode("credentials");
        }
      } catch {
        if (!mounted) return;
        setMode("credentials");
        setError(copy.unavailable);
      }
    }
    void restoreSession();
    return () => {
      mounted = false;
    };
  }, [copy.unavailable]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    const fields = new FormData(event.currentTarget);
    setBusy(true);
    setError("");

    try {
      let response: Response;
      if (mode === "credentials") {
        const identifier = String(fields.get("identifier")).trim();
        const method = identifier.includes("@") ? "email" : "username";
        response = await authRequest(`sign-in/${method}`, {
          [method]: identifier,
          password: String(fields.get("password")),
        });
      } else if (mode === "signed-in") {
        response = await authRequest("sign-out", {});
      } else {
        const endpoint =
          mode === "backup" ? "verify-backup-code" : "verify-totp";
        response = await authRequest(`two-factor/${endpoint}`, {
          code: String(fields.get("code")).trim(),
        });
      }

      if (!response.ok) {
        const failure = await response.json().catch(() => null);
        const message =
          response.status === 429
            ? copy.rateLimited
            : response.status === 404 ||
                response.status >= 500 ||
                mode === "signed-in"
              ? copy.unavailable
              : failure?.code === "EMAIL_NOT_VERIFIED"
                ? copy.emailNotVerified
                : mode === "credentials"
                  ? copy.invalidCredentials
                  : copy.invalidCode;
        setError(message);
        return;
      }

      if (mode === "signed-in") {
        setName("");
        setMode("credentials");
        return;
      }

      const result: AuthResult = await response.json();
      if (result.twoFactorRedirect) {
        setMode("totp");
      } else if (result.user) {
        window.location.replace(continueHref);
      } else {
        setError(copy.unavailable);
      }
    } catch {
      setError(copy.unavailable);
    } finally {
      setBusy(false);
    }
  }

  if (mode === "loading") return <p role="status">{copy.loading}</p>;

  return (
    <form
      className="sign-in-form"
      key={mode}
      method="post"
      onSubmit={submit}
      aria-busy={busy}
    >
      {mode === "credentials" ? (
        <>
          <p>{copy.intro}</p>
          <label>
            {copy.identifier}
            <input
              name="identifier"
              dir="auto"
              autoComplete="username"
              autoCapitalize="none"
              spellCheck={false}
              maxLength={254}
              required
            />
          </label>
          <label>
            {copy.password}
            <input
              name="password"
              type="password"
              dir="auto"
              autoComplete="current-password"
              maxLength={128}
              required
            />
          </label>
        </>
      ) : mode === "signed-in" ? (
        <>
          <p role="status">
            {copy.signedIn} <bdi>{name}</bdi>
          </p>
          <a className="button button-outline" href={continueHref}>
            {copy.continue}
          </a>
        </>
      ) : (
        <label>
          {mode === "totp" ? copy.totp : copy.backup}
          <input
            name="code"
            dir="ltr"
            autoComplete="one-time-code"
            autoCapitalize="none"
            inputMode={mode === "totp" ? "numeric" : "text"}
            maxLength={mode === "totp" ? 6 : 64}
            pattern={mode === "totp" ? "[0-9]{6}" : undefined}
            required
          />
        </label>
      )}
      {error && (
        <p className="sign-in-error" role="alert">
          {error}
        </p>
      )}
      <button className="button button-primary" disabled={busy}>
        {busy
          ? copy.loading
          : mode === "signed-in"
            ? copy.signOut
            : mode === "credentials"
              ? copy.heading
              : copy.verify}
      </button>
      {mode === "credentials" && (
        <div className="sign-in-alternatives">
          <a href={`/${locale}/forgot-password`}>{copy.forgotPassword}</a>
          <a href={`/${locale}/signup`}>{copy.createDonorAccount}</a>
        </div>
      )}
      {(mode === "totp" || mode === "backup") && (
        <div className="sign-in-alternatives">
          <button
            className="button button-outline"
            type="button"
            disabled={busy}
            onClick={() => {
              setMode(mode === "totp" ? "backup" : "totp");
              setError("");
            }}
          >
            {mode === "totp" ? copy.useBackup : copy.useTotp}
          </button>
          <button
            className="button button-outline"
            type="button"
            disabled={busy}
            onClick={() => {
              setMode("credentials");
              setError("");
            }}
          >
            {copy.backToSignIn}
          </button>
        </div>
      )}
    </form>
  );
}
