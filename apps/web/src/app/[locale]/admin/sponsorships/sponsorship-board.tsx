"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
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
  const day = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "medium",
    timeZone: "UTC",
  });

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
      <section className="staff-panel" aria-labelledby="match-title">
        <h2 id="match-title">{copy.match}</h2>
        {orphans.length && sponsors.length && causes.length ? (
          <form className="staff-fields" onSubmit={onMatch}>
            <label>
              {copy.sponsor}
              <select name="donorId" required defaultValue="">
                <option value="">{copy.choose}</option>
                {sponsors.map((sponsor) => (
                  <option key={sponsor.id} value={sponsor.id}>
                    {sponsor.name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              {copy.child}
              <select name="personaId" required defaultValue="">
                <option value="">{copy.choose}</option>
                {orphans.map((child) => (
                  <option key={child.persona_id} value={child.persona_id}>
                    {child.persona} · {child.real_name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              {copy.cause}
              <select name="causeId" required defaultValue="">
                <option value="">{copy.choose}</option>
                {causes.map((cause) => (
                  <option key={cause.id} value={cause.id}>
                    {cause.title
                      ? (pageTranslation(cause.title, locale)?.text ?? "")
                      : cause.id}
                  </option>
                ))}
              </select>
            </label>
            <button
              className="button button-primary"
              type="submit"
              disabled={busy}
            >
              {busy ? copy.pending : copy.save}
            </button>
          </form>
        ) : (
          <p>{copy.noOrphans}</p>
        )}
      </section>
      <section className="staff-panel" aria-labelledby="current-matches">
        <h2 id="current-matches">{copy.current}</h2>
        {matches.length ? (
          <ul className="staff-rows">
            {matches.map((match) => (
              <li className="staff-row" key={match.id}>
                <div>
                  <strong>
                    <bdi>{match.persona}</bdi>
                  </strong>
                  <p>
                    {copy.realName}: <bdi>{match.real_name}</bdi>
                  </p>
                  <p>
                    {copy.sponsor}: <bdi>{match.sponsor ?? "—"}</bdi>
                  </p>
                </div>
                <dl>
                  <div>
                    <dt>{copy.started}</dt>
                    <dd>
                      <time dateTime={match.started_on}>
                        {day.format(new Date(match.started_on + "T00:00:00Z"))}
                      </time>
                    </dd>
                  </div>
                </dl>
                <button
                  className="button button-outline"
                  type="button"
                  disabled={busy}
                  onClick={() =>
                    void send({ action: "end", sponsorshipId: match.id })
                  }
                >
                  {copy.end}
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <p>{copy.empty}</p>
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
