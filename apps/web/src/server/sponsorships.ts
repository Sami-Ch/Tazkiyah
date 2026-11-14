import { sql } from "drizzle-orm";
import type { Locale } from "@tazkiyah/i18n/routing";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

export type SponsorshipMatch = {
  id: string;
  persona: string;
  real_name: string;
  student_id: string;
  status: string;
  started_on: string;
  sponsor: string | null;
  consent_id: string | null;
  consent_status: string | null;
  second_signer: string | null;
};

export type SponsorThreadMessage = {
  id: string;
  sponsorship_id: string;
  persona: string;
  direction: "to_madrasa" | "to_sponsor";
  body: string;
  language: string;
  created_at: string;
};

export type SponsorshipChoice = {
  id?: string;
  persona_id?: string;
  persona?: string;
  real_name?: string;
  name?: string;
  title?: Partial<Record<Locale, string>>;
};

export type SponsorshipWorkspace =
  | {
      state: "allowed";
      is_principal: boolean;
      unread: number;
      matches: SponsorshipMatch[];
      orphans: SponsorshipChoice[];
      sponsors: SponsorshipChoice[];
      causes: SponsorshipChoice[];
      teachers: SponsorshipChoice[];
      messages: SponsorThreadMessage[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type WorkspaceJson = {
  allowed: boolean;
  is_principal?: boolean;
  unread?: number;
  matches?: SponsorshipMatch[];
  orphans?: SponsorshipChoice[];
  sponsors?: SponsorshipChoice[];
  causes?: SponsorshipChoice[];
  teachers?: SponsorshipChoice[];
  messages?: SponsorThreadMessage[];
};

export async function readSponsorshipWorkspace(
  tx: AuthQuery,
  sessionId: string,
) {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: WorkspaceJson | string }>(sql`
    select identity.sponsorship_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace =
    typeof row?.workspace === "string"
      ? (JSON.parse(row.workspace) as WorkspaceJson)
      : row?.workspace;
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    is_principal: workspace.is_principal === true,
    unread: workspace.unread ?? 0,
    matches: workspace.matches ?? [],
    orphans: workspace.orphans ?? [],
    sponsors: workspace.sponsors ?? [],
    causes: workspace.causes ?? [],
    teachers: workspace.teachers ?? [],
    messages: workspace.messages ?? [],
  } satisfies SponsorshipWorkspace);
}

export async function manageSponsorship(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const body = input as Record<string, unknown>;
  if (body.action === "end") {
    if (
      typeof body.sponsorshipId !== "string" ||
      !uuid.test(body.sponsorshipId)
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.end_sponsorship(${sessionId}::uuid, ${body.sponsorshipId}::uuid) as code
    `);
    if (result?.code === "denied") return privateJson(result, 403);
    if (result?.code === "not_found") return privateJson(result, 404);
    if (result?.code === "ended") return privateJson(result);
    return invalid();
  }
  if (body.action === "reply") {
    const message = typeof body.body === "string" ? body.body : "";
    if (
      typeof body.sponsorshipId !== "string" ||
      !uuid.test(body.sponsorshipId) ||
      (body.language !== "ur" && body.language !== "en") ||
      !message.trim() ||
      message.length > 2000 ||
      /\p{Cc}/u.test(message)
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.reply_sponsor_message(
        ${sessionId}::uuid, ${body.sponsorshipId}::uuid, ${message.trim()}, ${body.language}
      ) as code
    `);
    if (result?.code === "denied") return privateJson(result, 403);
    if (result?.code === "sent") return privateJson(result, 201);
    if (result?.code === "contact_details" || result?.code === "unavailable")
      return privateJson(result, 409);
    return invalid();
  }
  if (
    body.action === "sign" ||
    body.action === "assign" ||
    body.action === "withdraw" ||
    body.action === "openConsent"
  ) {
    if (body.action === "openConsent") {
      const guardian =
        typeof body.guardianName === "string" ? body.guardianName.trim() : "";
      const notes = typeof body.notes === "string" ? body.notes : "";
      if (
        typeof body.studentId !== "string" ||
        !uuid.test(body.studentId) ||
        typeof body.sponsorshipId !== "string" ||
        !uuid.test(body.sponsorshipId) ||
        !guardian ||
        guardian.length > 120 ||
        notes.length > 1000 ||
        /\p{Cc}/u.test(guardian) ||
        /\p{Cc}/u.test(notes) ||
        (body.relation !== "father" &&
          body.relation !== "mother" &&
          body.relation !== "guardian" &&
          body.relation !== "other" &&
          body.relation !== "principal") ||
        (body.method !== "paper_form" &&
          body.method !== "in_person" &&
          body.method !== "phone" &&
          body.method !== "other") ||
        typeof body.givenOn !== "string" ||
        !/^\d{4}-\d{2}-\d{2}$/.test(body.givenOn)
      )
        return invalid();
      const {
        rows: [result],
      } = await tx.execute<{ code: string }>(sql`
        select identity.record_consent(
          ${sessionId}::uuid, ${body.studentId}::uuid, 'orphan_full_profile',
          ${guardian}, ${body.relation}, ${body.method}, ${body.givenOn}::date,
          ${notes}, ${body.sponsorshipId}::uuid
        ) as code
      `);
      if (result?.code === "denied") return privateJson(result, 403);
      if (result?.code === "recorded") return privateJson(result, 201);
      if (result?.code === "already" || result?.code === "unavailable")
        return privateJson(result, 409);
      return invalid();
    }
    if (typeof body.consentId !== "string" || !uuid.test(body.consentId))
      return invalid();
    const teacher = typeof body.teacherId === "string" ? body.teacherId : null;
    const reason = typeof body.reason === "string" ? body.reason : "";
    if (
      (body.action === "assign" &&
        (teacher === null || !uuid.test(teacher))) ||
      (body.action === "withdraw" &&
        (!reason.trim() || reason.length > 500 || /\p{Cc}/u.test(reason)))
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.consent_action(
        ${sessionId}::uuid, ${body.consentId}::uuid, ${body.action},
        ${teacher}::uuid, ${reason}
      ) as code
    `);
    if (result?.code === "denied") return privateJson(result, 403);
    if (
      result?.code === "assigned" ||
      result?.code === "principal_signed" ||
      result?.code === "second_signed" ||
      result?.code === "withdrawn_now"
    )
      return privateJson(result);
    if (
      result?.code === "already_signed" ||
      result?.code === "withdrawn" ||
      result?.code === "not_needed"
    )
      return privateJson(result, 409);
    return invalid();
  }
  if (body.action !== "match") return invalid();
  const { donorId, personaId, causeId } = body;
  if (
    typeof donorId !== "string" ||
    !uuid.test(donorId) ||
    typeof personaId !== "string" ||
    !uuid.test(personaId) ||
    typeof causeId !== "string" ||
    !uuid.test(causeId)
  )
    return invalid();
  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(sql`
    select identity.match_sponsorship(
      ${sessionId}::uuid, ${donorId}::uuid, ${personaId}::uuid, ${causeId}::uuid
    ) as code
  `);
  if (result?.code === "denied") return privateJson(result, 403);
  if (result?.code === "matched") return privateJson(result, 201);
  if (result?.code === "already_matched" || result?.code === "unavailable")
    return privateJson(result, 409);
  return invalid();
}
