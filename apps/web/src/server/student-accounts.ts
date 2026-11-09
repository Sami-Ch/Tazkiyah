import { hashPassword, verifyPassword } from "better-auth/crypto";
import { sql } from "drizzle-orm";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

// No 0/O, 1/l/i: the starting password is read off paper or a screen.
const passwordAlphabet = "abcdefghjkmnpqrstuvwxyz23456789";

export function startingPassword(length = 10) {
  const bytes = crypto.getRandomValues(new Uint8Array(length * 2));
  let password = "";
  for (const byte of bytes) {
    // Drop bytes that would bias the choice.
    if (byte >= 256 - (256 % passwordAlphabet.length)) continue;
    password += passwordAlphabet[byte % passwordAlphabet.length];
    if (password.length === length) return password;
  }
  return startingPassword(length);
}

function validPassword(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length >= 8 &&
    value.length <= 128 &&
    !/[\r\n]/.test(value)
  );
}

async function fields(request: Request) {
  const value: unknown = await request.json().catch(() => null);
  return value && typeof value === "object"
    ? (value as Record<string, unknown>)
    : {};
}

// A teacher or admin creates a student account (03 §6.2, 07 §4.1). The
// username and starting password are returned once and never stored in clear.
export async function createStudentAccount(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const input = await fields(request);
  const name = typeof input.name === "string" ? input.name.trim() : "";
  const chosen = input.password;
  if (
    !name ||
    name.length > 120 ||
    (chosen !== undefined && !validPassword(chosen))
  )
    return privateJson({ code: "invalid" }, 400);

  const password = chosen ?? startingPassword();
  const {
    rows: [result],
  } = await tx.execute<{ username: string | null }>(sql`
    select identity.create_student_account(${sessionId}, ${name}, ${await hashPassword(password)}) as username
  `);
  if (!result?.username) return privateJson({ code: "denied" }, 403);
  return privateJson({ username: result.username, password }, 201);
}

// The student replaces the starting password at first sign-in.
export async function setFirstPassword(
  tx: AuthQuery,
  request: Request,
  session: { user: { id: string }; session: { id: string } },
) {
  const { currentPassword, newPassword } = await fields(request);
  if (
    typeof currentPassword !== "string" ||
    !validPassword(newPassword) ||
    newPassword === currentPassword
  )
    return privateJson({ code: "invalid" }, 400);

  const {
    rows: [account],
  } = await tx.execute<{ password: string | null }>(sql`
    select password from identity.accounts
    where user_id = ${session.user.id} and provider_id = 'credential'
  `);
  if (
    !account?.password ||
    !(await verifyPassword({
      hash: account.password,
      password: currentPassword,
    }))
  )
    return privateJson({ code: "invalid_password" }, 400);

  const {
    rows: [result],
  } = await tx.execute<{ changed: boolean }>(sql`
    select identity.set_first_password(${session.session.id}, ${await hashPassword(newPassword)}) as changed
  `);
  return result?.changed
    ? privateJson({ changed: true })
    : privateJson({ code: "denied" }, 403);
}
