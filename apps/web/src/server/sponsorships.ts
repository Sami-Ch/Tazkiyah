import { sql } from "drizzle-orm";
import type { Locale } from "@tazkiyah/i18n/routing";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

export type SponsorshipMatch = {
  id: string;
  persona: string;
  real_name: string;
  status: string;
  started_on: string;
  sponsor: string | null;
};

export type SponsorshipChoice = {
  id?: string;
  persona_id?: string;
  persona?: string;
  real_name?: string;
  name?: string;
  title?: Partial<Record<Locale, string>>;
};

export type SponsorshipWorkspace =
  | {
      state: "allowed";
      matches: SponsorshipMatch[];
      orphans: SponsorshipChoice[];
      sponsors: SponsorshipChoice[];
      causes: SponsorshipChoice[];
    }
  | { state: "signed-out" | "denied" | "enroll" | "unavailable" };

type WorkspaceJson = {
  allowed: boolean;
  matches?: SponsorshipMatch[];
  orphans?: SponsorshipChoice[];
  sponsors?: SponsorshipChoice[];
  causes?: SponsorshipChoice[];
};

export async function readSponsorshipWorkspace(
  tx: AuthQuery,
  sessionId: string,
) {
  const {
    rows: [row],
  } = await tx.execute<{ workspace: WorkspaceJson | string }>(sql`
    select identity.sponsorship_workspace(${sessionId}::uuid) as workspace
  `);
  const workspace =
    typeof row?.workspace === "string"
      ? (JSON.parse(row.workspace) as WorkspaceJson)
      : row?.workspace;
  if (!workspace?.allowed) return privateJson({ state: "denied" });
  return privateJson({
    state: "allowed",
    matches: workspace.matches ?? [],
    orphans: workspace.orphans ?? [],
    sponsors: workspace.sponsors ?? [],
    causes: workspace.causes ?? [],
  } satisfies SponsorshipWorkspace);
}

export async function manageSponsorship(
  tx: AuthQuery,
  request: Request,
  sessionId: string,
) {
  const invalid = () => privateJson({ code: "invalid" }, 400);
  const input: unknown = await request.json().catch(() => null);
  if (!input || typeof input !== "object") return invalid();
  const body = input as Record<string, unknown>;
  if (body.action === "end") {
    if (
      typeof body.sponsorshipId !== "string" ||
      !uuid.test(body.sponsorshipId)
    )
      return invalid();
    const {
      rows: [result],
    } = await tx.execute<{ code: string }>(sql`
      select identity.end_sponsorship(${sessionId}::uuid, ${body.sponsorshipId}::uuid) as code
    `);
    if (result?.code === "denied") return privateJson(result, 403);
    if (result?.code === "not_found") return privateJson(result, 404);
    if (result?.code === "ended") return privateJson(result);
    return invalid();
  }
  if (body.action !== "match") return invalid();
  const { donorId, personaId, causeId } = body;
  if (
    typeof donorId !== "string" ||
    !uuid.test(donorId) ||
    typeof personaId !== "string" ||
    !uuid.test(personaId) ||
    typeof causeId !== "string" ||
    !uuid.test(causeId)
  )
    return invalid();
  const {
    rows: [result],
  } = await tx.execute<{ code: string }>(sql`
    select identity.match_sponsorship(
      ${sessionId}::uuid, ${donorId}::uuid, ${personaId}::uuid, ${causeId}::uuid
    ) as code
  `);
  if (result?.code === "denied") return privateJson(result, 403);
  if (result?.code === "matched") return privateJson(result, 201);
  if (result?.code === "already_matched" || result?.code === "unavailable")
    return privateJson(result, 409);
  return invalid();
}
