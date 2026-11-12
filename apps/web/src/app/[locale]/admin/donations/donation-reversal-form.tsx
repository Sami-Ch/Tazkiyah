"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import {
  reversalCategories,
  type TransferForReversal,
} from "@/institutes/manual-donations";
import { pageTranslation } from "@/institutes/site-pages";
import { trailCopy } from "../../trail/trail-copy";

type Copy = typeof common.donationReversal;

export function DonationReversalForm({
  locale,
  copy,
  donationCopy,
}: {
  locale: Locale;
  copy: Copy;
  donationCopy: typeof common.manualDonations;
}) {
  const router = useRouter();
  const [transfer, setTransfer] = useState<TransferForReversal>();
  const [busy, setBusy] = useState(false);
  const [otherReason, setOtherReason] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const reasonCopy = trailCopy[locale];
  const money = new Intl.NumberFormat(`${locale}-PK`, {
    style: "currency",
    currency: "PKR",
    maximumFractionDigits: 0,
  });
  const day = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "medium",
    timeZone: "UTC",
  });
  const cause = pageTranslation(transfer?.cause_title ?? undefined, locale);

  async function submit(
    event: FormEvent<HTMLFormElement>,
    action: "lookup" | "reverse",
  ) {
    event.preventDefault();
    if (busy) return;
    const fields = new FormData(event.currentTarget);
    const receipt =
      action === "lookup"
        ? String(fields.get("receipt") ?? "")
            .trim()
            .toUpperCase()
        : transfer?.receipt_number;
    setBusy(true);
    setError("");
    setSuccess("");
    if (action === "lookup") {
      setTransfer(undefined);
      setOtherReason(false);
    }

    try {
      const response = await authRequest("donation-reversal", {
        action,
        receipt,
        ...(action === "reverse" && {
          category: fields.get("category"),
          note: fields.get("note"),
          confirm: fields.has("confirm"),
        }),
      });
      const result: { code?: string; transfer?: TransferForReversal } =
        await response.json();
      if (response.ok && result.transfer) {
        setTransfer(result.transfer);
        if (action === "reverse") {
          if (result.code === "reversed") setSuccess(copy.reversed);
          router.refresh();
        }
      } else if (result.code === "has_spending" && transfer) {
        setTransfer({ ...transfer, has_spending: true });
      } else {
        setError(
          result.code === "invalid" ||
            result.code === "no_match" ||
            result.code === "denied"
            ? copy[result.code]
            : copy.unavailable,
        );
      }
    } catch {
      setError(copy.unavailable);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section
      className="manual-donation-form donation-reversal"
      aria-labelledby="donation-reversal-title"
    >
      <h2 id="donation-reversal-title">{copy.heading}</h2>
      <form
        className="sign-in-form"
        method="post"
        onSubmit={(event) => void submit(event, "lookup")}
        aria-busy={busy}
      >
        <label>
          {copy.receipt}
          <input
            name="receipt"
            dir="ltr"
            maxLength={89}
            autoComplete="off"
            spellCheck={false}
            required
            disabled={busy}
          />
        </label>
        <button className="button button-outline" disabled={busy}>
          {busy && !transfer ? copy.pending : copy.find}
        </button>
      </form>
      {transfer && (
        <div className="donation-reversal-details">
          <div aria-live="polite">
            <h3>{copy.original}</h3>
            <p>
              <bdi>{transfer.receipt_number}</bdi>
            </p>
            <p>
              <bdi>{money.format(BigInt(transfer.amount_paisa) / 100n)}</bdi>
              {" · "}
              <time dateTime={transfer.credited_on}>
                {day.format(new Date(`${transfer.credited_on}T00:00:00Z`))}
              </time>
            </p>
            <p>
              {donationCopy.types[transfer.donation_type]}
              {" · "}
              {cause ? (
                <bdi lang={cause.language}>{cause.text}</bdi>
              ) : (
                donationCopy.allNeeds
              )}
            </p>
          </div>
          {transfer.status === "reversed" ? (
            <div>
              <h3>{copy.reversal}</h3>
              <p>{copy.cancelled}</p>
              {transfer.reversal_reason && (
                <p>{reasonCopy[`reason_${transfer.reversal_reason}`]}</p>
              )}
              {transfer.reversed_on && (
                <time dateTime={transfer.reversed_on}>
                  {day.format(new Date(`${transfer.reversed_on}T00:00:00Z`))}
                </time>
              )}
            </div>
          ) : transfer.has_spending ? (
            <p role="status">{copy.has_spending}</p>
          ) : (
            <form
              className="sign-in-form"
              method="post"
              onSubmit={(event) => void submit(event, "reverse")}
              aria-busy={busy}
            >
              <label>
                {copy.reason}
                <select
                  name="category"
                  defaultValue=""
                  required
                  disabled={busy}
                  onChange={(event) =>
                    setOtherReason(event.target.value === "other")
                  }
                >
                  <option value="">{copy.chooseReason}</option>
                  {reversalCategories.map((reason) => (
                    <option key={reason} value={reason}>
                      {reasonCopy[`reason_${reason}`]}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                {copy.note}
                <input
                  name="note"
                  maxLength={500}
                  required={otherReason}
                  disabled={busy}
                  dir="auto"
                />
              </label>
              <label className="manual-donation-email-confirm">
                <input
                  name="confirm"
                  type="checkbox"
                  required
                  disabled={busy}
                />
                {copy.confirm}
              </label>
              <button className="button button-outline" disabled={busy}>
                {busy ? copy.pending : copy.submit}
              </button>
            </form>
          )}
        </div>
      )}
      {error && (
        <p className="sign-in-error" role="alert">
          {error}
        </p>
      )}
      {success && <p role="status">{success}</p>}
    </section>
  );
}
