import type { Locale } from "@tazkiyah/i18n/routing";
import { causeCopy } from "@/institutes/cause-copy";
import type { PublishedCause } from "@/institutes/causes";

function formatPkr(paisa: bigint, locale: Locale) {
  const remainder = paisa % 100n;
  const formatter = new Intl.NumberFormat(`${locale}-PK`, {
    style: "currency",
    currency: "PKR",
    minimumFractionDigits: remainder ? 2 : 0,
  });
  if (!remainder) return formatter.format(paisa / 100n);
  const fraction = new Intl.NumberFormat(`${locale}-PK`, {
    minimumIntegerDigits: 2,
  }).format(remainder);
  return formatter
    .formatToParts(paisa / 100n)
    .map((part) => (part.type === "fraction" ? fraction : part.value))
    .join("");
}

export function CauseProgress({
  cause,
  locale,
  showLifetime = false,
}: {
  cause: PublishedCause;
  locale: Locale;
  showLifetime?: boolean;
}) {
  const copy = causeCopy[locale];
  const [raisedLabel, targetLabel] =
    cause.cause_type === "yearly_stock"
      ? [copy.stockRaised, copy.stockTarget]
      : cause.target_period === "monthly"
        ? [copy.monthRaised, copy.monthTarget]
        : cause.target_period === "yearly"
          ? [copy.yearRaised, copy.yearTarget]
          : [copy.raised, copy.target];
  const raised = BigInt(cause.raised_paisa);
  const target = BigInt(cause.target_paisa ?? "0");
  const reached = target > 0n && raised >= target;
  const progress = reached
    ? 1000
    : target > 0n
      ? Number((raised * 1000n) / target)
      : 0;
  const lifetime = BigInt(cause.lifetime_raised_paisa);

  return (
    <div className="giving-progress">
      <dl>
        <div>
          <dt>{raisedLabel}</dt>
          <dd>{formatPkr(raised, locale)}</dd>
        </div>
        {target > 0n && (
          <div>
            <dt>{targetLabel}</dt>
            <dd>{formatPkr(target, locale)}</dd>
          </div>
        )}
        {showLifetime &&
          cause.cause_type !== "campaign" &&
          lifetime !== raised && (
            <div>
              <dt>{copy.lifetimeRaised}</dt>
              <dd>{formatPkr(lifetime, locale)}</dd>
            </div>
          )}
      </dl>
      {target > 0n && (
        <progress max={1000} value={progress} aria-label={copy.progress} />
      )}
      {reached && <p className="giving-kicker">{copy.targetReached}</p>}
    </div>
  );
}
