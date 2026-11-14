import { sql } from "drizzle-orm";
import type { Locale } from "@tazkiyah/i18n/routing";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const postActions = ["hide", "unhide", "remove", "takedown", "restore"] as const;

export type ModerationItem = {
  id: string;
  title: string | null;
  body: string | null;
  language: string;
  scope: string;
  target_scope: string | null;
  state: string;
  hidden: boolean;
  persona: string | null;
  class_name: Partial<Record<Locale, string>> | null;
  real_name: string | null;
  shows_face: boolean;
  needs_public_consent: boolean;
  public_consent: boolean;
  face_consent: boolean;
  can_approve: boolean;
};

export type ModerationPost = {
  id: string;
  title: string | null;
  body: string | null;
  scope: string;
  state: string;
  hidden?: boolean;
  persona: string | null;
  class_name?: Partial<Record<Locale, string>> | null;
  reason?: string | null;
  can_hide?: boolean;
  can_unhide?: boolean;
  can_remove?: boolean;
  can_takedown?: boolean;
  can_restore?: boolean;
};

export type ScopeWidener = {
  id: string;
  name: string;
  can_widen: boolean;
};

export type ModerationWorkspace =
  | {
      state: "allowed";
      is_admin: boolean;
      can_widen: boolean;
      requests: ModerationItem[];
      posts: ModerationPost[];
      public_posts: ModerationPost[];
      taken_down: ModerationPost[];
      wideners: ScopeWidener[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type BoardJson = {
  allowed: boolean;
  is_admin?: boolean;
  can_widen?: boolean;
  requests?: ModerationItem[];
  posts?: ModerationPost[];
  public_posts?: ModerationPost[];
  taken_down?: ModerationPost[];
  wideners?: ScopeWidener[];
};

export async function readModerationQueue(tx: AuthQuery, sessionId: string) {
  const {
    rows: [row],
  } = await tx.execute<{ board: BoardJson | string }>(sql`
    select identity.moderation_board(${sessionId}::uuid) as board
  `);
  const board =
    typeof row?.board === "string"
      ? (JSON.parse(row.board) as BoardJson)
      : row?.board;
  if (!board?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    is_admin: board.is_admin === true,
    can_widen: board.can_widen === true,
    requests: board.requests ?? [],
    posts: board.posts ?? [],
    public_posts: board.public_posts ?? [],
    taken_down: board.taken_down ?? [],
    wideners: board.wideners ?? [],
  } satisfies ModerationWorkspace);
}

export async function decidePost(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const body = input as Record<string, unknown>;
  const { postId, action, note } = body;

  if (action === "widen") {
    if (
      typeof body.teacherId !== "string" ||
      !uuid.test(body.teacherId) ||
      typeof body.enabled !== "boolean"
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.set_scope_widener(
        ${sessionId}::uuid, ${body.teacherId}::uuid, ${body.enabled}
      ) as code
    `);
    if (result?.code === "denied") return privateJson(result, 403);
    if (result?.code === "saved") return privateJson(result);
    return invalid();
  }

  if (
    typeof action === "string" &&
    postActions.includes(action as (typeof postActions)[number])
  ) {
    if (typeof postId !== "string" || !uuid.test(postId)) return invalid();
    const reason = typeof note === "string" ? note : "";
    if (reason.length > 500 || /\p{Cc}/u.test(reason)) return invalid();
    if (action !== "unhide" && action !== "restore" && !reason.trim())
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.moderate_post(
        ${sessionId}::uuid, ${postId}::uuid, ${action}, ${reason.trim()}
      ) as code
    `);
    if (result?.code === "denied") return privateJson(result, 403);
    if (result?.code === "not_found" || result?.code === "not_waiting")
      return privateJson(result, 404);
    if (result?.code === "blocked") return privateJson(result, 409);
    if (postActions.includes(result?.code as (typeof postActions)[number]))
      return privateJson(result);
    return invalid();
  }

  if (
    typeof postId !== "string" ||
    !uuid.test(postId) ||
    (action !== "approve" && action !== "reject") ||
    typeof note !== "string" ||
    note.length > 500 ||
    /\p{Cc}/u.test(note) ||
    (action === "reject" && !note.trim())
  )
    return invalid();
  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(sql`
    select identity.decide_post(
      ${sessionId}::uuid, ${postId}::uuid, ${action}, ${note.trim()}
    ) as code
  `);
  if (result?.code === "denied") return privateJson(result, 403);
  if (result?.code === "not_waiting") return privateJson(result, 404);
  if (
    result?.code === "needs_consent" ||
    result?.code === "face_blocked" ||
    result?.code === "blocked"
  )
    return privateJson(result, 409);
  if (result?.code === "approved" || result?.code === "rejected")
    return privateJson(result);
  return invalid();
}
