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
import type {
  ConsentPerson,
  ConsentRecord,
  ConsentSponsorship,
  ConsentStudent,
} from "@/server/consent";

type Copy = typeof common.staffConsent;

export function ConsentBoard({
  locale,
  copy,
  isPrincipal,
  students,
  teachers,
  sponsorships,
  records,
}: {
  locale: Locale;
  copy: Copy;
  isPrincipal: boolean;
  students: ConsentStudent[];
  teachers: ConsentPerson[];
  sponsorships: ConsentSponsorship[];
  records: ConsentRecord[];
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [warning, setWarning] = useState("");

  async function send(body: Record<string, unknown>) {
    setBusy(true);
    setMessage("");
    setWarning("");
    const response = await authRequest("consent", body);
    const result = (await response.json().catch(() => null)) as {
      code?: string;
    } | null;
    setBusy(false);
    const code = result?.code;
    if (code === "recorded") setMessage(copy.recorded);
    else if (code === "assigned") setMessage(copy.assigned);
    else if (code === "principal_signed" || code === "second_signed")
      setMessage(copy.signed);
    else if (code === "withdrawn_now") setMessage(copy.withdrawnNow);
    else if (code === "already") setWarning(copy.already);
    else if (code === "denied") setWarning(copy.denied);
    else if (code === "invalid") setWarning(copy.invalid);
    else if (code === "withdrawn" || code === "already_signed" || code === "not_needed")
      setWarning(copy.notOpen);
    else setWarning(copy.unavailable);
    if (code === "recorded" || code === "assigned" || code?.endsWith("signed") || code === "withdrawn_now")
      router.refresh();
    else if (code) router.refresh();
  }

  function onRecord(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const kind = String(data.get("kind") ?? "");
    void send({
      action: "record",
      studentId: String(data.get("studentId") ?? ""),
      kind,
      guardianName: String(data.get("guardianName") ?? ""),
      relation: String(data.get("relation") ?? ""),
      method: String(data.get("method") ?? ""),
      givenOn: String(data.get("givenOn") ?? ""),
      notes: String(data.get("notes") ?? ""),
      sponsorshipId:
        kind === "orphan_full_profile"
          ? String(data.get("sponsorshipId") ?? "")
          : null,
    });
  }

  return (
    <>
      <section className="ui-card" aria-labelledby="consent-form-title">
        <h2 id="consent-form-title">{copy.form}</h2>
        <p>{copy.formIntro}</p>
        {students.length ? (
          <form className="ui-form" onSubmit={onRecord}>
            <SelectField id="consent-student" name="studentId" label={copy.student} required defaultValue="">
              <option value="">{copy.choose}</option>
              {students.map((student) => (
                <option key={student.id} value={student.id}>
                  {student.persona ? `${student.persona} · ` : ""}
                  {student.real_name}
                </option>
              ))}
            </SelectField>
            <SelectField id="consent-kind" name="kind" label={copy.kind} required defaultValue="public_work">
              <option value="public_work">{copy.kinds.public_work}</option>
              <option value="real_name">{copy.kinds.real_name}</option>
              <option value="face">{copy.kinds.face}</option>
              {isPrincipal && (
                <option value="orphan_full_profile">{copy.kinds.orphan_full_profile}</option>
              )}
            </SelectField>
            {isPrincipal && sponsorships.length > 0 && (
              <SelectField id="consent-sponsorship" name="sponsorshipId" label={copy.sponsorship} defaultValue="">
                <option value="">{copy.notSponsorship}</option>
                {sponsorships.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.persona} · {item.real_name}
                  </option>
                ))}
              </SelectField>
            )}
            <TextField id="consent-guardian" name="guardianName" label={copy.guardian} required maxLength={120} />
            <SelectField id="consent-relation" name="relation" label={copy.relation} required defaultValue="father">
              {(
                ["father", "mother", "guardian", "other", "principal"] as const
              ).map((relation) => (
                <option key={relation} value={relation}>
                  {copy.relations[relation]}
                </option>
              ))}
            </SelectField>
            <SelectField id="consent-method" name="method" label={copy.method} required defaultValue="in_person">
              {(
                ["in_person", "phone", "paper_form", "other"] as const
              ).map((method) => (
                <option key={method} value={method}>
                  {copy.methods[method]}
                </option>
              ))}
            </SelectField>
            <TextField id="consent-date" name="givenOn" label={copy.givenOn} type="date" required dir="ltr" />
            <TextAreaField id="consent-notes" name="notes" label={copy.notes} maxLength={1000} />
            <p className="ui-hint">{copy.noScan}</p>
            <Button type="submit" disabled={busy}>
              {busy ? copy.pending : copy.save}
            </Button>
          </form>
        ) : (
          <EmptyState title={copy.noStudents}>{copy.formIntro}</EmptyState>
        )}
      </section>
      <section className="ui-card" aria-labelledby="consent-records">
        <h2 id="consent-records">{copy.records}</h2>
        {records.length ? (
          <ul className="cause-grid">
            {records.map((record) => (
              <li className="ui-card" key={record.id}>
                <h3>
                  <bdi>{record.persona ?? record.real_name}</bdi>
                </h3>
                <p>
                  {copy.realName}: <bdi>{record.real_name}</bdi>
                </p>
                <p>
                  {copy.kinds[record.kind as keyof Copy["kinds"]] ?? record.kind}
                  {" · "}
                  <Badge tone={record.status === "active" ? "verified" : "warning"}>
                    {copy.statuses[record.status as keyof Copy["statuses"]] ?? record.status}
                  </Badge>
                </p>
                <p>
                  <bdi>{record.guardian_name}</bdi>
                  {" · "}
                  {copy.relations[record.relation as keyof Copy["relations"]] ?? record.relation}
                  {" · "}
                  {copy.methods[record.method as keyof Copy["methods"]] ?? record.method}
                </p>
                <p>
                  <time dateTime={record.given_on}>{formatDate(record.given_on, locale)}</time>
                </p>
                {record.notes && <p>{record.notes}</p>}
                {record.second_signer && (
                  <p>
                    {copy.secondSigner}: <bdi>{record.second_signer}</bdi>
                  </p>
                )}
                <div className="ui-actions">
                  {record.can_sign_principal && (
                    <Button disabled={busy} onClick={() => void send({ action: "sign", consentId: record.id })}>
                      {copy.signPrincipal}
                    </Button>
                  )}
                  {record.can_sign_second && (
                    <Button disabled={busy} onClick={() => void send({ action: "sign", consentId: record.id })}>
                      {copy.signSecond}
                    </Button>
                  )}
                </div>
                {record.can_assign && (
                  <form
                    className="ui-form"
                    onSubmit={(event) => {
                      event.preventDefault();
                      const data = new FormData(event.currentTarget);
                      void send({
                        action: "assign",
                        consentId: record.id,
                        teacherId: String(data.get("teacherId") ?? ""),
                      });
                    }}
                  >
                    <SelectField id={`assign-${record.id}`} name="teacherId" label={copy.assign} required defaultValue="">
                      <option value="">{copy.choose}</option>
                      {teachers.map((teacher) => (
                        <option key={teacher.id} value={teacher.id}>
                          {teacher.name}
                        </option>
                      ))}
                    </SelectField>
                    <Button type="submit" disabled={busy || !teachers.length}>
                      {copy.assign}
                    </Button>
                  </form>
                )}
                {record.can_withdraw && (
                  <form
                    className="ui-form"
                    onSubmit={(event) => {
                      event.preventDefault();
                      const data = new FormData(event.currentTarget);
                      void send({
                        action: "withdraw",
                        consentId: record.id,
                        reason: String(data.get("reason") ?? ""),
                      });
                    }}
                  >
                    <TextField id={`withdraw-${record.id}`} name="reason" label={copy.withdrawReason} required maxLength={500} />
                    <Button type="submit" variant="danger" disabled={busy}>
                      {copy.withdraw}
                    </Button>
                  </form>
                )}
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState title={copy.noRecords}>{copy.recordsIntro}</EmptyState>
        )}
      </section>
      {message && <Alert tone="success">{message}</Alert>}
      {warning && <Alert tone="danger">{warning}</Alert>}
    </>
  );
}
