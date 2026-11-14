"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { authRequest } from "@/components/auth-request";
import { formatAmount } from "@/design/format";
import { pageTranslation } from "@/institutes/site-pages";
import type { AllNeedsCause, AllNeedsGift, AllNeedsPool } from "@/server/transparency";

type Copy = {
  pool: string;
  pools: { zakat: string; general: string };
  waiting: string;
  gifts: string;
  noPools: string;
  cause: string;
  amount: string;
  addRow: string;
  removeRow: string;
  preview: string;
  save: string;
  previewTitle: string;
  saved: string;
  over: string;
  causeUnavailable: string;
  invalid: string;
  denied: string;
  unavailable: string;
  pending: string;
  noReverse: string;
};

type Part = { causeId: string; amount: string };
type Draw = {
  cause_id: string;
  donation_id: string;
  receipt_number: string;
  amount_paisa: string;
};

export function AllNeedsBoard({
  locale,
  copy,
  pools,
  gifts,
  causes,
}: {
  locale: Locale;
  copy: Copy;
  pools: AllNeedsPool[];
  gifts: AllNeedsGift[];
  causes: AllNeedsCause[];
}) {
  const router = useRouter();
  const [pool, setPool] = useState<"zakat" | "general">(
    pools[0]?.pool ?? "general",
  );
  const eligible = causes.filter(
    (cause) => pool !== "zakat" || cause.accepts_zakat,
  );
  const [parts, setParts] = useState<Part[]>([
    { causeId: eligible[0]?.id ?? "", amount: "" },
  ]);
  const [draws, setDraws] = useState<Draw[] | null>(null);
  const [notice, setNotice] = useState<string>();
  const [pending, setPending] = useState(false);
  const waiting = useMemo(
    () => pools.find((item) => item.pool === pool),
    [pools, pool],
  );

  function message(code: string | undefined) {
    if (code === "over") return copy.over;
    if (code === "cause") return copy.causeUnavailable;
    if (code === "denied") return copy.denied;
    if (code === "invalid") return copy.invalid;
    return copy.unavailable;
  }

  async function send(action: "preview" | "split") {
    setPending(true);
    setNotice(undefined);
    const response = await authRequest("all-needs", { action, pool, parts });
    const body = (await response.json().catch(() => null)) as {
      code?: string;
      draws?: Draw[];
    } | null;
    setPending(false);
    if (body?.code === "preview") {
      setDraws(Array.isArray(body.draws) ? body.draws : []);
      return;
    }
    if (body?.code === "split") {
      setDraws(null);
      setNotice(copy.saved);
      router.refresh();
      return;
    }
    setDraws(null);
    setNotice(message(body?.code));
  }

  if (!pools.length) return <p role="status">{copy.noPools}</p>;

  return (
    <form
      className="ui-card"
      onSubmit={(event) => {
        event.preventDefault();
        void send(draws ? "split" : "preview");
      }}
    >
      <label className="ui-field" htmlFor="all-needs-pool">
        {copy.pool}
        <select
          id="all-needs-pool"
          value={pool}
          onChange={(event) => {
            const next = event.target.value === "zakat" ? "zakat" : "general";
            setPool(next);
            setDraws(null);
            const nextCauses = causes.filter(
              (cause) => next !== "zakat" || cause.accepts_zakat,
            );
            setParts([{ causeId: nextCauses[0]?.id ?? "", amount: "" }]);
          }}
        >
          {pools.map((item) => (
            <option key={item.pool} value={item.pool}>
              {copy.pools[item.pool]}
            </option>
          ))}
        </select>
      </label>
      {waiting && (
        <p>
          {copy.waiting}: {formatAmount(BigInt(waiting.unallocated_paisa), locale)} (
          {waiting.gifts} {copy.gifts})
        </p>
      )}
      <ul className="wall-list">
        {gifts
          .filter((gift) => gift.pool === pool)
          .map((gift) => (
            <li className="wall-row" key={gift.donation_id}>
              <bdi>{gift.receipt_number}</bdi>
              <time dateTime={gift.credited_on}>{gift.credited_on}</time>
              <span>{formatAmount(BigInt(gift.unallocated_paisa), locale)}</span>
            </li>
          ))}
      </ul>
      {parts.map((part, index) => (
        <div className="filter-row" key={index}>
          <label className="ui-field">
            {copy.cause}
            <select
              value={part.causeId}
              onChange={(event) => {
                setDraws(null);
                setParts(
                  parts.map((row, rowIndex) =>
                    rowIndex === index
                      ? { ...row, causeId: event.target.value }
                      : row,
                  ),
                );
              }}
            >
              {eligible.map((cause) => (
                <option key={cause.id} value={cause.id}>
                  {pageTranslation(cause.title, locale)?.text ?? cause.id}
                </option>
              ))}
            </select>
          </label>
          <label className="ui-field">
            {copy.amount}
            <input
              inputMode="numeric"
              value={part.amount}
              onChange={(event) => {
                setDraws(null);
                setParts(
                  parts.map((row, rowIndex) =>
                    rowIndex === index
                      ? { ...row, amount: event.target.value }
                      : row,
                  ),
                );
              }}
            />
          </label>
          {parts.length > 1 && (
            <button
              type="button"
              className="ui-button ui-button-quiet"
              onClick={() => {
                setDraws(null);
                setParts(parts.filter((_, rowIndex) => rowIndex !== index));
              }}
            >
              {copy.removeRow}
            </button>
          )}
        </div>
      ))}
      <button
        type="button"
        className="ui-button ui-button-secondary"
        onClick={() =>
          setParts([...parts, { causeId: eligible[0]?.id ?? "", amount: "" }])
        }
      >
        {copy.addRow}
      </button>
      {draws && (
        <section aria-labelledby="split-preview-title">
          <h2 id="split-preview-title">{copy.previewTitle}</h2>
          <ul>
            {draws.map((draw) => (
              <li key={`${draw.donation_id}-${draw.cause_id}-${draw.amount_paisa}`}>
                <bdi>{draw.receipt_number}</bdi>{" "}
                {formatAmount(BigInt(draw.amount_paisa), locale)}
              </li>
            ))}
          </ul>
        </section>
      )}
      <p>{copy.noReverse}</p>
      {notice && <p role="status">{notice}</p>}
      <button className="ui-button ui-button-primary" type="submit" disabled={pending}>
        {pending ? copy.pending : draws ? copy.save : copy.preview}
      </button>
    </form>
  );
}
