import { sql } from "drizzle-orm";
import {
  createConsoleEmailSender,
  createResendEmailSender,
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

export function authEmailSender(
  local: boolean,
  config: { apiKey?: string; from?: string; replyTo?: string },
): EmailSender | undefined {
  // The console adapter prints links and must stay on loopback origins.
  if (local) return consoleSender;
  const apiKey = config.apiKey?.trim();
  const from = config.from?.trim();
  if (!apiKey || !from) return undefined;
  return createResendEmailSender({
    apiKey,
    from,
    replyTo: config.replyTo?.trim() || undefined,
  });
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
