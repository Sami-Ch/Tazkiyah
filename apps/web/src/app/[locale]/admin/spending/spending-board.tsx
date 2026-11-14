"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import {
  Alert,
  Amount,
  Badge,
  Button,
  CheckboxField,
  DataTable,
  EmptyState,
  SelectField,
  TextAreaField,
  TextField,
} from "@/design/ui";
import { formatDate } from "@/design/format";
import { reversalCategories } from "@/institutes/manual-donations";
import { pageTranslation } from "@/institutes/site-pages";
import type {
  SpendingCause,
  SpendingEntryRow,
  SpendingPool,
} from "@/server/spending";

type Copy = typeof common.staffSpending;

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
      <section className="ui-card" aria-labelledby="spending-balances">
        <h2 id="spending-balances">{copy.balances}</h2>
        {causes.length ? (
          <ul className="cause-grid">
            {causes.map((cause) => (
              <li className="ui-card" key={cause.id}>
                <strong>{label(cause.title)}</strong>
                <dl className="money-pair">
                  {cause.balances.map((balance) => (
                    <div key={balance.donation_type}>
                      <dt>{copy.types[balance.donation_type]}</dt>
                      <dd>
                        <Amount paisa={balance.unspent_paisa} locale={locale} />
                      </dd>
                    </div>
                  ))}
                </dl>
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState title={copy.noCauses}>{copy.noCauses}</EmptyState>
        )}
        <h3>{copy.pools}</h3>
        {pools.length ? (
          <ul className="cause-grid">
            {pools.map((pool) => (
              <li className="ui-card" key={pool.pool}>
                <strong>{copy.poolsNames[pool.pool]}</strong>
                <p>
                  <Amount paisa={pool.unallocated_paisa} locale={locale} />
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

      <section className="ui-card" aria-labelledby="spending-form-title">
        <h2 id="spending-form-title">{copy.batch}</h2>
        <p>{copy.receiptLater}</p>
        <form
          className="ui-form"
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
          <SelectField
            id="spend-cause"
            name="cause"
            label={copy.cause}
            required
            value={causeId}
            onChange={(event) => setCauseId(event.target.value)}
          >
            <option value="">{copy.chooseCause}</option>
            {causes.map((cause) => (
              <option key={cause.id} value={cause.id}>
                {label(cause.title)}
              </option>
            ))}
          </SelectField>
          <TextField
            id="spend-amount"
            name="amount"
            label={copy.amount}
            inputMode="numeric"
            autoComplete="off"
            required
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
          />
          <TextField
            id="spend-date"
            name="date"
            label={copy.date}
            type="date"
            required
            defaultValue={today}
            max={today}
          />
          <TextAreaField
            id="spend-ur"
            name="descriptionUr"
            label={copy.descriptionUr}
            maxLength={500}
          />
          <TextAreaField
            id="spend-en"
            name="descriptionEn"
            label={copy.descriptionEn}
            hint={copy.descriptionHint}
            maxLength={500}
          />
          <CheckboxField
            id="spend-public"
            name="receiptPublic"
            label={copy.receiptPublic}
            defaultChecked
          />
          {liveOver && <Alert tone="warning">{copy.overBalance}</Alert>}
          <Button type="submit" disabled={busy || !causes.length}>
            {busy ? copy.pending : copy.save}
          </Button>
        </form>
      </section>

      <section className="ui-card" aria-labelledby="spending-drafts">
        <h2 id="spending-drafts">{copy.drafts}</h2>
        {drafts.length ? (
          <>
            <DataTable
              columns={[
                { key: "cause", label: copy.cause },
                { key: "amount", label: copy.amount },
                { key: "date", label: copy.date },
                { key: "action", label: copy.recordOne },
              ]}
              rows={drafts.map((entry) => ({
                cause: (
                  <>
                    <strong>{causeName(entry.cause_id)}</strong>
                    <p>{label(entry.description)}</p>
                  </>
                ),
                amount: <Amount paisa={entry.amount_paisa} locale={locale} />,
                date: (
                  <time dateTime={entry.spent_on}>
                    {formatDate(entry.spent_on, locale)}
                  </time>
                ),
                action: (
                  <Button
                    variant="secondary"
                    disabled={busy}
                    onClick={() =>
                      void submit({ action: "record-one", entryId: entry.id })
                    }
                  >
                    {copy.recordOne}
                  </Button>
                ),
              }))}
            />
            <Button
              disabled={busy}
              onClick={() => void submit({ action: "record" })}
            >
              {copy.recordAll}
            </Button>
          </>
        ) : (
          <EmptyState title={copy.noDrafts}>{copy.noDrafts}</EmptyState>
        )}
      </section>

      <section className="ui-card" aria-labelledby="spending-recent">
        <h2 id="spending-recent">{copy.recent}</h2>
        {recent.length ? (
          <ul className="cause-grid">
            {recent.map((entry) => (
              <li className="ui-card" key={entry.id}>
                <strong>{causeName(entry.cause_id)}</strong>
                <p>{label(entry.description)}</p>
                <Badge
                  tone={entry.status === "recorded" ? "verified" : "warning"}
                >
                  {copy.statuses[entry.status]}
                </Badge>
                <dl className="money-pair">
                  <div>
                    <dt>{copy.amount}</dt>
                    <dd>
                      <Amount paisa={entry.amount_paisa} locale={locale} />
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.matched}</dt>
                    <dd>
                      <Amount paisa={entry.matched_paisa} locale={locale} />
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.date}</dt>
                    <dd>
                      <time dateTime={entry.spent_on}>
                        {formatDate(entry.spent_on, locale)}
                      </time>
                    </dd>
                  </div>
                </dl>
                {entry.status === "recorded" && (
                  <form
                    className="ui-form"
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
                    <SelectField
                      id={`reverse-reason-${entry.id}`}
                      name="category"
                      label={copy.reason}
                      required
                      defaultValue=""
                    >
                      <option value="">{copy.chooseReason}</option>
                      {reversalCategories.map((reason) => (
                        <option key={reason} value={reason}>
                          {copy.reasons[reason]}
                        </option>
                      ))}
                    </SelectField>
                    <TextField
                      id={`reverse-note-${entry.id}`}
                      name="note"
                      label={copy.note}
                      maxLength={500}
                    />
                    <Button type="submit" variant="secondary" disabled={busy}>
                      {copy.reverse}
                    </Button>
                  </form>
                )}
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState title={copy.noEntries}>{copy.noEntries}</EmptyState>
        )}
      </section>
      {message && <Alert tone="success">{message}</Alert>}
      {warning && <Alert tone="danger">{warning}</Alert>}
    </>
  );
}
