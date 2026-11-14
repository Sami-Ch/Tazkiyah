"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useState } from "react";
import { formatAmount } from "@/design/format";
import { Amount, ChoiceChips, ErrorSummary, TextField } from "@/design/ui";
import { givingCopy } from "@/institutes/giving-copy";
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
      {invalid && (
        <ErrorSummary title={copy.checkDetails} errors={[copy.amountInvalid]} />
      )}
      <ChoiceChips
        labelId="donate-amount"
        options={[
          ...donationPresets.map((rupees) => ({
            id: String(rupees),
            label: <Amount paisa={BigInt(rupees) * 100n} locale={locale} />,
            pressed: preset === rupees,
            onSelect: () => setPreset(rupees),
          })),
          {
            id: "other",
            label: copy.otherAmount,
            pressed: preset === "other",
            onSelect: () => setPreset("other"),
          },
        ]}
      />
      {preset === "other" && (
        <TextField
          id="donate-other-amount"
          label={copy.otherAmount}
          hint={copy.amountHelp}
          error={invalid ? copy.amountInvalid : undefined}
          inputMode="numeric"
          autoComplete="off"
          dir="ltr"
          value={other}
          onChange={(event) => setOther(event.target.value)}
        />
      )}
      {amount !== null && (
        <p role="status">
          {copy.amountChosen.replace("{amount}", formatAmount(amount, locale))}
        </p>
      )}

      <h2 id="donate-frequency">{copy.frequency}</h2>
      <ChoiceChips
        labelId="donate-frequency"
        options={[
          { id: "once", label: copy.oneOff, pressed: true },
          { id: "month", label: copy.monthly, disabled: true },
          { id: "year", label: copy.yearly, disabled: true },
        ]}
      />
      <p className="ui-hint">{copy.recurringLater}</p>

      <h2 id="donate-methods">{copy.methods}</h2>
      <ChoiceChips
        labelId="donate-methods"
        options={[
          { id: "bank", label: copy.bankTransfer, pressed: true },
          { id: "card", label: copy.card, disabled: true },
          { id: "jazz", label: copy.jazzCash, disabled: true },
          { id: "easy", label: copy.easyPaisa, disabled: true },
        ]}
      />
      <p>{copy.bankTransferHelp}</p>
      <p className="ui-hint">{copy.onlineLater}</p>
    </div>
  );
}
