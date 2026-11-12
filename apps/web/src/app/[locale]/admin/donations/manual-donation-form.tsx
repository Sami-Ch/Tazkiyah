"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useRef, useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import {
  donationTypes,
  type DonationBank,
  type DonationCause,
  type DonationType,
} from "@/institutes/manual-donations";

export function ManualDonationForm({
  copy,
  locale,
  today,
  banks,
  causes,
}: {
  copy: typeof common.manualDonations;
  locale: Locale;
  today: string;
  banks: DonationBank[];
  causes: DonationCause[];
}) {
  const router = useRouter();
  const [type, setType] = useState<DonationType>("general");
  const [date, setDate] = useState(today);
  const [bank, setBank] = useState("");
  const [cause, setCause] = useState("");
  const [pending, setPending] = useState(false);
  const [code, setCode] = useState("");
  const [receipt, setReceipt] = useState("");
  const [emailQueued, setEmailQueued] = useState(false);
  const attempt = useRef<{
    id: string;
    confirmLarge: boolean;
    confirmSimilar: boolean;
  } | null>(null);
  const filteredBanks = banks.filter((item) =>
    item.for_donation_types.includes(type),
  );
  const eligibleCauses = causes.filter(
    (item) =>
      date &&
      (!item.starts_on || item.starts_on <= date) &&
      (!item.ends_on || item.ends_on >= date) &&
      (type !== "zakat" || item.accepts_zakat),
  );
  const confirmation =
    code === "large_confirmation_required" ||
    code === "similar_confirmation_required";

  function clearAttempt() {
    attempt.current = null;
    setCode("");
    setReceipt("");
    setEmailQueued(false);
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    const form = event.currentTarget;
    const values = new FormData(form);
    const request = (attempt.current ??= {
      id: crypto.randomUUID(),
      confirmLarge: false,
      confirmSimilar: false,
    });
    if (code === "large_confirmation_required") request.confirmLarge = true;
    if (code === "similar_confirmation_required") request.confirmSimilar = true;
    setPending(true);
    setCode("");
    setReceipt("");
    setEmailQueued(false);
    try {
      const response = await authRequest("manual-donation", {
        operation: request.id,
        confirmLarge: request.confirmLarge,
        confirmSimilar: request.confirmSimilar,
        type,
        date,
        bank,
        cause,
        reference: values.get("reference"),
        amount: values.get("amount"),
        email: values.get("email"),
        emailConfirmed: values.has("emailConfirmed"),
        language: values.get("language"),
      });
      const result = await response.json();
      if (!response.ok) {
        setCode(typeof result.code === "string" ? result.code : "unavailable");
        return;
      }
      setCode(result.code);
      setReceipt(result.receipt);
      setEmailQueued(result.emailQueued === true);
      form.reset();
      attempt.current = null;
      setType("general");
      setDate(today);
      setBank("");
      setCause("");
      router.refresh();
    } catch {
      setCode("unavailable");
    } finally {
      setPending(false);
    }
  }

  return (
    <form
      className="sign-in-form manual-donation-form"
      onSubmit={submit}
      method="post"
      aria-busy={pending}
    >
      <fieldset disabled={pending} onChange={clearAttempt}>
        <label>
          {copy.type}
          <select
            name="type"
            value={type}
            onChange={(event) => {
              setType(event.target.value as DonationType);
              setBank("");
              setCause("");
            }}
          >
            {donationTypes.map((item) => (
              <option key={item} value={item}>
                {copy.types[item]}
              </option>
            ))}
          </select>
        </label>
        <label>
          {copy.amount}
          <input
            name="amount"
            required
            dir="ltr"
            inputMode="numeric"
            pattern="[0-9٠-٩۰-۹]{1,12}"
            maxLength={12}
          />
        </label>
        <label>
          {copy.date}
          <input
            name="date"
            type="date"
            value={date}
            required
            max={today}
            onChange={(event) => {
              setDate(event.target.value);
              setCause("");
            }}
          />
        </label>
        <label>
          {copy.bank}
          <select
            name="bank"
            required
            value={bank}
            onChange={(event) => setBank(event.target.value)}
          >
            <option value="">{copy.selectBank}</option>
            {filteredBanks.map((item) => (
              <option key={item.id} value={item.id}>
                {[
                  item.bank_name,
                  item.label[locale] ?? item.label.en ?? item.label.ur,
                ]
                  .filter(Boolean)
                  .join(" · ")}
              </option>
            ))}
          </select>
        </label>
        <label>
          {copy.reference}
          <input
            name="reference"
            required
            maxLength={120}
            dir="auto"
            autoComplete="off"
          />
        </label>
        <label>
          {copy.cause}
          <select
            name="cause"
            value={cause}
            onChange={(event) => setCause(event.target.value)}
          >
            <option value="">{copy.allNeeds}</option>
            {eligibleCauses.map((item) => (
              <option key={item.id} value={item.id}>
                {item.title[locale] ??
                  item.title.en ??
                  item.title.ur ??
                  item.slug}
              </option>
            ))}
          </select>
        </label>
        <label>
          {copy.email}
          <input
            type="email"
            name="email"
            dir="ltr"
            autoComplete="off"
            maxLength={254}
          />
        </label>
        <label>
          {copy.language}
          <select name="language" defaultValue={locale}>
            <option value="en">English</option>
            <option value="ur" lang="ur">
              اردو
            </option>
          </select>
        </label>
        <label className="manual-donation-email-confirm">
          <input type="checkbox" name="emailConfirmed" />
          {copy.emailConfirmation}
        </label>
      </fieldset>
      {!filteredBanks.length && <p>{copy.noBankType}</p>}
      {code && (
        <p className="sign-in-error" role={receipt ? "status" : "alert"}>
          {(copy.results as Record<string, string>)[code] ??
            copy.results.unavailable}
          {receipt && (
            <>
              {" "}
              <bdi>{receipt}</bdi>
            </>
          )}
          {emailQueued && <> {copy.emailQueued}</>}
        </p>
      )}
      <button
        type="submit"
        className="button button-primary"
        disabled={pending || !filteredBanks.length}
      >
        {pending ? copy.recording : confirmation ? copy.confirm : copy.record}
      </button>
    </form>
  );
}
