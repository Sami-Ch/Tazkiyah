import type { Locale } from "@tazkiyah/i18n/routing";
import { Amount, ProgressBar } from "@/design/ui";
import { percentOf } from "@/design/format";
import { causeCopy } from "@/institutes/cause-copy";
import type { PublishedCause } from "@/institutes/causes";

export function CauseProgress({
  cause,
  locale,
  showLifetime = false,
  spent,
  spentLabel,
}: {
  cause: PublishedCause;
  locale: Locale;
  showLifetime?: boolean;
  spent?: string;
  spentLabel?: string;
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
  const target = cause.target_paisa ? BigInt(cause.target_paisa) : 0n;
  const lifetime = BigInt(cause.lifetime_raised_paisa);
  const percent = target > 0n ? Math.min(100, percentOf(raised, target)) : 0;

  return (
    <div className="giving-progress">
      <dl className="money-pair">
        <div>
          <dt>{raisedLabel}</dt>
          <dd>
            <Amount paisa={raised} locale={locale} />
          </dd>
        </div>
        {target > 0n && (
          <div>
            <dt>{targetLabel}</dt>
            <dd>
              <Amount paisa={target} locale={locale} />
            </dd>
          </div>
        )}
        {spent !== undefined && (
          <div>
            <dt>{spentLabel}</dt>
            <dd>
              <Amount paisa={spent} locale={locale} />
            </dd>
          </div>
        )}
        {showLifetime &&
          cause.cause_type !== "campaign" &&
          lifetime !== raised && (
            <div>
              <dt>{copy.lifetimeRaised}</dt>
              <dd>
                <Amount paisa={lifetime} locale={locale} />
              </dd>
            </div>
          )}
      </dl>
      {target > 0n && (
        <ProgressBar
          value={percent}
          max={100}
          label={`${percent}% · ${raisedLabel}`}
        />
      )}
      {target > 0n && raised >= target && (
        <p className="giving-kicker">{copy.targetReached}</p>
      )}
    </div>
  );
}
