import { can, roles, type Role } from "@tazkiyah/core/permissions";
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
      canReverseTransfers: boolean;
      canReconcileTransfers: boolean;
      canCreateStudents: boolean;
      twoFactorVerified: boolean;
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type Session = {
  user: { id: string; name: string };
  session: { id: string };
};

export type AccountAccess =
  | {
      state: "allowed";
      name: string;
      email: string | null;
      roles: Role[];
      mustChangePassword: boolean;
    }
  | { state: "signed-out" | "enroll" | "unavailable" };

const currentRoles = sql`array(
  select r from unnest(string_to_array(${roles.join(",")}, ',')) as r
  where app.has_role(r)
)`;

export async function readAccountAccess(
  tx: AuthQuery,
  access: Session | null,
): Promise<AccountAccess> {
  if (!access) return { state: "signed-out" };

  await tx.execute(
    sql`select set_config('app.user_id', ${access.user.id}, true)`,
  );
  const {
    rows: [account],
  } = await tx.execute<{
    name: string;
    email: string | null;
    roles: Role[];
    mustChangePassword: boolean;
  }>(sql`
    select u.full_name as name, u.email, ${currentRoles} as roles,
      u.must_change_password as "mustChangePassword"
    from app.users u where u.id = ${access.user.id} and u.status in ('active', 'left')
  `);
  if (!account || !can(account, "account.edit_own", ["own"])) {
    return { state: "signed-out" };
  }

  if (
    account.roles.includes("admin") ||
    account.roles.includes("finance_officer")
  ) {
    const workspace = await checkWorkspaceAccess(tx, access);
    if (workspace.state === "enroll") return { state: "enroll" };
    if (workspace.state !== "allowed") return { state: "signed-out" };
  }

  return { state: "allowed", ...account };
}

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
    roles: Role[];
    enrolled: boolean;
  }>(sql`
    select
      app.is_staff() and u.status = 'active' and not u.must_change_password as eligible,
      ${currentRoles} as roles,
      u.two_factor_enabled and exists (
        select from identity.two_factor f
        where f.institute_id = u.institute_id and f.user_id = u.id and f.verified
      ) as enrolled
    from app.users u where u.id = ${access.user.id}
  `);
  if (!account?.eligible) return { state: "denied" };
  const actor = { roles: account.roles };
  // Two-factor is required for the admin and finance officer roles (03 §6.4).
  const requireMfa =
    account.roles.includes("admin") ||
    account.roles.includes("finance_officer");
  const allowed = {
    state: "allowed",
    name: access.user.name,
    canInvite: can(actor, "staff.manage"),
    canEditPages: can(actor, "site_pages.edit"),
    canRecordTransfers: can(actor, "donation.record"),
    canReverseTransfers: can(actor, "donation.reverse"),
    canReconcileTransfers: can(actor, "donation.reconcile"),
    canCreateStudents: can(actor, "student_account.create"),
    twoFactorVerified: requireMfa,
  } as const;
  if (!requireMfa) return allowed;

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
