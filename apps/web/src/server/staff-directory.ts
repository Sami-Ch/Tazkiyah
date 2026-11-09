import { sql } from "drizzle-orm";
import { privateJson } from "./staff-invitations";
import type { AdminAccess, AuthQuery } from "./workspace-access";

export const staffRoles = [
  "admin",
  "teacher",
  "editor",
  "finance_officer",
] as const;
const staffStatuses = ["active", "invited", "suspended", "left"] as const;
export type StaffRole = (typeof staffRoles)[number];
export type StaffStatus = (typeof staffStatuses)[number];

export type StaffEntry = {
  id: string;
  name: string;
  email: string | null;
  status: StaffStatus;
  roles: StaffRole[];
  manageable: boolean;
  invitation: "pending" | "expired" | null;
};

export type StaffDirectory =
  | { state: "allowed"; staff: StaffEntry[]; hasNext: boolean }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

const pageSize = 50;
const lastPage = 201;

function isRole(value: unknown): value is StaffRole {
  return staffRoles.some((role) => role === value);
}

export function directoryFilters(params: URLSearchParams) {
  const role = params.get("role");
  const status = params.get("status");
  const page = Number(params.get("page"));
  return {
    search: params.get("q")?.trim().slice(0, 120) ?? "",
    role: isRole(role) ? role : "",
    status: staffStatuses.find((value) => value === status) ?? "",
    page: Number.isInteger(page) && page >= 1 && page <= lastPage ? page : 1,
  } as const;
}

export async function listStaff(tx: AuthQuery, sessionId: string, url: URL) {
  const { search, role, status, page } = directoryFilters(url.searchParams);
  const { rows } = await tx.execute<StaffEntry>(sql`
    select id, name, email, status, roles, manageable,
      case when invitation_expires_at > now() then 'pending'
           when invitation_expires_at is not null then 'expired'
      end as invitation
    from identity.list_staff(
      ${sessionId}, ${search || null}, ${role || null}, ${status || null}, ${(page - 1) * pageSize}
    )
  `);
  return privateJson({
    state: "allowed",
    staff: rows.slice(0, pageSize),
    hasNext: page < lastPage && rows.length > pageSize,
  } satisfies StaffDirectory);
}

function roleList(value: unknown): StaffRole[] | null {
  if (
    !Array.isArray(value) ||
    value.length < 1 ||
    value.length > staffRoles.length ||
    !value.every(isRole) ||
    new Set(value).size !== value.length
  ) {
    return null;
  }
  return [...value].sort();
}

export async function updateStaffAccess(
  tx: AuthQuery,
  request: Request,
  access: { user: { id: string }; session: { id: string } },
) {
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object")
    return privateJson({ code: "invalid" }, 400);

  const { id, expectedStatus, expectedRoles, nextStatus, nextRoles } =
    input as Record<string, unknown>;
  const currentRoles = roleList(expectedRoles);
  const requestedRoles = nextRoles === undefined ? null : roleList(nextRoles);
  const requestedStatus = nextStatus === undefined ? null : nextStatus;
  if (
    typeof id !== "string" ||
    !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(id) ||
    (expectedStatus !== "active" && expectedStatus !== "suspended") ||
    !currentRoles ||
    (nextRoles === undefined) === (nextStatus === undefined) ||
    (nextRoles !== undefined && !requestedRoles) ||
    (requestedStatus !== null &&
      requestedStatus !== "active" &&
      requestedStatus !== "suspended")
  ) {
    return privateJson({ code: "invalid" }, 400);
  }

  await tx.execute(
    sql`select set_config('app.user_id', ${access.user.id}, true)`,
  );
  const {
    rows: [result],
  } = await tx.execute<{ outcome: string }>(sql`
    select identity.update_staff_access(
      ${access.session.id}, ${id}, ${expectedStatus}, ${sql.param(currentRoles)}::text[],
      ${requestedStatus}, ${sql.param(requestedRoles)}::text[]
    ) as outcome
  `);
  if (result.outcome === "stale") return privateJson({ code: "stale" }, 409);
  if (result.outcome === "invalid")
    return privateJson({ code: "invalid" }, 400);
  if (result.outcome !== "updated") return privateJson({ code: "denied" }, 403);
  return privateJson({ updated: true });
}
