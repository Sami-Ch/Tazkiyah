"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import {
  Alert,
  Badge,
  Button,
  EmptyState,
  SelectField,
  TextAreaField,
  TextField,
} from "@/design/ui";
import { formatDate } from "@/design/format";
import { pageTranslation } from "@/institutes/site-pages";
import type {
  SponsorThreadMessage,
  SponsorshipChoice,
  SponsorshipMatch,
} from "@/server/sponsorships";

type Copy = typeof common.staffSponsorships;

export function SponsorshipBoard({
  locale,
  copy,
  isPrincipal,
  unread,
  matches,
  orphans,
  sponsors,
  causes,
  teachers,
  messages,
}: {
  locale: Locale;
  copy: Copy;
  isPrincipal: boolean;
  unread: number;
  matches: SponsorshipMatch[];
  orphans: SponsorshipChoice[];
  sponsors: SponsorshipChoice[];
  causes: SponsorshipChoice[];
  teachers: SponsorshipChoice[];
  messages: SponsorThreadMessage[];
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
    const code = result?.code;
    const success =
      code === "matched"
        ? copy.matched
        : code === "ended"
          ? copy.ended
          : code === "sent"
            ? copy.sent
            : code === "recorded"
              ? copy.recorded
              : code === "assigned"
                ? copy.assigned
                : code === "principal_signed" || code === "second_signed"
                  ? copy.signed
                  : code === "withdrawn_now"
                    ? copy.withdrawnNow
                    : "";
    const problem =
      code === "already_matched"
        ? copy.already
        : code === "already"
          ? copy.consentOpen
          : code === "contact_details"
            ? copy.contactBlocked
            : code === "unavailable"
              ? copy.unavailable
              : code === "denied"
                ? copy.denied
                : code === "invalid"
                  ? copy.invalid
                  : code === "already_signed" || code === "withdrawn" || code === "not_needed"
                    ? copy.notOpen
                    : "";
    if (success) setMessage(success);
    else if (problem) setWarning(problem);
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
          <ul className="cause-grid">
            {matches.map((match) => (
              <li className="ui-card" key={match.id}>
                <h3>
                  <bdi>{match.persona}</bdi>
                </h3>
                <p>
                  {copy.realName}: <bdi>{match.real_name}</bdi>
                </p>
                <p>
                  {copy.sponsor}: <bdi>{match.sponsor ?? "—"}</bdi>
                </p>
                <p>
                  {copy.started}{" "}
                  <time dateTime={match.started_on}>
                    {formatDate(match.started_on, locale)}
                  </time>
                </p>
                <p>
                  <Badge
                    tone={
                      match.consent_status === "active" ? "verified" : "warning"
                    }
                  >
                    {copy.consentStatus}:{" "}
                    {match.consent_status
                      ? (copy.statuses[
                          match.consent_status as keyof Copy["statuses"]
                        ] ?? match.consent_status)
                      : copy.noConsent}
                  </Badge>
                </p>
                {match.second_signer && (
                  <p>
                    {copy.secondSigner}: <bdi>{match.second_signer}</bdi>
                  </p>
                )}
                {isPrincipal &&
                  match.consent_id &&
                  match.consent_status === "pending" && (
                    <form
                      className="ui-form"
                      onSubmit={(event) => {
                        event.preventDefault();
                        const data = new FormData(event.currentTarget);
                        void send({
                          action: "assign",
                          consentId: match.consent_id,
                          teacherId: String(data.get("teacherId") ?? ""),
                        });
                      }}
                    >
                      <SelectField
                        id={`signer-${match.id}`}
                        name="teacherId"
                        label={copy.assign}
                        required
                        defaultValue=""
                      >
                        <option value="">{copy.choose}</option>
                        {teachers.map((teacher) => (
                          <option key={teacher.id} value={teacher.id}>
                            {teacher.name}
                          </option>
                        ))}
                      </SelectField>
                      <div className="ui-actions">
                        <Button type="submit" disabled={busy || !teachers.length}>
                          {copy.assign}
                        </Button>
                        <Button
                          type="button"
                          variant="secondary"
                          disabled={busy}
                          onClick={() =>
                            void send({
                              action: "sign",
                              consentId: match.consent_id,
                            })
                          }
                        >
                          {copy.sign}
                        </Button>
                      </div>
                    </form>
                  )}
                {isPrincipal && !match.consent_id && (
                  <ConsentOpen
                    copy={copy}
                    busy={busy}
                    match={match}
                    onSubmit={(fields) => void send(fields)}
                  />
                )}
                {!isPrincipal && (
                  <p className="ui-hint">{copy.principalOnly}</p>
                )}
                <Button
                  variant="secondary"
                  disabled={busy}
                  onClick={() =>
                    void send({ action: "end", sponsorshipId: match.id })
                  }
                >
                  {copy.end}
                </Button>
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState title={copy.empty}>{copy.intro}</EmptyState>
        )}
      </section>
      <section className="ui-card" aria-labelledby="sponsor-inbox">
        <h2 id="sponsor-inbox">
          {copy.inbox}
          {unread > 0 ? ` (${unread})` : ""}
        </h2>
        <p>{copy.inboxIntro}</p>
        {messages.length ? (
          <ul className="cause-grid">
            {messages.map((item) => (
              <li key={item.id}>
                <p>
                  <bdi>{item.persona}</bdi>
                  {" · "}
                  {item.direction === "to_madrasa"
                    ? copy.fromSponsor
                    : copy.fromMadrasa}
                </p>
                <p lang={item.language} dir="auto">
                  {item.body}
                </p>
                <time dateTime={item.created_at}>
                  {formatDate(item.created_at.slice(0, 10), locale)}
                </time>
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState title={copy.noMessages}>{copy.inboxIntro}</EmptyState>
        )}
        {matches.length > 0 && (
          <form
            className="ui-form"
            onSubmit={(event) => {
              event.preventDefault();
              const data = new FormData(event.currentTarget);
              void send({
                action: "reply",
                sponsorshipId: String(data.get("sponsorshipId") ?? ""),
                body: String(data.get("body") ?? ""),
                language: String(data.get("language") ?? locale),
              });
              event.currentTarget.reset();
            }}
          >
            <SelectField
              id="reply-match"
              name="sponsorshipId"
              label={copy.child}
              required
              defaultValue={matches[0]?.id ?? ""}
            >
              {matches.map((match) => (
                <option key={match.id} value={match.id}>
                  {match.persona}
                </option>
              ))}
            </SelectField>
            <SelectField
              id="reply-language"
              name="language"
              label={copy.language}
              defaultValue={locale}
            >
              <option value="ur">{copy.urdu}</option>
              <option value="en">{copy.english}</option>
            </SelectField>
            <TextAreaField
              id="reply-body"
              name="body"
              label={copy.reply}
              required
              maxLength={2000}
            />
            <Button type="submit" disabled={busy}>
              {busy ? copy.pending : copy.send}
            </Button>
          </form>
        )}
      </section>
      {message && <Alert tone="success">{message}</Alert>}
      {warning && <Alert tone="danger">{warning}</Alert>}
    </>
  );
}

function ConsentOpen({
  copy,
  busy,
  match,
  onSubmit,
}: {
  copy: Copy;
  busy: boolean;
  match: SponsorshipMatch;
  onSubmit: (fields: Record<string, unknown>) => void;
}) {
  return (
    <form
      className="ui-form"
      onSubmit={(event) => {
        event.preventDefault();
        const data = new FormData(event.currentTarget);
        onSubmit({
          action: "openConsent",
          sponsorshipId: match.id,
          studentId: match.student_id,
          guardianName: String(data.get("guardianName") ?? ""),
          relation: String(data.get("relation") ?? ""),
          method: String(data.get("method") ?? ""),
          givenOn: String(data.get("givenOn") ?? ""),
          notes: String(data.get("notes") ?? ""),
        });
      }}
    >
      <h3>{copy.openConsent}</h3>
      <TextField
        id={`guardian-${match.id}`}
        name="guardianName"
        label={copy.guardian}
        required
        maxLength={120}
      />
      <SelectField id={`relation-${match.id}`} name="relation" label={copy.relation} required defaultValue="principal">
        <option value="principal">{copy.relations.principal}</option>
        <option value="guardian">{copy.relations.guardian}</option>
        <option value="father">{copy.relations.father}</option>
        <option value="mother">{copy.relations.mother}</option>
        <option value="other">{copy.relations.other}</option>
      </SelectField>
      <SelectField id={`method-${match.id}`} name="method" label={copy.method} required defaultValue="in_person">
        <option value="in_person">{copy.methods.in_person}</option>
        <option value="phone">{copy.methods.phone}</option>
        <option value="paper_form">{copy.methods.paper_form}</option>
        <option value="other">{copy.methods.other}</option>
      </SelectField>
      <TextField id={`given-${match.id}`} name="givenOn" label={copy.givenOn} type="date" required dir="ltr" />
      <TextAreaField id={`notes-${match.id}`} name="notes" label={copy.notes} maxLength={1000} />
      <p className="ui-hint">{copy.noScan}</p>
      <Button type="submit" disabled={busy}>
        {copy.openConsent}
      </Button>
    </form>
  );
}
