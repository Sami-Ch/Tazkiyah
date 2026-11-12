"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRef, useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { formatPkr } from "@/institutes/manual-donations";
import { pageTranslation } from "@/institutes/site-pages";
import type {
  BankStatement,
  StatementBank,
  StatementTransfer,
} from "@/server/bank-reconciliation";

type Period = { bank: string; from: string; to: string };
type View = Period & BankStatement;
type Action = "load" | "close" | "note";
type PendingOperation = { payload: string; id: string };

export function BankReconciliation({
  banks,
  copy,
  locale,
  today,
}: {
  banks: StatementBank[];
  copy: typeof common.bankReconciliation;
  locale: Locale;
  today: string;
}) {
  const [statement, setStatement] = useState<View>();
  const [matched, setMatched] = useState<string[]>([]);
  const [busy, setBusy] = useState<Action>();
  const [error, setError] = useState("");
  const [status, setStatus] = useState("");
  const [stale, setStale] = useState(false);
  const operations = useRef<
    Partial<Record<"close" | "note", PendingOperation>>
  >({});
  const day = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "medium",
    timeZone: "UTC",
  });
  const number = new Intl.NumberFormat(`${locale}-PK`);
  const dateLabel = (date: string) => day.format(new Date(`${date}T00:00:00Z`));
  const selected = new Set(matched);
  const transfers = statement?.transfers ?? [];
  const byDay = new Map<string, StatementTransfer[]>();
  for (const transfer of transfers) {
    const dayTransfers = byDay.get(transfer.credited_on);
    if (dayTransfers) dayTransfers.push(transfer);
    else byDay.set(transfer.credited_on, [transfer]);
  }
  const total = transfers.reduce(
    (sum, transfer) =>
      selected.has(transfer.id) ? sum + BigInt(transfer.amount_paisa) : sum,
    0n,
  );

  function show(period: Period, data: BankStatement) {
    setStatement({ ...period, ...data });
    setMatched(
      data.transfers.filter(({ matched }) => matched).map(({ id }) => id),
    );
    setStale(false);
  }

  async function send(
    action: Action,
    period: Period,
    detail?: Record<string, unknown>,
  ) {
    if (busy) return false;
    const body: Record<string, unknown> = { action, ...period, ...detail };
    if (action !== "load") {
      const payload = JSON.stringify(body);
      const previous = operations.current[action];
      const id =
        previous?.payload === payload ? previous.id : crypto.randomUUID();
      operations.current[action] = { id, payload };
      body.operation = id;
    }
    setError("");
    setStatus("");
    setBusy(action);
    try {
      const response = await authRequest("bank-reconciliation", body);
      const result: { code?: string; statement?: BankStatement } =
        await response.json();
      if (!response.ok || !result.statement) {
        if (result.code === "stale") setStale(true);
        setError(
          result.code === "stale" ||
            result.code === "denied" ||
            result.code === "invalid"
            ? copy[result.code]
            : copy.unavailable,
        );
        return false;
      }
      if (action === "note") {
        const otherCredits = result.statement.otherCredits;
        setStatement((current) => current && { ...current, otherCredits });
        setStatus(copy.noted);
      } else {
        show(period, result.statement);
        if (action === "close") setStatus(copy.closed);
      }
      if (action !== "load") delete operations.current[action];
      return true;
    } catch {
      setError(copy.unavailable);
      return false;
    } finally {
      setBusy(undefined);
    }
  }

  function load(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fields = new FormData(event.currentTarget);
    void send("load", {
      bank: String(fields.get("bank")),
      from: String(fields.get("from")),
      to: String(fields.get("to")),
    });
  }

  function close(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!statement || stale) return;
    const { bank, from, to, review } = statement;
    void send(
      "close",
      { bank, from, to },
      { review, matched: [...matched].sort() },
    );
  }

  async function note(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!statement) return;
    const { bank, from, to } = statement;
    const form = event.currentTarget;
    const fields = new FormData(form);
    if (
      await send(
        "note",
        { bank, from, to },
        {
          credited: fields.get("credited"),
          amount: fields.get("amount"),
          note: fields.get("note"),
        },
      )
    )
      form.reset();
  }

  return (
    <>
      <p>{copy.intro}</p>
      <form
        className="manual-donation-form sign-in-form"
        method="post"
        onSubmit={load}
        aria-busy={busy === "load"}
      >
        <fieldset
          disabled={Boolean(busy)}
          onChange={() => {
            setStatement(undefined);
            setStatus("");
            setError("");
          }}
        >
          <label>
            {copy.bank}
            <select name="bank" required>
              {banks.map((bank) => (
                <option key={bank.id} value={bank.id}>
                  {pageTranslation(bank.label, locale)?.text ?? bank.bank_name}
                  {bank.is_active ? "" : ` · ${copy.inactive}`}
                </option>
              ))}
            </select>
          </label>
          <label>
            {copy.from}
            <input
              type="date"
              name="from"
              defaultValue={`${today.slice(0, 7)}-01`}
              max={today}
              required
            />
          </label>
          <label>
            {copy.to}
            <input
              type="date"
              name="to"
              defaultValue={today}
              max={today}
              required
            />
          </label>
        </fieldset>
        <button className="button button-primary" disabled={Boolean(busy)}>
          {busy === "load" ? copy.pending : copy.load}
        </button>
      </form>
      {error && (
        <p className="sign-in-error" role="alert">
          {error}
        </p>
      )}
      {status && <p role="status">{status}</p>}
      {statement && (
        <>
          <form
            className="manual-donation-form sign-in-form"
            method="post"
            onSubmit={close}
            aria-busy={busy === "close"}
          >
            {transfers.length ? (
              [...byDay].map(([date, gifts]) => {
                const dailyTotal = gifts.reduce(
                  (sum, gift) => sum + BigInt(gift.amount_paisa),
                  0n,
                );
                return (
                  <div key={date} className="statement-day">
                    <h2>
                      <time dateTime={date}>{dateLabel(date)}</time>
                    </h2>
                    <p>
                      {copy.recordedTotal}{" "}
                      <bdi>{formatPkr(dailyTotal, locale)}</bdi>
                    </p>
                    {gifts.map((gift) => (
                      <label
                        className="manual-donation-email-confirm statement-transfer"
                        key={gift.id}
                      >
                        <input
                          type="checkbox"
                          checked={selected.has(gift.id)}
                          disabled={Boolean(busy) || stale}
                          onChange={(event) => {
                            const checked = event.target.checked;
                            setMatched((current) =>
                              checked
                                ? [...current, gift.id]
                                : current.filter((id) => id !== gift.id),
                            );
                            setStatus("");
                          }}
                        />
                        <span>
                          <bdi>{gift.receipt_number}</bdi>
                          {" · "}
                          <bdi>{formatPkr(gift.amount_paisa, locale)}</bdi>
                          <small>
                            {copy.reference} <bdi>{gift.reference_tail}</bdi>
                          </small>
                          {gift.matched === false && (
                            <small>{copy.missing}</small>
                          )}
                          {gift.statement_from && gift.statement_to && (
                            <small>
                              {copy.lastReview} {dateLabel(gift.statement_from)}
                              {" – "}
                              {dateLabel(gift.statement_to)}
                            </small>
                          )}
                        </span>
                      </label>
                    ))}
                  </div>
                );
              })
            ) : (
              <p>{copy.noTransfers}</p>
            )}
            <dl className="statement-summary" aria-live="polite">
              <div>
                <dt>{copy.matched}</dt>
                <dd>{number.format(matched.length)}</dd>
              </div>
              <div>
                <dt>{copy.total}</dt>
                <dd>
                  <bdi>{formatPkr(total, locale)}</bdi>
                </dd>
              </div>
              <div>
                <dt>{copy.missing}</dt>
                <dd>{number.format(transfers.length - matched.length)}</dd>
              </div>
            </dl>
            <button
              className="button button-primary"
              disabled={Boolean(busy) || stale}
            >
              {busy === "close" ? copy.pending : copy.close}
            </button>
          </form>
          <form
            className="manual-donation-form sign-in-form"
            method="post"
            onSubmit={(event) => void note(event)}
            aria-busy={busy === "note"}
          >
            <h2>{copy.otherCredits}</h2>
            {statement.otherCredits.length > 0 && (
              <ul>
                {statement.otherCredits.map((credit) => (
                  <li key={credit.id}>
                    <time dateTime={credit.credited_on}>
                      {dateLabel(credit.credited_on)}
                    </time>
                    {" · "}
                    <bdi>{formatPkr(credit.amount_paisa, locale)}</bdi>
                  </li>
                ))}
              </ul>
            )}
            <fieldset disabled={Boolean(busy)}>
              <label>
                {copy.credited}
                <input
                  type="date"
                  name="credited"
                  min={statement.from}
                  max={statement.to}
                  required
                />
              </label>
              <label>
                {copy.amount}
                <input
                  name="amount"
                  inputMode="decimal"
                  maxLength={15}
                  required
                />
              </label>
              <label>
                {copy.note}
                <input
                  name="note"
                  dir="auto"
                  maxLength={500}
                  required
                  aria-describedby="credit-note-help"
                />
              </label>
            </fieldset>
            <p id="credit-note-help">{copy.noteHelp}</p>
            <button className="button button-outline" disabled={Boolean(busy)}>
              {busy === "note" ? copy.pending : copy.saveNote}
            </button>
          </form>
          <a href={`/${locale}/admin/donations`}>{copy.recordMissing}</a>
        </>
      )}
    </>
  );
}
