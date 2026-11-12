import { readFileSync, readdirSync } from "node:fs";
import { PGlite } from "@electric-sql/pglite";
import { readMigrationFiles } from "drizzle-orm/migrator";
import { beforeAll, expect, it } from "vitest";

// Runs the migration history and every SQL suite in an in-process Postgres.
// CI repeats the same suites on a short-lived Neon branch (03 §5.3).
const folder = new URL("./", import.meta.url);
const suites = readdirSync(folder)
  .filter((file) => file.endsWith(".sql"))
  .sort();
const db = new PGlite();

beforeAll(async () => {
  for (const migration of readMigrationFiles({
    migrationsFolder: new URL("../drizzle/", import.meta.url).pathname,
  })) {
    await db.exec(`begin;\n${migration.sql.join("\n")}\ncommit;`);
  }
  await db.exec(
    readFileSync(
      new URL("../seed/markaz_al_azeem.sql", import.meta.url),
      "utf8",
    ),
  );
}, 60_000);

it("finds the SQL suites", () => {
  expect(suites).toContain("isolation_harness.sql");
});

it.each(suites)(
  "passes %s",
  async (suite) => {
    try {
      await db.exec(readFileSync(new URL(suite, folder), "utf8"));
    } finally {
      await db.exec("rollback");
    }
  },
  60_000,
);
