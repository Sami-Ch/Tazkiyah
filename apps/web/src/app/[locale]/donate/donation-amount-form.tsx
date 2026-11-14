"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useState } from "react";
import { givingCopy } from "@/institutes/giving-copy";
import { formatPkr } from "@/institutes/manual-donations";
import { donationPresets, parseDonationRupees } from "./donation-amount";

export function DonationAmountForm({ locale }: { locale: Locale }) {
  const copy = givingCopy[locale];
  const [preset, setPreset] = useState<
    (typeof donationPresets)[number] | "other" | null
  >(null);
  const [other, setOther] = useState("");
  const amount =
    preset === "other"
      ? parseDonationRupees(other)
      : preset
        ? BigInt(preset) * 100n
        : null;
  const invalid = preset === "other" && other.trim() !== "" && amount === null;

  return (
    <div className="donate-amount">
      <h2 id="donate-amount">{copy.amount}</h2>
      <p id="donate-amount-help">{copy.amountHelp}</p>
      <div
        className="donate-chips"
        role="group"
        aria-labelledby="donate-amount"
      >
        {donationPresets.map((rupees) => (
          <button
            key={rupees}
            type="button"
            className="button button-outline"
            aria-pressed={preset === rupees}
            onClick={() => setPreset(rupees)}
          >
            <bdi>{formatPkr(BigInt(rupees) * 100n, locale)}</bdi>
          </button>
        ))}
        <button
          type="button"
          className="button button-outline"
          aria-pressed={preset === "other"}
          onClick={() => setPreset("other")}
        >
          {copy.otherAmount}
        </button>
      </div>
      {preset === "other" && (
        <label>
          {copy.otherAmount}
          <input
            inputMode="numeric"
            autoComplete="off"
            dir="ltr"
            value={other}
            aria-invalid={invalid || undefined}
            aria-describedby="donate-amount-help"
            onChange={(event) => setOther(event.target.value)}
          />
        </label>
      )}
      {invalid && (
        <p className="donate-note" role="alert">
          {copy.amountInvalid}
        </p>
      )}
      {amount !== null && (
        <p role="status">
          {copy.amountChosen.replace("{amount}", formatPkr(amount, locale))}
        </p>
      )}

      <h2 id="donate-frequency">{copy.frequency}</h2>
      <div
        className="donate-chips"
        role="group"
        aria-labelledby="donate-frequency"
      >
        <button type="button" className="button button-outline" aria-pressed>
          {copy.oneOff}
        </button>
        <button type="button" className="button button-outline" disabled>
          {copy.monthly}
        </button>
        <button type="button" className="button button-outline" disabled>
          {copy.yearly}
        </button>
      </div>
      <p className="donate-note">{copy.recurringLater}</p>

      <h2 id="donate-methods">{copy.methods}</h2>
      <div
        className="donate-chips"
        role="group"
        aria-labelledby="donate-methods"
      >
        <button type="button" className="button button-outline" aria-pressed>
          {copy.bankTransfer}
        </button>
        {[copy.card, copy.jazzCash, copy.easyPaisa].map((method) => (
          <button
            key={method}
            type="button"
            className="button button-outline"
            disabled
          >
            {method}
          </button>
        ))}
      </div>
      <p>{copy.bankTransferHelp}</p>
      <p className="donate-note">{copy.onlineLater}</p>
    </div>
  );
}
