import { sql } from "drizzle-orm";
import {
  createConsoleEmailSender,
  renderAuthEmail,
  type AuthEmail,
  type EmailSender,
} from "../../../../packages/email/src/index";
import type { AuthQuery } from "./workspace-access";

const consoleSender = createConsoleEmailSender();

// Paths whose handler sends an email. Without a sender they are unavailable.
export const emailPaths = new Set([
  "/sign-up/email",
  "/send-verification-email",
  "/request-password-reset",
]);

// The console adapter prints links, so it is only used on a local origin.
// Hosted environments get a real adapter with P1-E3-T30 (Q-06).
export function authEmailSender(local: boolean): EmailSender | undefined {
  return local ? consoleSender : undefined;
}

type AuthUser = { id: string; email: string; preferredLanguage?: unknown };

export async function sendAuthEmail(
  tx: AuthQuery,
  sender: EmailSender | undefined,
  kind: AuthEmail["kind"],
  user: AuthUser,
  url: string,
  origin: string,
) {
  if (!sender) throw new Error("Email is unavailable");
  if (kind === "reset-password") {
    const {
      rows: [allowed],
    } = await tx.execute<{ ok: boolean }>(
      sql`select identity.can_reset_by_email(${user.id}) as ok`,
    );
    // Students reset through a teacher. The response stays the same.
    if (!allowed?.ok) return;
  }
  const locale = user.preferredLanguage === "ur" ? "ur" : "en";
  const {
    rows: [institute],
  } = await tx.execute<{ name: Record<string, string> }>(
    sql`select name::jsonb as name from public_api.institute_public`,
  );
  const instituteName =
    institute?.name[locale] ?? institute?.name.ur ?? institute?.name.en ?? "";
  const content = renderAuthEmail({
    kind,
    locale,
    instituteName,
    url,
    origin,
  });
  const result = await sender.send({
    ...content,
    to: user.email,
    idempotencyKey: `${kind}/${crypto.randomUUID()}`,
  });
  if (result.status !== "accepted") throw new Error("Email was not accepted");
}
