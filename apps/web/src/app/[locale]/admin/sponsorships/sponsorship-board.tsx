"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { Alert, Button, DataTable, EmptyState, SelectField } from "@/design/ui";
import { formatDate } from "@/design/format";
import { pageTranslation } from "@/institutes/site-pages";
import type {
  SponsorshipChoice,
  SponsorshipMatch,
} from "@/server/sponsorships";

type Copy = typeof common.staffSponsorships;

export function SponsorshipBoard({
  locale,
  copy,
  matches,
  orphans,
  sponsors,
  causes,
}: {
  locale: Locale;
  copy: Copy;
  matches: SponsorshipMatch[];
  orphans: SponsorshipChoice[];
  sponsors: SponsorshipChoice[];
  causes: SponsorshipChoice[];
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [warning, setWarning] = useState("");

  async function send(body: Record<string, unknown>) {
    setBusy(true);
    setMessage("");
    setWarning("");
    const response = await authRequest("sponsorship", body);
    const result = (await response.json().catch(() => null)) as {
      code?: string;
    } | null;
    setBusy(false);
    if (result?.code === "matched") setMessage(copy.matched);
    else if (result?.code === "ended") setMessage(copy.ended);
    else if (result?.code === "already_matched") setWarning(copy.already);
    else if (result?.code === "unavailable") setWarning(copy.unavailable);
    else if (result?.code === "denied") setWarning(copy.denied);
    else if (result?.code === "invalid") setWarning(copy.invalid);
    else {
      setWarning(copy.unavailable);
      return;
    }
    router.refresh();
  }

  function onMatch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    void send({
      action: "match",
      donorId: String(data.get("donorId") ?? ""),
      personaId: String(data.get("personaId") ?? ""),
      causeId: String(data.get("causeId") ?? ""),
    });
  }

  return (
    <>
      <section className="ui-card" aria-labelledby="match-title">
        <h2 id="match-title">{copy.match}</h2>
        {orphans.length && sponsors.length && causes.length ? (
          <form className="ui-form" onSubmit={onMatch}>
            <SelectField
              id="sponsor-donor"
              name="donorId"
              label={copy.sponsor}
              required
              defaultValue=""
            >
              <option value="">{copy.choose}</option>
              {sponsors.map((sponsor) => (
                <option key={sponsor.id} value={sponsor.id}>
                  {sponsor.name}
                </option>
              ))}
            </SelectField>
            <SelectField
              id="sponsor-child"
              name="personaId"
              label={copy.child}
              required
              defaultValue=""
            >
              <option value="">{copy.choose}</option>
              {orphans.map((child) => (
                <option key={child.persona_id} value={child.persona_id}>
                  {child.persona} · {child.real_name}
                </option>
              ))}
            </SelectField>
            <SelectField
              id="sponsor-cause"
              name="causeId"
              label={copy.cause}
              required
              defaultValue=""
            >
              <option value="">{copy.choose}</option>
              {causes.map((cause) => (
                <option key={cause.id} value={cause.id}>
                  {cause.title
                    ? (pageTranslation(cause.title, locale)?.text ?? "")
                    : cause.id}
                </option>
              ))}
            </SelectField>
            <Button type="submit" disabled={busy}>
              {busy ? copy.pending : copy.save}
            </Button>
          </form>
        ) : (
          <EmptyState title={copy.noOrphans}>{copy.intro}</EmptyState>
        )}
      </section>
      <section className="ui-card" aria-labelledby="current-matches">
        <h2 id="current-matches">{copy.current}</h2>
        {matches.length ? (
          <DataTable
            columns={[
              { key: "child", label: copy.child },
              { key: "sponsor", label: copy.sponsor },
              { key: "started", label: copy.started },
              { key: "action", label: copy.end },
            ]}
            rows={matches.map((match) => ({
              child: (
                <>
                  <bdi>{match.persona}</bdi>
                  <p>
                    {copy.realName}: <bdi>{match.real_name}</bdi>
                  </p>
                </>
              ),
              sponsor: <bdi>{match.sponsor ?? "—"}</bdi>,
              started: (
                <time dateTime={match.started_on}>
                  {formatDate(match.started_on, locale)}
                </time>
              ),
              action: (
                <Button
                  variant="secondary"
                  disabled={busy}
                  onClick={() =>
                    void send({ action: "end", sponsorshipId: match.id })
                  }
                >
                  {copy.end}
                </Button>
              ),
            }))}
          />
        ) : (
          <EmptyState title={copy.empty}>{copy.intro}</EmptyState>
        )}
      </section>
      {message && <Alert tone="success">{message}</Alert>}
      {warning && <Alert tone="danger">{warning}</Alert>}
    </>
  );
}
