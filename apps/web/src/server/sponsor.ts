import { sql } from "drizzle-orm";
import { privateJson } from "./staff-invitations";
import { readJsonObject, readUuid } from "./json-body";
import type { AuthQuery } from "./workspace-access";

export async function handleSponsor(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const fields = await readJsonObject(request);
  if (!fields) return privateJson({ code: "invalid" }, 400);
  const sponsorshipId = readUuid(fields.sponsorshipId);

  if (fields.action === "children") {
    const {
      rows: [row],
    } = await tx.execute<{ result: { code: string } }>(sql`
      select identity.read_sponsor_children(${sessionId}::uuid) as result
    `);
    return privateJson(row?.result ?? { code: "denied" }, 200);
  }

  if (!sponsorshipId) return privateJson({ code: "invalid" }, 400);
  if (fields.action === "messages") {
    const {
      rows: [row],
    } = await tx.execute<{ result: { code: string } }>(sql`
      select identity.read_sponsor_messages(${sessionId}::uuid, ${sponsorshipId}::uuid) as result
    `);
    const result = row?.result ?? { code: "denied" };
    return privateJson(result, result.code === "ok" ? 200 : 403);
  }
  if (fields.action === "send") {
    const body = typeof fields.body === "string" ? fields.body : "";
    const language = fields.language === "ur" ? "ur" : "en";
    const {
      rows: [row],
    } = await tx.execute<{ code: string }>(sql`
      select identity.send_sponsor_message(
        ${sessionId}::uuid, ${sponsorshipId}::uuid, ${body}, ${language}
      ) as code
    `);
    const code = row?.code ?? "denied";
    return privateJson(
      { code },
      code === "sent" ? 200 : code === "invalid" ? 400 : 403,
    );
  }
  return privateJson({ code: "invalid" }, 400);
}
