import { sql } from "drizzle-orm";
import { privateJson } from "./staff-invitations";
import type { AdminAccess, AuthQuery } from "./workspace-access";

type Change = { old: string | boolean | null; new: string | boolean | null };

export type AuditEntry = {
  id: string;
  occurred_at: string;
  actor_id: string | null;
  actor_kind: string;
  roles: string[];
  action: string;
  entity: string;
  entity_ref: string | null;
  changes: Record<string, Change>;
  hidden_fields: number;
};

export type AuditWorkspace =
  | { state: "allowed"; entries: AuditEntry[]; hasNext: boolean }
  | { state: Exclude<AdminAccess["state"], "allowed"> };

const pageSize = 50;
const lastPage = 201;

export function auditFilters(params: URLSearchParams) {
  const page = Number(params.get("page"));
  const days = params.get("days");
  const action = params.get("action");
  const entity = params.get("entity");

  return {
    page: Number.isInteger(page) && page >= 1 && page <= lastPage ? page : 1,
    days: days === "1" || days === "7" || days === "30" ? days : "",
    action: action && /^[a-z][a-z0-9_.]{0,79}$/.test(action) ? action : "",
    entity: entity && /^[a-z][a-z0-9_]{0,49}$/.test(entity) ? entity : "",
  } as const;
}

export async function readAuditWorkspace(
  tx: AuthQuery,
  sessionId: string,
  url: URL,
) {
  const { page, days, action, entity } = auditFilters(url.searchParams);
  const { rows } = await tx.execute<AuditEntry>(sql`
    select * from identity.read_audit_log(
      ${sessionId}, ${days ? Number(days) : null}, ${action || null},
      ${entity || null}, ${(page - 1) * pageSize}
    )
  `);
  return privateJson({
    state: "allowed",
    entries: rows.slice(0, pageSize),
    hasNext: page < lastPage && rows.length > pageSize,
  } satisfies AuditWorkspace);
}
