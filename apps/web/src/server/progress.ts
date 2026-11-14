import { sql } from "drizzle-orm";
import type { Locale } from "@tazkiyah/i18n/routing";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

export type ProgressChild = {
  persona_id: string;
  persona: string;
  real_name: string | null;
};

export type ProgressUpdate = {
  id: string;
  persona_id: string;
  persona: string;
  body: Partial<Record<Locale, string>>;
  published: boolean;
  hidden: boolean;
  own: boolean;
};

export type ProgressWorkspace =
  | {
      state: "allowed";
      is_admin: boolean;
      children: ProgressChild[];
      updates: ProgressUpdate[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type WorkspaceJson = {
  allowed: boolean;
  is_admin?: boolean;
  children?: ProgressChild[];
  updates?: ProgressUpdate[];
};

function note(value: unknown) {
  return typeof value === "string" && value.length <= 2000 && !/\p{Cc}/u.test(value)
    ? value
    : null;
}

export async function readProgressWorkspace(tx: AuthQuery, sessionId: string) {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: WorkspaceJson | string }>(sql`
    select identity.progress_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace =
    typeof row?.workspace === "string"
      ? (JSON.parse(row.workspace) as WorkspaceJson)
      : row?.workspace;
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    is_admin: workspace.is_admin === true,
    children: workspace.children ?? [],
    updates: workspace.updates ?? [],
  } satisfies ProgressWorkspace);
}

export async function manageProgress(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const body = input as Record<string, unknown>;
  if (body.action === "write") {
    const urdu = note(body.urdu ?? "");
    const english = note(body.english ?? "");
    if (
      typeof body.personaId !== "string" ||
      !uuid.test(body.personaId) ||
      urdu === null ||
      english === null ||
      (!urdu.trim() && !english.trim())
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.write_progress_update(
        ${sessionId}::uuid, ${body.personaId}::uuid, ${urdu}, ${english}
      ) as code
    `);
    return progressResult(result?.code);
  }
  if (body.action !== "publish" && body.action !== "hide") return invalid();
  if (typeof body.updateId !== "string" || !uuid.test(body.updateId))
    return invalid();
  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(sql`
    select identity.progress_action(
      ${sessionId}::uuid, ${body.updateId}::uuid, ${body.action}
    ) as code
  `);
  return progressResult(result?.code);
}

function progressResult(code: string | undefined) {
  if (code === "denied") return privateJson({ code }, 403);
  if (code === "not_found") return privateJson({ code }, 404);
  if (code === "published" || code === "waiting" || code === "hidden")
    return privateJson({ code }, code === "waiting" ? 201 : 200);
  if (
    code === "contact_details" ||
    code === "real_name" ||
    code === "unavailable" ||
    code === "blocked"
  )
    return privateJson({ code }, 409);
  return privateJson({ code: "invalid" }, 400);
}
