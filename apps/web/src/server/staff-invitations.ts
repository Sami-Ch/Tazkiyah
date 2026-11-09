import { hashPassword } from "better-auth/crypto";
import { sql } from "drizzle-orm";
import type { AuthQuery } from "./workspace-access";

const roles = new Set(["teacher", "editor", "finance_officer"]);

export function privateJson(body: unknown, status = 200) {
  return Response.json(body, {
    status,
    headers: { "Cache-Control": "private, no-store" },
  });
}

export async function tokenHash(token: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );
  return Buffer.from(digest).toString("hex");
}

async function fields(request: Request) {
  const value: unknown = await request.json().catch(() => null);
  return value && typeof value === "object"
    ? (value as Record<string, unknown>)
    : {};
}

export async function issueStaffInvitation(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
  publicUrl: URL,
) {
  const input = await fields(request);
  const name = typeof input.name === "string" ? input.name.trim() : "";
  const email =
    typeof input.email === "string" ? input.email.trim().toLowerCase() : "";
  const { role, language } = input;
  if (
    !name ||
    name.length > 120 ||
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    typeof role !== "string" ||
    !roles.has(role) ||
    (language !== "en" && language !== "ur")
  )
    return privateJson({ code: "invalid" }, 400);

  const token = Buffer.from(
    crypto.getRandomValues(new Uint8Array(32)),
  ).toString("base64url");
  const hash = await tokenHash(token);
  const {
    rows: [result],
  } = await tx.execute<{ outcome: string }>(sql`
    select identity.issue_staff_invitation(${sessionId}, ${name}, ${email}, ${role}, ${language}, ${hash}) as outcome
  `);
  if (result.outcome === "conflict")
    return privateJson({ code: "conflict" }, 409);
  if (result.outcome === "invalid")
    return privateJson({ code: "invalid" }, 400);
  if (result.outcome !== "created" && result.outcome !== "reissued")
    return privateJson({ code: "denied" }, 403);

  const link = new URL(`/${language}/staff-invite`, publicUrl.origin);
  link.hash = token;
  return privateJson(
    { link: link.href },
    result.outcome === "created" ? 201 : 200,
  );
}

export async function acceptStaffInvitation(tx: AuthQuery, request: Request) {
  const { token, password } = await fields(request);
  if (
    typeof token !== "string" ||
    !/^[A-Za-z0-9_-]{43}$/.test(token) ||
    typeof password !== "string" ||
    password.length < 16 ||
    password.length > 128 ||
    /[\r\n]/.test(password)
  )
    return privateJson({ code: "invalid" }, 400);

  const hash = await tokenHash(token);
  // Filter invalid tokens before running the expensive password hash.
  const {
    rows: [invite],
  } = await tx.execute(sql`
    select 1 from identity.staff_invitations where token_hash = ${hash} and expires_at > now()
  `);
  if (!invite) return privateJson({ code: "expired" }, 410);

  const passwordHash = await hashPassword(password);
  const {
    rows: [result],
  } = await tx.execute<{ accepted: boolean }>(sql`
    select identity.accept_staff_invitation(${hash}, ${passwordHash}) as accepted
  `);
  return result.accepted
    ? privateJson({ accepted: true })
    : privateJson({ code: "expired" }, 410);
}
