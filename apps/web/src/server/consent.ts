import { sql } from "drizzle-orm";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const day = /^\d{4}-\d{2}-\d{2}$/;
const kinds = ["public_work", "real_name", "face", "orphan_full_profile"] as const;
const relations = ["father", "mother", "guardian", "other", "principal"] as const;
const methods = ["paper_form", "in_person", "phone", "other"] as const;

export type ConsentStudent = {
  id: string;
  real_name: string;
  persona: string | null;
  is_orphan: boolean;
};

export type ConsentPerson = { id: string; name: string };

export type ConsentSponsorship = {
  id: string;
  student_id: string;
  persona: string;
  real_name: string;
};

export type ConsentRecord = {
  id: string;
  student_id: string;
  real_name: string;
  persona: string | null;
  kind: string;
  guardian_name: string;
  relation: string;
  method: string;
  given_on: string;
  notes: string | null;
  sponsorship_id: string | null;
  status: string | null;
  second_signer: string | null;
  can_sign_principal: boolean;
  can_sign_second: boolean;
  can_assign: boolean;
  can_withdraw: boolean;
};

export type ConsentWorkspace =
  | {
      state: "allowed";
      is_principal: boolean;
      students: ConsentStudent[];
      teachers: ConsentPerson[];
      sponsorships: ConsentSponsorship[];
      records: ConsentRecord[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type WorkspaceJson = {
  allowed: boolean;
  is_principal?: boolean;
  students?: ConsentStudent[];
  teachers?: ConsentPerson[];
  sponsorships?: ConsentSponsorship[];
  records?: ConsentRecord[];
};

function clean(value: unknown, max: number) {
  return typeof value === "string" && value.length <= max && !/\p{Cc}/u.test(value)
    ? value
    : null;
}

export async function readConsentWorkspace(tx: AuthQuery, sessionId: string) {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: WorkspaceJson | string }>(sql`
    select identity.consent_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace =
    typeof row?.workspace === "string"
      ? (JSON.parse(row.workspace) as WorkspaceJson)
      : row?.workspace;
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    is_principal: workspace.is_principal === true,
    students: workspace.students ?? [],
    teachers: workspace.teachers ?? [],
    sponsorships: workspace.sponsorships ?? [],
    records: workspace.records ?? [],
  } satisfies ConsentWorkspace);
}

export async function manageConsent(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const body = input as Record<string, unknown>;

  if (body.action === "record") {
    const guardian = clean(body.guardianName, 120);
    const notes = body.notes === undefined || body.notes === ""
      ? ""
      : clean(body.notes, 1000);
    const sponsorship =
      body.sponsorshipId === null || body.sponsorshipId === ""
        ? null
        : body.sponsorshipId;
    if (
      typeof body.studentId !== "string" ||
      !uuid.test(body.studentId) ||
      typeof body.kind !== "string" ||
      !kinds.includes(body.kind as (typeof kinds)[number]) ||
      !guardian?.trim() ||
      typeof body.relation !== "string" ||
      !relations.includes(body.relation as (typeof relations)[number]) ||
      typeof body.method !== "string" ||
      !methods.includes(body.method as (typeof methods)[number]) ||
      typeof body.givenOn !== "string" ||
      !day.test(body.givenOn) ||
      notes === null ||
      (sponsorship !== null &&
        (typeof sponsorship !== "string" || !uuid.test(sponsorship))) ||
      (body.kind === "orphan_full_profile") !== (sponsorship !== null)
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.record_consent(
        ${sessionId}::uuid, ${body.studentId}::uuid, ${body.kind}, ${guardian.trim()},
        ${body.relation}, ${body.method}, ${body.givenOn}::date, ${notes},
        ${sponsorship}::uuid
      ) as code
    `);
    return consentResult(result?.code);
  }

  if (
    body.action !== "sign" &&
    body.action !== "assign" &&
    body.action !== "withdraw"
  )
    return invalid();
  if (typeof body.consentId !== "string" || !uuid.test(body.consentId))
    return invalid();
  const teacher = body.teacherId === undefined ? null : body.teacherId;
  const reason = body.reason === undefined ? "" : clean(body.reason, 500);
  if (
    (body.action === "assign" &&
      (typeof teacher !== "string" || !uuid.test(teacher))) ||
    (body.action === "withdraw" && (!reason || !reason.trim())) ||
    reason === null
  )
    return invalid();
  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(sql`
    select identity.consent_action(
      ${sessionId}::uuid, ${body.consentId}::uuid, ${body.action},
      ${typeof teacher === "string" ? teacher : null}::uuid, ${reason}
    ) as code
  `);
  return consentResult(result?.code);
}

function consentResult(code: string | undefined) {
  if (code === "denied" || code === "not_needed")
    return privateJson({ code }, code === "denied" ? 403 : 409);
  if (
    code === "recorded" ||
    code === "assigned" ||
    code === "principal_signed" ||
    code === "second_signed" ||
    code === "withdrawn_now"
  )
    return privateJson({ code }, code === "recorded" ? 201 : 200);
  if (
    code === "already" ||
    code === "already_signed" ||
    code === "withdrawn" ||
    code === "unavailable"
  )
    return privateJson({ code }, 409);
  return privateJson({ code: "invalid" }, 400);
}
