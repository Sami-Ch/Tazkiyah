import { drizzleAdapter } from "@better-auth/drizzle-adapter";
import { getCloudflareContext } from "@opennextjs/cloudflare";
import {
  authAccounts,
  authRateLimit,
  authSessions,
  authTwoFactor,
  authVerification,
} from "@tazkiyah/core/db/identity";
import { users } from "@tazkiyah/core/db/schema";
import { betterAuth } from "better-auth";
import { APIError, createAuthMiddleware } from "better-auth/api";
import { twoFactor, username } from "better-auth/plugins";
import { eq, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import {
  listStaff,
  updateStaffAccess,
  type StaffDirectory,
} from "./staff-directory";
import type { PublishedSitePage } from "@/institutes/site-pages";
import type { PublishedInstituteContact } from "@/institutes/contact";
import { readPublishedInstituteContact } from "./contact";
import type { PublishedBankAccount } from "@/institutes/giving";
import {
  readBankWorkspace,
  readPublishedBankAccounts,
  writeBankAccount,
  type BankWorkspace,
} from "./bank-accounts";
import type { PublishedCause } from "@/institutes/causes";
import {
  readCauseWorkspace,
  readPublishedCauses,
  writeCause,
  type CauseWorkspace,
} from "./causes";
import {
  readPublishedSitePages,
  readSitePageWorkspace,
  writeSitePage,
  type SitePageWorkspace,
} from "./site-pages";
import { authOriginHeader, forwardedHttpsOrigin } from "./auth-origin";
import { readAuditWorkspace, type AuditWorkspace } from "./audit-log";
import { manageDonorLink, readDonorTrail, readTrailQuery } from "./donor-trail";
import {
  manageDonationReversal,
  readDonationWorkspace,
  recordDonation,
  type DonationWorkspace,
} from "./manual-donations";
import {
  acceptStaffInvitation,
  issueStaffInvitation,
  privateJson,
} from "./staff-invitations";
import {
  checkWorkspaceAccess,
  readAccountAccess,
  type AccountAccess,
  type AdminAccess,
} from "./workspace-access";
import { authEmailSender, emailPaths, sendAuthEmail } from "./auth-email";
import { createStudentAccount, setFirstPassword } from "./student-accounts";

const authSchema = {
  user: users,
  account: authAccounts,
  session: authSessions,
  verification: authVerification,
  twoFactor: authTwoFactor,
  rateLimit: authRateLimit,
};

const postEndpoints = new Set([
  "/sign-in/email",
  "/sign-up/email",
  "/send-verification-email",
  "/request-password-reset",
  "/reset-password",
  "/sign-in/username",
  "/sign-out",
  "/revoke-sessions",
  "/two-factor/enable",
  "/staff-invite",
  "/staff-access",
  "/site-page",
  "/cause",
  "/staff-invite/accept",
  "/student-account",
  "/first-password",
  "/manual-donation",
  "/donation-reversal",
  "/bank-account",
  "/donor-trail",
  "/donor-link",
  "/two-factor/verify-totp",
  "/two-factor/verify-backup-code",
]);

const signInPaths = new Set(["/sign-in/email", "/sign-in/username"]);

// Sign-up cannot choose a username, institute, image or anything else.
const signUpFields = new Set([
  "name",
  "email",
  "password",
  "preferredLanguage",
  "callbackURL",
]);

// Thrown inside the transaction to undo its writes and still answer.
class RollbackWith extends Error {
  constructor(readonly response: Response) {
    super("rollback");
  }
}

const twoFactorVerification = new Set([
  "/two-factor/verify-totp",
  "/two-factor/verify-backup-code",
]);

function jsonError(message: string, status: number) {
  return privateJson({ message }, status);
}

type AuthBindings = {
  AUTH_HYPERDRIVE?: { connectionString: string };
  AUTH_DATABASE_URL?: string;
  BETTER_AUTH_SECRET?: string;
  BETTER_AUTH_LOCAL_ORIGIN?: string;
  BETTER_AUTH_LOCAL_INSTITUTE_DOMAIN?: string;
  RESEND_API_KEY?: string;
  AUTH_EMAIL_FROM?: string;
  AUTH_EMAIL_REPLY_TO?: string;
};

function workerBindings(): AuthBindings | undefined {
  try {
    return getCloudflareContext().env as AuthBindings;
  } catch {
    return undefined;
  }
}

export async function handleAuth(request: Request) {
  const url = new URL(request.url);
  const path = url.pathname.slice("/api/auth".length);
  const getEndpoint =
    path === "/get-session" ||
    path === "/verify-email" ||
    /^\/reset-password\/[A-Za-z0-9_-]{1,128}$/.test(path);
  if (
    !(request.method === "GET" && getEndpoint) &&
    !(request.method === "POST" && postEndpoints.has(path))
  ) {
    return jsonError("Not found.", 404);
  }
  return runAuth(request, path);
}

export function getAdminAccess(headers: Headers): Promise<AdminAccess> {
  return readWorkspace<AdminAccess>(headers, "/admin-access");
}

export function getAccountAccess(headers: Headers): Promise<AccountAccess> {
  return readWorkspace<AccountAccess>(headers, "/account-access");
}

export function getStaffDirectory(
  headers: Headers,
  filters: URLSearchParams,
): Promise<StaffDirectory> {
  return readWorkspace<StaffDirectory>(headers, "/staff-directory", filters);
}

export function getAuditWorkspace(
  headers: Headers,
  filters: URLSearchParams,
): Promise<AuditWorkspace> {
  return readWorkspace<AuditWorkspace>(headers, "/audit-workspace", filters);
}

export function getDonationWorkspace(
  headers: Headers,
): Promise<DonationWorkspace> {
  return readWorkspace<DonationWorkspace>(
    headers,
    "/manual-donation-workspace",
  );
}

export function getBankWorkspace(headers: Headers): Promise<BankWorkspace> {
  return readWorkspace<BankWorkspace>(headers, "/bank-settings");
}

export function getSitePageWorkspace(
  headers: Headers,
): Promise<SitePageWorkspace> {
  return readWorkspace<SitePageWorkspace>(headers, "/site-page-workspace");
}

export async function getPublishedSitePages(
  headers: Headers,
): Promise<PublishedSitePage[]> {
  const response = await instituteRequest(headers, "/site-pages-public");
  return response.ok ? response.json() : [];
}

export async function getPublishedInstituteContact(
  headers: Headers,
): Promise<PublishedInstituteContact | null> {
  const response = await instituteRequest(headers, "/contact-public");
  return response.ok ? response.json() : null;
}

export async function getPublishedBankAccounts(
  headers: Headers,
): Promise<PublishedBankAccount[]> {
  const response = await instituteRequest(headers, "/bank-accounts-public");
  return response.ok ? response.json() : [];
}

export function getCauseWorkspace(headers: Headers): Promise<CauseWorkspace> {
  return readWorkspace<CauseWorkspace>(headers, "/cause-workspace");
}

export async function getPublishedCauses(
  headers: Headers,
  slug?: string,
): Promise<PublishedCause[]> {
  const filters =
    slug === undefined ? undefined : new URLSearchParams({ slug });
  const response = await instituteRequest(headers, "/causes-public", filters);
  return response.ok ? response.json() : [];
}

async function readWorkspace<
  T extends
    | AccountAccess
    | AdminAccess
    | StaffDirectory
    | SitePageWorkspace
    | CauseWorkspace
    | AuditWorkspace
    | DonationWorkspace
    | BankWorkspace,
>(
  headers: Headers,
  path: string,
  filters?: URLSearchParams,
): Promise<T | { state: "signed-out" | "unavailable" }> {
  if (!headers.has("cookie")) return { state: "signed-out" };
  const response = await instituteRequest(headers, path, filters);
  if (!response.ok) return { state: "unavailable" };
  return response.json();
}

function instituteRequest(
  headers: Headers,
  path: string,
  filters?: URLSearchParams,
) {
  const configuredOrigin = process.env.BETTER_AUTH_LOCAL_ORIGIN;
  const origin =
    configuredOrigin &&
    URL.canParse(configuredOrigin) &&
    new URL(configuredOrigin).host === headers.get("host")
      ? configuredOrigin
      : (forwardedHttpsOrigin(headers) ?? "http://invalid.invalid");
  const url = new URL(`/api/auth${path}`, origin);
  if (filters) url.search = filters.toString();
  return runAuth(new Request(url, { headers }), path);
}

async function runAuth(request: Request, path: string) {
  const url = new URL(request.url);
  const bindings = workerBindings();
  const vercel = !bindings && process.env.VERCEL === "1";
  const origin = bindings
    ? request.headers.get(authOriginHeader)
    : vercel
      ? forwardedHttpsOrigin(request.headers)
      : url.origin;
  if (!origin) return jsonError("Not found.", 404);

  const publicUrl = new URL(url.pathname + url.search, origin);
  if (
    request.method === "POST" &&
    request.headers.get("origin") !== publicUrl.origin
  ) {
    return jsonError("Invalid origin.", 403);
  }

  const local =
    publicUrl.protocol === "http:" &&
    ["localhost", "127.0.0.1", "[::1]"].includes(publicUrl.hostname) &&
    publicUrl.origin ===
      (bindings?.BETTER_AUTH_LOCAL_ORIGIN ??
        process.env.BETTER_AUTH_LOCAL_ORIGIN);
  if (publicUrl.protocol !== "https:" && !local)
    return jsonError("Not found.", 404);

  if ((path === "/donor-trail" || path === "/donor-link") && publicUrl.search)
    return jsonError("Invalid request.", 400);
  const trailQuery =
    path === "/donor-trail" ? await readTrailQuery(request) : null;
  if (path === "/donor-trail" && !trailQuery)
    return jsonError("Invalid request.", 400);

  const host = local
    ? (bindings?.BETTER_AUTH_LOCAL_INSTITUTE_DOMAIN ??
      process.env.BETTER_AUTH_LOCAL_INSTITUTE_DOMAIN)
    : publicUrl.hostname;
  const ipHeader = vercel ? "x-vercel-forwarded-for" : "cf-connecting-ip";
  const ip = local ? "127.0.0.1" : request.headers.get(ipHeader);
  const secret = bindings?.BETTER_AUTH_SECRET ?? process.env.BETTER_AUTH_SECRET;
  const publicContent =
    trailQuery !== null ||
    path === "/site-pages-public" ||
    path === "/contact-public" ||
    path === "/causes-public" ||
    path === "/bank-accounts-public";
  if (!host || (!publicContent && (!ip || !secret || secret.length < 32))) {
    return jsonError("Authentication is unavailable.", 503);
  }
  const emailSender = authEmailSender(local, {
    apiKey: bindings?.RESEND_API_KEY ?? process.env.RESEND_API_KEY,
    from: bindings?.AUTH_EMAIL_FROM ?? process.env.AUTH_EMAIL_FROM,
    replyTo: bindings?.AUTH_EMAIL_REPLY_TO ?? process.env.AUTH_EMAIL_REPLY_TO,
  });
  if (emailPaths.has(path) && !emailSender)
    return jsonError("Email is unavailable.", 503);

  let client: pg.Client | undefined;
  let closing = false;
  try {
    const database =
      bindings?.AUTH_HYPERDRIVE?.connectionString ??
      bindings?.AUTH_DATABASE_URL ??
      process.env.AUTH_DATABASE_URL;
    if (!database) return jsonError("Authentication is unavailable.", 503);
    const authClient = new pg.Client({
      connectionString: database,
      connectionTimeoutMillis: 5_000,
    });
    authClient.on("error", (error: Error) => {
      // The Workerd socket can reject its pending read during a normal client.end().
      if (
        closing &&
        bindings &&
        error instanceof TypeError &&
        error.message === "This socket has been closed."
      )
        return;
      console.error("Database connection error.", error.name);
    });
    client = authClient;
    await authClient.connect();
    const response = await drizzle({ client: authClient }).transaction(
      async (tx) => {
        const {
          rows: [role],
        } = await tx.execute<{ role: string }>(
          sql`select current_user as role`,
        );
        if (role?.role !== "tazkiyah_auth")
          throw new Error("Invalid authentication role");

        const {
          rows: [institute],
        } = await tx.execute<{ id: string | null }>(
          sql`select app.resolve_institute(${host}) as id`,
        );
        if (!institute?.id) return jsonError("Not found.", 404);
        await tx.execute(
          sql`select set_config('app.institute_id', ${institute.id}, true)`,
        );

        if (trailQuery) return readDonorTrail(tx, trailQuery);
        if (path === "/site-pages-public") return readPublishedSitePages(tx);
        if (path === "/contact-public")
          return readPublishedInstituteContact(tx);
        if (path === "/bank-accounts-public")
          return readPublishedBankAccounts(tx);
        if (path === "/causes-public")
          return readPublishedCauses(tx, publicUrl.searchParams.get("slug"));
        if (!ip || !secret)
          return jsonError("Authentication is unavailable.", 503);

        // Better Auth's database rate limiter can race to create the first bucket.
        // Serialize requests for the same tenant and IP inside this transaction.
        await tx.execute(
          sql`select pg_advisory_xact_lock(hashtextextended(${institute.id + ":" + ip}, 0))`,
        );
        const headers = new Headers(request.headers);
        if (local) headers.set("cf-connecting-ip", ip);

        let unverifiedSignIn = false;
        const auth = betterAuth({
          baseURL: publicUrl.origin,
          secret,
          database: drizzleAdapter(tx, {
            provider: "pg",
            schema: authSchema,
            transaction: true,
          }),
          emailAndPassword: {
            enabled: true,
            // The public form creates donor accounts only; the database makes
            // every self-created user an active donor (0019_donor_sign_up).
            disableSignUp: false,
            // No session at sign-up, so a sign-up for a known email gets the
            // same answer as a new one.
            autoSignIn: false,
            revokeSessionsOnPasswordReset: true,
            resetPasswordTokenExpiresIn: 60 * 60,
            sendResetPassword: ({ user, url }) =>
              sendAuthEmail(
                tx,
                emailSender,
                "reset-password",
                user,
                url,
                publicUrl.origin,
              ),
          },
          emailVerification: {
            sendOnSignUp: true,
            autoSignInAfterVerification: false,
            expiresIn: 60 * 60,
            sendVerificationEmail: ({ user, url }) =>
              sendAuthEmail(
                tx,
                emailSender,
                "verify-email",
                user,
                url,
                publicUrl.origin,
              ),
          },
          user: {
            fields: { name: "fullName", image: "authImage" },
            additionalFields: {
              instituteId: {
                type: "string",
                input: false,
                returned: false,
                defaultValue: institute.id,
              },
              preferredLanguage: {
                type: "string",
                required: false,
                returned: false,
              },
              // Tells the sign-in page to ask for a new password first.
              mustChangePassword: {
                type: "boolean",
                input: false,
                required: false,
              },
            },
          },
          session: {
            // The longest role lifetime. The database caps each session by role
            // and ends idle sessions (03 §6.5, identity.touch_session).
            expiresIn: 90 * 24 * 60 * 60,
            disableSessionRefresh: true,
            cookieCache: { enabled: false },
          },
          advanced: {
            database: { generateId: "uuid" },
            useSecureCookies: !local,
            cookiePrefix: "tazkiyah",
            ipAddress: {
              ipAddressHeaders: [ipHeader],
              ipv6Subnet: 128,
            },
          },
          rateLimit: {
            enabled: true,
            storage: "database",
            customRules: { "/sign-in/*": { window: 15 * 60, max: 10 } },
          },
          logger: { disabled: true },
          plugins: [
            username({
              displayUsername: false,
              usernameValidator: (value) => /^[a-zA-Z0-9_.-]+$/.test(value),
            }),
            twoFactor({
              issuer: "Tazkiyah",
              accountLockout: { maxFailedAttempts: 5, durationSeconds: 900 },
            }),
          ],
          hooks: {
            before: createAuthMiddleware(async (ctx) => {
              if (ctx.body && "trustDevice" in ctx.body)
                ctx.body.trustDevice = false;
              if (ctx.path === "/sign-up/email") {
                const body: Record<string, unknown> = ctx.body ?? {};
                const { preferredLanguage } = body;
                if (
                  Object.keys(body).some((key) => !signUpFields.has(key)) ||
                  (preferredLanguage !== undefined &&
                    preferredLanguage !== "en" &&
                    preferredLanguage !== "ur")
                )
                  throw new APIError("BAD_REQUEST", {
                    code: "INVALID_SIGN_UP",
                    message: "Invalid sign-up.",
                  });
              }
            }),
            after: createAuthMiddleware(async (ctx) => {
              const signedIn = ctx.context.newSession;
              if (signedIn && ctx.path && signInPaths.has(ctx.path)) {
                // Donor accounts must confirm their email first (03 §6.2).
                const {
                  rows: [check],
                } = await tx.execute<{ needed: boolean }>(
                  sql`select identity.needs_email_verification(${signedIn.user.id}) as needed`,
                );
                if (check?.needed) {
                  unverifiedSignIn = true;
                  throw new APIError("FORBIDDEN", {
                    code: "EMAIL_NOT_VERIFIED",
                    message: "Email not verified.",
                  });
                }
              }
              const session = ctx.context.newSession?.session;
              if (session && ctx.path && twoFactorVerification.has(ctx.path)) {
                await tx
                  .update(authSessions)
                  .set({ twoFactorVerifiedAt: sql`now()` })
                  .where(eq(authSessions.id, session.id));
              }
            }),
          },
        });
        const currentSession = async () => {
          const session = await auth.api.getSession({ headers });
          if (!session) return null;
          const {
            rows: [touched],
          } = await tx.execute<{ valid: boolean }>(
            sql`select identity.touch_session(${session.session.id}) as valid`,
          );
          return touched?.valid ? session : null;
        };
        if (path === "/get-session") return privateJson(await currentSession());
        if (path === "/account-access") {
          return privateJson(
            await readAccountAccess(tx, await currentSession()),
          );
        }
        if (path === "/staff-invite/accept") {
          return acceptStaffInvitation(tx, request);
        }
        if (path === "/first-password") {
          const session = await currentSession();
          return session
            ? setFirstPassword(tx, request, session)
            : privateJson({ code: "denied" }, 403);
        }
        if (path === "/staff-access") {
          const session = await currentSession();
          return session
            ? updateStaffAccess(tx, request, session)
            : privateJson({ code: "denied" }, 403);
        }
        if (
          path === "/admin-access" ||
          path === "/staff-invite" ||
          path === "/staff-directory" ||
          path === "/audit-workspace" ||
          path === "/donor-link" ||
          path === "/student-account" ||
          path === "/bank-settings" ||
          path === "/bank-account" ||
          path === "/manual-donation-workspace" ||
          path === "/manual-donation" ||
          path === "/donation-reversal" ||
          path === "/site-page-workspace" ||
          path === "/site-page" ||
          path === "/cause-workspace" ||
          path === "/cause"
        ) {
          const session = await currentSession();
          const access = await checkWorkspaceAccess(tx, session);
          if (path === "/admin-access") return privateJson(access);
          if (path === "/donation-reversal") {
            if (
              !session ||
              access.state !== "allowed" ||
              !access.canReverseTransfers
            )
              return privateJson({ code: "denied" }, 403);
            return manageDonationReversal(tx, request, session.session.id);
          }
          if (path === "/student-account") {
            if (
              !session ||
              access.state !== "allowed" ||
              !access.canCreateStudents
            )
              return privateJson({ code: "denied" }, 403);
            return createStudentAccount(tx, request, session.session.id);
          }
          if (path === "/donor-link") {
            if (!session || access.state !== "allowed" || !access.canInvite)
              return privateJson({ code: "denied" }, 403);
            return manageDonorLink(
              tx,
              request,
              session.session.id,
              publicUrl.origin,
            );
          }
          if (path === "/bank-settings" || path === "/bank-account") {
            if (path === "/bank-settings" && access.state !== "allowed")
              return privateJson(access);
            if (!session || access.state !== "allowed" || !access.canInvite)
              return path === "/bank-account"
                ? privateJson({ code: "denied" }, 403)
                : privateJson({ state: "denied" });
            return path === "/bank-account"
              ? writeBankAccount(tx, request, session.session.id)
              : readBankWorkspace(tx, session.session.id);
          }
          if (
            path === "/manual-donation-workspace" ||
            path === "/manual-donation"
          ) {
            if (
              path === "/manual-donation-workspace" &&
              access.state !== "allowed"
            )
              return privateJson(access);
            if (
              !session ||
              access.state !== "allowed" ||
              !access.canRecordTransfers
            )
              return path === "/manual-donation"
                ? privateJson({ code: "denied" }, 403)
                : privateJson({ state: "denied" });
            return path === "/manual-donation"
              ? recordDonation(tx, request, session.session.id)
              : readDonationWorkspace(tx, session.session.id);
          }
          if (path === "/cause-workspace" || path === "/cause") {
            if (path === "/cause-workspace" && access.state !== "allowed")
              return privateJson(access);
            if (!session || access.state !== "allowed" || !access.canInvite)
              return path === "/cause"
                ? privateJson({ code: "denied" }, 403)
                : privateJson({ state: "denied" });
            return path === "/cause"
              ? writeCause(tx, request, session.session.id)
              : readCauseWorkspace(tx, session.session.id);
          }
          if (path === "/site-page-workspace" || path === "/site-page") {
            if (path === "/site-page-workspace" && access.state !== "allowed") {
              return privateJson(access);
            }
            if (
              !session ||
              access.state !== "allowed" ||
              !access.canEditPages
            ) {
              return path === "/site-page"
                ? privateJson({ code: "denied" }, 403)
                : privateJson({ state: "denied" });
            }
            return path === "/site-page"
              ? writeSitePage(tx, request, session.session.id)
              : readSitePageWorkspace(tx, session.session.id);
          }
          if (path === "/staff-directory" || path === "/audit-workspace") {
            if (access.state !== "allowed") return privateJson(access);
            if (!session || !access.canInvite)
              return privateJson({ state: "denied" });
            return path === "/audit-workspace"
              ? readAuditWorkspace(tx, session.session.id, publicUrl)
              : listStaff(tx, session.session.id, publicUrl);
          }
          if (!session || access.state !== "allowed" || !access.canInvite) {
            return privateJson({ code: "denied" }, 403);
          }
          return issueStaffInvitation(
            tx,
            request,
            session.session.id,
            publicUrl,
          );
        }
        const result = await auth.handler(
          new Request(publicUrl, new Request(request, { headers })),
        );
        // Undo the session and its audit row, and send no session cookie.
        if (unverifiedSignIn)
          throw new RollbackWith(
            privateJson(
              { code: "EMAIL_NOT_VERIFIED", message: "Email not verified." },
              403,
            ),
          );
        if (result.status >= 500)
          throw new Error("Authentication handler failed");
        result.headers.set("Cache-Control", "private, no-store");
        return result;
      },
    );
    return response;
  } catch (error) {
    if (error instanceof RollbackWith) return error.response;
    return jsonError("Authentication is unavailable.", 503);
  } finally {
    closing = true;
    await client
      ?.end()
      .catch(() => console.error("Database connection did not close cleanly."));
  }
}
