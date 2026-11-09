import { sql } from "drizzle-orm";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";

export type AuthQuery = Pick<NodePgDatabase, "execute">;
export type AdminAccess =
  | {
      state: "allowed";
      name: string;
      canInvite: boolean;
      canEditPages: boolean;
      canRecordTransfers: boolean;
      twoFactorVerified: boolean;
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type Session = {
  user: { id: string; name: string };
  session: { id: string };
};

export async function checkWorkspaceAccess(
  tx: AuthQuery,
  access: Session | null,
): Promise<AdminAccess> {
  if (!access) return { state: "signed-out" };

  await tx.execute(
    sql`select set_config('app.user_id', ${access.user.id}, true)`,
  );
  const {
    rows: [account],
  } = await tx.execute<{
    eligible: boolean;
    admin: boolean;
    editor: boolean;
    requireMfa: boolean;
    enrolled: boolean;
  }>(sql`
    select
      app.is_staff() and u.status = 'active' and not u.must_change_password as eligible,
      app.has_role('admin') as admin,
      app.has_role('editor') as editor,
      app.has_role('admin') or app.has_role('finance_officer') as "requireMfa",
      u.two_factor_enabled and exists (
        select from identity.two_factor f
        where f.institute_id = u.institute_id and f.user_id = u.id and f.verified
      ) as enrolled
    from app.users u where u.id = ${access.user.id}
  `);
  if (!account?.eligible) return { state: "denied" };
  const allowed = {
    state: "allowed",
    name: access.user.name,
    canInvite: account.admin,
    canEditPages: account.admin || account.editor,
    canRecordTransfers: account.requireMfa,
    twoFactorVerified: account.requireMfa,
  } as const;
  if (!account.requireMfa) return allowed;

  const {
    rows: [session],
  } = await tx.execute<{ verified: boolean }>(sql`
    update identity.sessions set updated_at = now()
    where id = ${access.session.id} and user_id = ${access.user.id}
      and expires_at > now() and updated_at > now() - interval '30 minutes'
    returning two_factor_verified_at is not null as verified
  `);
  if (session && !account.enrolled) return { state: "enroll" };
  if (session?.verified) return allowed;

  await tx.execute(
    sql`delete from identity.sessions where id = ${access.session.id}`,
  );
  return { state: "signed-out" };
}
