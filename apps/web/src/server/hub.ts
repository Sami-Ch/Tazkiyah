import { sql } from "drizzle-orm";
import { readJsonObject, readUuid } from "./json-body";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const reasons = new Set([
  "personal_details",
  "face_or_name",
  "unkind",
  "wrong_information",
  "other",
]);

export async function handleHub(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const fields = await readJsonObject(request);
  if (!fields || typeof fields.action !== "string")
    return privateJson({ code: "invalid" }, 400);
  const classId = readUuid(fields.classId);
  const threadId = readUuid(fields.threadId);
  const parentId = readUuid(fields.parentId);
  const postId = readUuid(fields.postId);
  const scope = fields.scope === "madrasa" ? "madrasa" : "class";
  const language = fields.language === "en" ? "en" : "ur";

  if (fields.action === "read") {
    const {
      rows: [row],
    } = await tx.execute<{ result: { code: string } }>(sql`
      select identity.read_hub(
        ${sessionId}::uuid,
        ${typeof fields.scope === "string" ? scope : null},
        ${classId}::uuid,
        ${threadId}::uuid
      ) as result
    `);
    const result = row?.result ?? { code: "denied" };
    return privateJson(result, result.code === "ok" ? 200 : 403);
  }

  if (fields.action === "start") {
    const postType = fields.postType === "question" ? "question" : "message";
    const title = typeof fields.title === "string" ? fields.title : "";
    const body = typeof fields.body === "string" ? fields.body : "";
    const {
      rows: [row],
    } = await tx.execute<{ result: { code: string } }>(sql`
      select identity.start_hub_thread(
        ${sessionId}::uuid, ${scope}, ${classId}::uuid, ${postType},
        ${language}, ${title}, ${body}
      ) as result
    `);
    const result = row?.result ?? { code: "denied" };
    return privateJson(
      result,
      result.code === "posted" ? 200 : result.code === "invalid" ? 400 : 403,
    );
  }

  if (fields.action === "reply") {
    if (!threadId) return privateJson({ code: "invalid" }, 400);
    const postType = fields.postType === "answer" ? "answer" : "message";
    const body = typeof fields.body === "string" ? fields.body : "";
    const {
      rows: [row],
    } = await tx.execute<{ code: string }>(sql`
      select identity.reply_hub_thread(
        ${sessionId}::uuid, ${threadId}::uuid, ${parentId}::uuid, ${postType},
        ${language}, ${body}
      ) as code
    `);
    const code = row?.code ?? "denied";
    return privateJson(
      { code },
      code === "posted" ? 200 : code === "invalid" ? 400 : 403,
    );
  }

  if (fields.action === "report") {
    const reason = typeof fields.reason === "string" ? fields.reason : "";
    if (!postId || !reasons.has(reason))
      return privateJson({ code: "invalid" }, 400);
    const note = typeof fields.note === "string" ? fields.note : "";
    const {
      rows: [row],
    } = await tx.execute<{ code: string }>(sql`
      select identity.report_hub_post(
        ${sessionId}::uuid, ${postId}::uuid, ${reason}, ${note}
      ) as code
    `);
    const code = row?.code ?? "denied";
    return privateJson(
      { code },
      code === "reported" || code === "already" ? 200 : 403,
    );
  }

  return privateJson({ code: "invalid" }, 400);
}
