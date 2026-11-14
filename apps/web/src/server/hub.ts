import { sql } from "drizzle-orm";
import { readJsonObject, readUuid } from "./json-body";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

const hubPostTypes = new Set([
  "message",
  "question",
  "answer",
  "poll",
  "article",
  "video",
  "vlog",
  "audio",
  "slides",
]);

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

  if (fields.action === "onboarding") {
    const command =
      typeof fields.command === "string" ? fields.command : "";
    const commands = new Set([
      "replay",
      "back",
      "suggest",
      "language",
      "name",
      "avatar",
      "bio",
      "post",
      "skip",
      "next",
      "finish",
    ]);
    const step = Number(fields.step);
    if (!commands.has(command) || !Number.isInteger(step) || step < 0 || step > 8)
      return privateJson({ code: "invalid" }, 400);
    const avatar =
      fields.avatar === undefined || fields.avatar === null
        ? null
        : Number(fields.avatar);
    if (avatar !== null && (!Number.isInteger(avatar) || avatar < 0 || avatar > 24))
      return privateJson({ code: "invalid" }, 400);
    const value = typeof fields.value === "string" ? fields.value : "";
    const {
      rows: [row],
    } = await tx.execute<{ result: { code: string } }>(sql`
      select identity.save_onboarding(
        ${sessionId}::uuid, ${command}, ${step}, ${value}, ${avatar}::smallint
      ) as result
    `);
    const result = row?.result ?? { code: "denied" };
    return privateJson(result, result.code === "ok" ? 200 : 400);
  }

  if (fields.action === "persona") {
    const name = typeof fields.name === "string" ? fields.name : null;
    const bio = typeof fields.bio === "string" ? fields.bio : null;
    const avatar =
      fields.avatar === undefined || fields.avatar === null
        ? null
        : Number(fields.avatar);
    if (avatar !== null && (!Number.isInteger(avatar) || avatar < 1 || avatar > 24))
      return privateJson({ code: "invalid" }, 400);
    const {
      rows: [row],
    } = await tx.execute<{ code: string }>(sql`
      select identity.update_persona(
        ${sessionId}::uuid, ${name}, ${avatar}::smallint, ${bio}, ${language}
      ) as code
    `);
    const code = row?.code ?? "denied";
    return privateJson({ code }, code === "saved" ? 200 : 400);
  }

  if (fields.action === "publish") {
    const postType = typeof fields.postType === "string" ? fields.postType : "";
    if (!hubPostTypes.has(postType)) return privateJson({ code: "invalid" }, 400);
    const options = Array.isArray(fields.options)
      ? fields.options.filter((item): item is string => typeof item === "string").slice(0, 6)
      : [];
    const optionSql = options.length
      ? sql`array[${sql.join(
          options.map((option) => sql`${option}`),
          sql`, `,
        )}]::text[]`
      : sql`null::text[]`;
    const hours =
      fields.hours === undefined || fields.hours === null || fields.hours === ""
        ? null
        : Number(fields.hours);
    const maxChoices =
      fields.maxChoices === undefined || fields.maxChoices === null || fields.maxChoices === ""
        ? null
        : Number(fields.maxChoices);
    const {
      rows: [row],
    } = await tx.execute<{ result: { code: string } }>(sql`
      select identity.publish_hub_post(
        ${sessionId}::uuid, ${scope}, ${classId}::uuid, ${threadId}::uuid, ${parentId}::uuid,
        ${postType}, ${language},
        ${typeof fields.title === "string" ? fields.title : ""},
        ${typeof fields.summary === "string" ? fields.summary : ""},
        ${typeof fields.body === "string" ? fields.body : ""},
        ${typeof fields.youtube === "string" ? fields.youtube : ""},
        ${typeof fields.label === "string" ? fields.label : ""},
        ${fields.multiple === true}, ${maxChoices}::smallint,
        ${fields.results === "after_voting" ? "after_voting" : "after_closing"},
        ${hours}::int, ${optionSql}
      ) as result
    `);
    const result = row?.result ?? { code: "denied" };
    return privateJson(
      result,
      result.code === "posted" ? 200 : result.code === "denied" ? 403 : 400,
    );
  }

  if (fields.action === "vote" || fields.action === "close_poll" || fields.action === "submit") {
    if (!postId) return privateJson({ code: "invalid" }, 400);
    if (fields.action === "vote") {
      const options = Array.isArray(fields.options)
        ? fields.options.filter((item): item is string => typeof item === "string" && uuid.test(item))
        : [];
      const optionSql = options.length
        ? sql`array[${sql.join(
            options.map((option) => sql`${option}::uuid`),
            sql`, `,
          )}]::uuid[]`
        : sql`array[]::uuid[]`;
      const {
        rows: [row],
      } = await tx.execute<{ code: string }>(sql`
        select identity.vote_hub_poll(${sessionId}::uuid, ${postId}::uuid, ${optionSql}) as code
      `);
      const code = row?.code ?? "denied";
      return privateJson({ code }, code === "voted" ? 200 : 400);
    }
    const {
      rows: [row],
    } = await tx.execute<{ code: string }>(sql`
      select ${
        fields.action === "close_poll"
          ? sql`identity.close_hub_poll(${sessionId}::uuid, ${postId}::uuid)`
          : sql`identity.submit_hub_post(${sessionId}::uuid, ${postId}::uuid)`
      } as code
    `);
    const code = row?.code ?? "denied";
    const ok = code === "closed" || code === "submitted" || code === "published";
    return privateJson({ code }, ok ? 200 : 400);
  }

  if (fields.action === "verify") {
    if (!threadId) return privateJson({ code: "invalid" }, 400);
    const quotes = Array.isArray(fields.quotes)
      ? fields.quotes.filter((item): item is string => typeof item === "string" && uuid.test(item)).slice(0, 12)
      : [];
    const quoteSql = quotes.length
      ? sql`array[${sql.join(
          quotes.map((quote) => sql`${quote}::uuid`),
          sql`, `,
        )}]::uuid[]`
      : sql`null::uuid[]`;
    const {
      rows: [row],
    } = await tx.execute<{ result: { code: string } }>(sql`
      select identity.make_hub_article(
        ${sessionId}::uuid, ${threadId}::uuid,
        ${typeof fields.title === "string" ? fields.title : ""},
        ${typeof fields.summary === "string" ? fields.summary : ""},
        ${typeof fields.body === "string" ? fields.body : ""},
        ${language}, ${quoteSql}
      ) as result
    `);
    const result = row?.result ?? { code: "denied" };
    return privateJson(result, result.code === "posted" ? 200 : 400);
  }

  if (fields.action === "teacher_profile") {
    const {
      rows: [row],
    } = await tx.execute<{ code: string }>(sql`
      select identity.save_teacher_profile(
        ${sessionId}::uuid,
        ${typeof fields.name === "string" ? fields.name : ""},
        ${typeof fields.role === "string" ? fields.role : ""},
        ${typeof fields.bioUr === "string" ? fields.bioUr : ""},
        ${typeof fields.bioEn === "string" ? fields.bioEn : ""}
      ) as code
    `);
    const code = row?.code ?? "denied";
    return privateJson({ code }, code === "saved" ? 200 : 400);
  }

  if (fields.action === "checklist") {
    const {
      rows: [row],
    } = await tx.execute<{ result: { code: string } }>(sql`
      select identity.admin_setup_checklist(${sessionId}::uuid) as result
    `);
    const result = row?.result ?? { code: "denied" };
    return privateJson(result, result.code === "ok" ? 200 : 403);
  }

  return privateJson({ code: "invalid" }, 400);
}
