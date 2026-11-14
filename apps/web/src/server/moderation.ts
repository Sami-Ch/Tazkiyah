import { sql } from "drizzle-orm";
import type { Locale } from "@tazkiyah/i18n/routing";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

export type ModerationItem = {
  id: string;
  title: string | null;
  body: string | null;
  language: string;
  scope: string;
  target_scope: string | null;
  persona: string | null;
  class_name: Partial<Record<Locale, string>> | null;
  real_name: string | null;
  shows_face: boolean;
  needs_public_consent: boolean;
  public_consent: boolean;
  face_consent: boolean;
};

export type ModerationWorkspace =
  | { state: "allowed"; items: ModerationItem[] }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

export async function readModerationQueue(tx: AuthQuery, sessionId: string) {
  const {
    rows: [row],
  } = await tx.execute<{
    queue: { allowed: boolean; items?: ModerationItem[] } | string;
  }>(sql`select identity.moderation_queue(${sessionId}::uuid) as queue`);
  const queue =
    typeof row?.queue === "string"
      ? (JSON.parse(row.queue) as {
          allowed: boolean;
          items?: ModerationItem[];
        })
      : row?.queue;
  if (!queue?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    items: queue.items ?? [],
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
  const { postId, action, note } = input as Record<string, unknown>;
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
