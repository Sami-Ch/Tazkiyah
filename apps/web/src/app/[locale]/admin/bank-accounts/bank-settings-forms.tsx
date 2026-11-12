"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, useTransition, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { donationPurposes } from "@/institutes/giving";
import type { AdminBankAccount } from "@/server/bank-accounts";

export function BankSettingsForms({
  accounts,
  copy,
  locale,
}: {
  accounts: AdminBankAccount[];
  copy: typeof common.bankSettings;
  locale: Locale;
}) {
  const router = useRouter();
  const [sending, setSending] = useState(false);
  const [refreshing, startTransition] = useTransition();
  const [result, setResult] = useState<{ form: string; code: string } | null>(
    null,
  );
  const busy = sending || refreshing;

  async function submit(
    event: FormEvent<HTMLFormElement>,
    account?: AdminBankAccount,
  ) {
    event.preventDefault();
    if (busy) return;
    const form = event.currentTarget;
    const values = new FormData(form);
    const formId = account?.id ?? "create";
    const data = account
      ? {
          action: account.show_on_donate ? "hide" : "publish",
          id: account.id,
          confirm: values.has("confirm"),
        }
      : {
          ...Object.fromEntries(values),
          action: "create",
          purposes: values.getAll("purposes"),
        };
    setSending(true);
    setResult(null);
    try {
      const response = await authRequest("bank-account", data);
      const payload = await response.json();
      setResult({ form: formId, code: payload.code ?? "unavailable" });
      if (response.ok) {
        form.reset();
        startTransition(() => router.refresh());
      }
    } catch {
      setResult({ form: formId, code: "unavailable" });
    } finally {
      setSending(false);
    }
  }

  function status(formId: string) {
    if (result?.form !== formId) return null;
    const success = result.code === "created" || result.code === "updated";
    return (
      <p
        className={success ? undefined : "sign-in-error"}
        role={success ? "status" : "alert"}
      >
        {(copy.results as Record<string, string>)[result.code] ??
          copy.results.unavailable}
      </p>
    );
  }

  return (
    <>
      <section aria-labelledby="current-bank-accounts">
        <h2 id="current-bank-accounts">{copy.current}</h2>
        {accounts.length ? (
          <ul className="bank-settings-list">
            {accounts.map((account) => (
              <li key={account.id}>
                <h3>
                  {account.label[locale] ??
                    account.label.en ??
                    account.label.ur}
                </h3>
                <p>
                  {!account.is_active
                    ? copy.inactive
                    : account.show_on_donate
                      ? copy.published
                      : copy.hidden}
                </p>
                <dl className="bank-settings-details">
                  <dt>{copy.bank}</dt>
                  <dd>
                    <bdi>{account.bank_name}</bdi>
                  </dd>
                  <dt>{copy.title}</dt>
                  <dd>
                    <bdi>{account.account_title}</bdi>
                  </dd>
                  {account.account_number && (
                    <>
                      <dt>{copy.number}</dt>
                      <dd>
                        <bdi>{account.account_number}</bdi>
                      </dd>
                    </>
                  )}
                  {account.iban && (
                    <>
                      <dt>{copy.iban}</dt>
                      <dd>
                        <bdi>{account.iban}</bdi>
                      </dd>
                    </>
                  )}
                  {account.branch && (
                    <>
                      <dt>{copy.branch}</dt>
                      <dd>
                        <bdi>{account.branch}</bdi>
                      </dd>
                    </>
                  )}
                  <dt>{copy.purposes}</dt>
                  <dd>
                    {account.for_donation_types
                      .map((purpose) => copy.types[purpose])
                      .join(", ")}
                  </dd>
                </dl>
                {(account.is_active || account.show_on_donate) && (
                  <form
                    method="post"
                    className="bank-settings-publication"
                    onSubmit={(event) => void submit(event, account)}
                  >
                    {!account.show_on_donate && (
                      <label className="bank-settings-check">
                        <input
                          type="checkbox"
                          name="confirm"
                          required
                          disabled={busy}
                        />
                        {copy.confirm}
                      </label>
                    )}
                    <button className="button button-outline" disabled={busy}>
                      {account.show_on_donate ? copy.hide : copy.publish}
                    </button>
                  </form>
                )}
                {status(account.id)}
              </li>
            ))}
          </ul>
        ) : (
          <p>{copy.empty}</p>
        )}
      </section>
      <section aria-labelledby="add-bank-account">
        <h2 id="add-bank-account">{copy.add}</h2>
        <form
          method="post"
          className="sign-in-form bank-settings-add"
          onSubmit={(event) => void submit(event)}
        >
          <fieldset className="bank-settings-fields" disabled={busy}>
            <label>
              {copy.labelEn}
              <input
                name="labelEn"
                required
                maxLength={90}
                lang="en"
                dir="ltr"
              />
            </label>
            <label>
              {copy.labelUr}
              <input
                name="labelUr"
                required
                maxLength={90}
                lang="ur"
                dir="rtl"
              />
            </label>
            <label>
              {copy.bank}
              <input name="bank" required maxLength={120} dir="auto" />
            </label>
            <label>
              {copy.title}
              <input name="title" required maxLength={120} dir="auto" />
            </label>
            <label>
              {copy.number}
              <input
                name="number"
                maxLength={40}
                dir="ltr"
                autoComplete="off"
              />
            </label>
            <label>
              {copy.iban}
              <input name="iban" maxLength={42} dir="ltr" autoComplete="off" />
            </label>
            <label>
              {copy.branch}
              <input name="branch" maxLength={120} dir="auto" />
            </label>
          </fieldset>
          <p>{copy.numberHelp}</p>
          <fieldset className="bank-settings-purposes" disabled={busy}>
            <legend>{copy.purposes}</legend>
            {donationPurposes.map((purpose) => (
              <label key={purpose} className="bank-settings-check">
                <input type="checkbox" name="purposes" value={purpose} />
                {copy.types[purpose]}
              </label>
            ))}
          </fieldset>
          {status("create")}
          <button className="button button-primary" disabled={busy}>
            {copy.save}
          </button>
        </form>
      </section>
    </>
  );
}
