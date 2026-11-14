"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { reversalCategories } from "@/institutes/manual-donations";
import { pageTranslation } from "@/institutes/site-pages";
import type {
  SpendingCause,
  SpendingEntryRow,
  SpendingPool,
} from "@/server/spending";

type Copy = typeof common.staffSpending;

function rupees(locale: Locale, paisa: string) {
  return new Intl.NumberFormat(`${locale}-PK`, {
    style: "currency",
    currency: "PKR",
    maximumFractionDigits: 0,
  }).format(Number(BigInt(paisa) / 100n));
}

function unspentOf(cause: SpendingCause | undefined) {
  return (cause?.balances ?? []).reduce(
    (sum, balance) => sum + BigInt(balance.unspent_paisa),
    0n,
  );
}

export function SpendingBoard({
  locale,
  copy,
  today,
  causes,
  pools,
  entries,
}: {
  locale: Locale;
  copy: Copy;
  today: string;
  causes: SpendingCause[];
  pools: SpendingPool[];
  entries: SpendingEntryRow[];
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [warning, setWarning] = useState("");
  const [causeId, setCauseId] = useState(causes[0]?.id ?? "");
  const [amount, setAmount] = useState("");
  const drafts = entries.filter((entry) => entry.status === "draft");
  const recent = entries.filter((entry) => entry.status !== "draft");
  const day = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "medium",
    timeZone: "UTC",
  });

  function label(
    title: SpendingCause["title"] | SpendingEntryRow["description"] | undefined,
  ) {
    return title ? (pageTranslation(title, locale)?.text ?? "") : "";
  }

  function causeName(id: string) {
    return label(causes.find((cause) => cause.id === id)?.title) || id;
  }

  async function submit(
    body: Record<string, unknown>,
    event?: FormEvent<HTMLFormElement>,
  ) {
    event?.preventDefault();
    setBusy(true);
    setMessage("");
    setWarning("");
    const response = await authRequest("spending", body);
    const result = (await response.json().catch(() => null)) as {
      code?: string;
    } | null;
    setBusy(false);
    const code = result?.code;
    if (code === "saved" || code === "saved_over_balance") {
      setMessage(copy.saveAnother);
      if (code === "saved_over_balance") setWarning(copy.overBalance);
      setAmount("");
      router.refresh();
      return;
    }
    if (code === "recorded") {
      setMessage(copy.recorded);
      router.refresh();
      return;
    }
    if (code === "over_balance") {
      setWarning(copy.overBalance);
      router.refresh();
      return;
    }
    if (code === "reversed") {
      setMessage(copy.reversed);
      router.refresh();
      return;
    }
    const known: Record<string, string> = {
      nothing_open: copy.nothingOpen,
      not_draft: copy.notDraft,
      not_recorded: copy.notRecorded,
      invalid: copy.invalid,
      denied: copy.denied,
      cause_unavailable: copy.noCauses,
    };
    setWarning(code && known[code] ? known[code] : copy.unavailable);
  }

  const typed = /^\d+$/.test(amount) ? BigInt(amount) * 100n : null;
  const selected = causes.find((cause) => cause.id === causeId);
  const liveOver = typed !== null && typed > unspentOf(selected);

  return (
    <>
      <section className="staff-panel" aria-labelledby="spending-balances">
        <h2 id="spending-balances">{copy.balances}</h2>
        {causes.length ? (
          <ul className="staff-rows">
            {causes.map((cause) => (
              <li className="staff-row" key={cause.id}>
                <strong>{label(cause.title)}</strong>
                <dl>
                  {cause.balances.map((balance) => (
                    <div key={balance.donation_type}>
                      <dt>{copy.types[balance.donation_type]}</dt>
                      <dd>
                        <bdi>{rupees(locale, balance.unspent_paisa)}</bdi>
                      </dd>
                    </div>
                  ))}
                </dl>
              </li>
            ))}
          </ul>
        ) : (
          <p>{copy.noCauses}</p>
        )}
        <h3>{copy.pools}</h3>
        {pools.length ? (
          <ul className="staff-rows">
            {pools.map((pool) => (
              <li className="staff-row" key={pool.pool}>
                <strong>{copy.poolsNames[pool.pool]}</strong>
                <p>
                  <bdi>{rupees(locale, pool.unallocated_paisa)}</bdi>
                  {" · "}
                  {pool.gifts} {copy.gifts}
                </p>
              </li>
            ))}
          </ul>
        ) : (
          <p>{copy.noPools}</p>
        )}
      </section>

      <section className="staff-panel" aria-labelledby="spending-form-title">
        <h2 id="spending-form-title">{copy.batch}</h2>
        <p className="staff-lead">{copy.receiptLater}</p>
        <form
          className="staff-fields"
          onSubmit={(event) => {
            const data = new FormData(event.currentTarget);
            void submit(
              {
                action: "save",
                causeId,
                amount: String(data.get("amount") ?? ""),
                date: String(data.get("date") ?? ""),
                descriptionUr: String(data.get("descriptionUr") ?? ""),
                descriptionEn: String(data.get("descriptionEn") ?? ""),
                receiptPublic: data.get("receiptPublic") === "on",
              },
              event,
            );
          }}
        >
          <label>
            {copy.cause}
            <select
              name="cause"
              value={causeId}
              required
              onChange={(event) => setCauseId(event.target.value)}
            >
              <option value="">{copy.chooseCause}</option>
              {causes.map((cause) => (
                <option key={cause.id} value={cause.id}>
                  {label(cause.title)}
                </option>
              ))}
            </select>
          </label>
          <label>
            {copy.amount}
            <input
              name="amount"
              inputMode="numeric"
              autoComplete="off"
              required
              value={amount}
              onChange={(event) => setAmount(event.target.value)}
            />
          </label>
          <label>
            {copy.date}
            <input
              name="date"
              type="date"
              required
              defaultValue={today}
              max={today}
            />
          </label>
          <label>
            {copy.descriptionUr}
            <textarea name="descriptionUr" maxLength={500} />
          </label>
          <label>
            {copy.descriptionEn}
            <textarea name="descriptionEn" maxLength={500} />
          </label>
          <p className="staff-span staff-lead">{copy.descriptionHint}</p>
          <label className="staff-span">
            <input name="receiptPublic" type="checkbox" defaultChecked />{" "}
            {copy.receiptPublic}
          </label>
          {liveOver && (
            <p className="staff-warning staff-span" role="status">
              {copy.overBalance}
            </p>
          )}
          <button
            className="button button-primary"
            type="submit"
            disabled={busy || !causes.length}
          >
            {busy ? copy.pending : copy.save}
          </button>
        </form>
      </section>

      <section className="staff-panel" aria-labelledby="spending-drafts">
        <h2 id="spending-drafts">{copy.drafts}</h2>
        {drafts.length ? (
          <>
            <ul className="staff-rows">
              {drafts.map((entry) => (
                <li className="staff-row" key={entry.id}>
                  <div>
                    <strong>{causeName(entry.cause_id)}</strong>
                    <p>{label(entry.description)}</p>
                  </div>
                  <dl>
                    <div>
                      <dt>{copy.amount}</dt>
                      <dd>
                        <bdi>{rupees(locale, entry.amount_paisa)}</bdi>
                      </dd>
                    </div>
                    <div>
                      <dt>{copy.date}</dt>
                      <dd>
                        <time dateTime={entry.spent_on}>
                          {day.format(new Date(entry.spent_on + "T00:00:00Z"))}
                        </time>
                      </dd>
                    </div>
                  </dl>
                  <button
                    className="button button-outline"
                    type="button"
                    disabled={busy}
                    onClick={() =>
                      void submit({ action: "record-one", entryId: entry.id })
                    }
                  >
                    {copy.recordOne}
                  </button>
                </li>
              ))}
            </ul>
            <button
              className="button button-primary"
              type="button"
              disabled={busy}
              onClick={() => void submit({ action: "record" })}
            >
              {copy.recordAll}
            </button>
          </>
        ) : (
          <p>{copy.noDrafts}</p>
        )}
      </section>

      <section className="staff-panel" aria-labelledby="spending-recent">
        <h2 id="spending-recent">{copy.recent}</h2>
        {recent.length ? (
          <ul className="staff-rows">
            {recent.map((entry) => (
              <li className="staff-row" key={entry.id}>
                <div>
                  <strong>{causeName(entry.cause_id)}</strong>
                  <p>{label(entry.description)}</p>
                  <p className="staff-meta">
                    <span>{copy.statuses[entry.status]}</span>
                  </p>
                </div>
                <dl>
                  <div>
                    <dt>{copy.amount}</dt>
                    <dd>
                      <bdi>{rupees(locale, entry.amount_paisa)}</bdi>
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.matched}</dt>
                    <dd>
                      <bdi>{rupees(locale, entry.matched_paisa)}</bdi>
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.date}</dt>
                    <dd>
                      <time dateTime={entry.spent_on}>
                        {day.format(new Date(entry.spent_on + "T00:00:00Z"))}
                      </time>
                    </dd>
                  </div>
                </dl>
                {entry.status === "recorded" && (
                  <form
                    className="staff-row-actions"
                    onSubmit={(event) => {
                      const data = new FormData(event.currentTarget);
                      void submit(
                        {
                          action: "reverse",
                          entryId: entry.id,
                          category: String(data.get("category") ?? ""),
                          note: String(data.get("note") ?? ""),
                        },
                        event,
                      );
                    }}
                  >
                    <label>
                      {copy.reason}
                      <select name="category" required defaultValue="">
                        <option value="">{copy.chooseReason}</option>
                        {reversalCategories.map((reason) => (
                          <option key={reason} value={reason}>
                            {copy.reasons[reason]}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label>
                      {copy.note}
                      <input name="note" maxLength={500} />
                    </label>
                    <button
                      className="button button-outline"
                      type="submit"
                      disabled={busy}
                    >
                      {copy.reverse}
                    </button>
                  </form>
                )}
              </li>
            ))}
          </ul>
        ) : (
          <p>{copy.noEntries}</p>
        )}
      </section>
      {message && (
        <p className="staff-success" role="status">
          {message}
        </p>
      )}
      {warning && (
        <p className="staff-warning" role="alert">
          {warning}
        </p>
      )}
    </>
  );
}
