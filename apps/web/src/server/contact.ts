import { sql } from "drizzle-orm";
import { parseInstituteContact } from "@/institutes/contact";
import type { LocalizedPageText } from "@/institutes/site-pages";
import { privateJson } from "./staff-invitations";
import type { AuthQuery } from "./workspace-access";

export async function readPublishedInstituteContact(tx: AuthQuery) {
  const {
    rows: [institute],
  } = await tx.execute<{
    address: LocalizedPageText;
    contact: Record<string, unknown>;
  }>(sql`select address::jsonb, contact from public_api.institute_public`);
  return privateJson(
    institute
      ? parseInstituteContact(institute.address, institute.contact)
      : null,
  );
}
