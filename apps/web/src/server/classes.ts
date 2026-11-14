import { sql } from "drizzle-orm";
import type { Locale } from "@tazkiyah/i18n/routing";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

export type ClassMember = {
  user_id: string;
  name?: string;
  persona: string | null;
  real_name: string | null;
  status?: string;
};

export type ClassRoom = {
  id: string;
  name: Partial<Record<Locale, string>>;
  year_label: string | null;
  kind?: "class" | "alumni";
  archived: boolean;
  manage_students: boolean;
  manage_teachers: boolean;
  teachers: { user_id: string; name: string }[];
  students: ClassMember[];
};

export type ClassCandidate = {
  user_id: string;
  persona: string | null;
  real_name: string | null;
  class_ids: string[];
};

export type TeacherChoice = { user_id: string; name: string };

export type ClassWorkspace =
  | {
      state: "allowed";
      is_admin: boolean;
      classes: ClassRoom[];
      students: ClassCandidate[];
      teachers: TeacherChoice[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type WorkspaceJson = {
  allowed: boolean;
  is_admin?: boolean;
  classes?: ClassRoom[];
  students?: ClassCandidate[];
  teachers?: TeacherChoice[];
};

function textPair(ur: unknown, en: unknown) {
  const name: Record<string, string> = {};
  for (const [language, value] of [
    ["ur", ur],
    ["en", en],
  ] as const) {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    if (!trimmed) continue;
    if (trimmed.length > 80 || /\p{Cc}/u.test(trimmed)) return null;
    name[language] = trimmed;
  }
  return Object.keys(name).length ? name : null;
}

export async function readClassWorkspace(tx: AuthQuery, sessionId: string) {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: WorkspaceJson | string }>(sql`
    select identity.class_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace =
    typeof row?.workspace === "string"
      ? (JSON.parse(row.workspace) as WorkspaceJson)
      : row?.workspace;
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    is_admin: workspace.is_admin === true,
    classes: workspace.classes ?? [],
    students: workspace.students ?? [],
    teachers: workspace.teachers ?? [],
  } satisfies ClassWorkspace);
}

export async function manageClass(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const body = input as Record<string, unknown>;

  if (body.action === "member") {
    const { classId, userId, memberRole, change } = body;
    if (
      typeof classId !== "string" ||
      !uuid.test(classId) ||
      typeof userId !== "string" ||
      !uuid.test(userId) ||
      (memberRole !== "student" && memberRole !== "teacher") ||
      (change !== "add" && change !== "end")
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.set_class_member(
        ${sessionId}::uuid, ${classId}::uuid, ${userId}::uuid, ${memberRole}, ${change}
      ) as code
    `);
    if (result?.code === "denied") return privateJson(result, 403);
    if (result?.code === "added" || result?.code === "ended")
      return privateJson(result);
    if (result?.code === "not_found") return privateJson(result, 404);
    if (
      result?.code === "already_member" ||
      result?.code === "archived" ||
      result?.code === "unavailable"
    )
      return privateJson(result, 409);
    return invalid();
  }

  if (body.action === "leave" || body.action === "reset") {
    const userId = body.userId;
    if (typeof userId !== "string" || !uuid.test(userId)) return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(
      body.action === "leave"
        ? sql`select identity.mark_student_left(${sessionId}::uuid, ${userId}::uuid) as code`
        : sql`select identity.reset_persona(${sessionId}::uuid, ${userId}::uuid) as code`,
    );
    const code = result?.code ?? "denied";
    if (code === "left" || code === "reset" || code === "already_left")
      return privateJson({ code });
    if (code === "denied" || code === "not_found")
      return privateJson({ code }, 403);
    return invalid();
  }

  if (body.action !== "save") return invalid();
  const name = textPair(body.nameUr, body.nameEn);
  const year = body.yearLabel;
  if (
    !name ||
    (body.classId !== undefined &&
      (typeof body.classId !== "string" || !uuid.test(body.classId))) ||
    typeof year !== "string" ||
    year.trim().length > 40 ||
    typeof body.archived !== "boolean"
  )
    return invalid();
  const {
    rows: [saved],
  } = await tx.execute<{ code: string; class_id: string | null }>(sql`
    select code, class_id from identity.save_class(
      ${sessionId}::uuid, ${typeof body.classId === "string" ? body.classId : null}::uuid,
      ${JSON.stringify(name)}::jsonb, ${year.trim()}, ${body.archived}
    )
  `);
  if (saved?.code === "denied") return privateJson(saved, 403);
  if (saved?.code === "not_found") return privateJson(saved, 404);
  if (saved?.code === "saved") return privateJson(saved, 201);
  return invalid();
}
