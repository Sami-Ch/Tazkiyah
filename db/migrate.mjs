import { fileURLToPath } from "node:url";
import { readMigrationFiles } from "drizzle-orm/migrator";
import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import pg from "pg";

const connectionString = process.env.MIGRATION_DATABASE_URL;
if (!connectionString || !URL.canParse(connectionString)) {
  throw new Error(
    "Set MIGRATION_DATABASE_URL to the direct migration connection.",
  );
}

const { protocol, hostname, searchParams } = new URL(connectionString);
const host = searchParams.get("host") ?? hostname;
if (
  !["postgres:", "postgresql:"].includes(protocol) ||
  host.toLowerCase().split(".")[0].endsWith("-pooler")
) {
  throw new Error("Use a direct Postgres connection for migrations.");
}

const config = {
  migrationsFolder: fileURLToPath(new URL("./drizzle/", import.meta.url)),
};
const migrations = readMigrationFiles(config);
const baseline = migrations[0];
const baselineHash =
  "1863fabea18e8ffc2f3c00fa9914dfb1f15087e30a67c8fcb47077b0b2325120";
const legacyHistory = [
  "0001_common.sql 0091c90c6826c8b5af583c205a1b72ea293c7bb10f6cb0c9df3b5bf822ff521b",
  "0002_institutes.sql d53808ed3d59151584bc8bd4dca3743662c712d056d20b43806be89338952dbe",
  "0003_institute_access.sql 7e4f890a22d6895289c7290ea443e44dacd6a9237ffe4b7bb7fd6d0cdda64b01",
  "0004_users_and_roles.sql 07596f26f8960dd0cd371e00a9558b6ec9cb2da5176c16ca929f7c52f2fbe75b",
  "0005_media_and_pages.sql 03aa38c05c0df82ea662d9f2a7d2f90c44a8a3372f2f1ad1cc5378a1dbe7625d",
  "0006_staff_audit.sql cd93f159b0566e7cdcd27dd6922cdf1cfd0ccd5ac97d58ae8b99ef214650bce4",
];

if (baseline?.hash !== baselineHash) {
  throw new Error("The Drizzle baseline migration has changed.");
}
for (const [index, migration] of migrations.slice(1).entries()) {
  if (
    migration.folderMillis <= migrations[index].folderMillis ||
    migration.sql[0]?.trim() !== "SET LOCAL ROLE tazkiyah_schema_owner;" ||
    migration.sql.at(-1)?.trim() !== "RESET ROLE;"
  ) {
    throw new Error(
      `Invalid migration order or owner role at position ${index + 2}.`,
    );
  }
}

const client = new pg.Client({
  connectionString,
  connectionTimeoutMillis: 10_000,
});

try {
  await client.connect();
  // Hold the same lock the previous runner used, across Drizzle's transaction.
  await client.query("select pg_catalog.pg_advisory_lock(2090687064, 1)");
  const {
    rows: [history],
  } = await client.query(`
    select to_regclass('drizzle.__drizzle_migrations') as drizzle,
      to_regclass('tazkiyah_meta.migrations') as legacy
  `);
  const applied = history.drizzle
    ? (
        await client.query(
          "select hash, created_at from drizzle.__drizzle_migrations order by created_at",
        )
      ).rows
    : [];

  for (const [index, row] of applied.entries()) {
    const migration = migrations[index];
    if (
      migration?.hash !== row.hash ||
      migration.folderMillis !== Number(row.created_at)
    ) {
      throw new Error(
        `Drizzle migration history differs at position ${index + 1}.`,
      );
    }
  }

  if (history.legacy) {
    if (applied.length)
      throw new Error("Both migration histories have entries.");

    // Adopt the baseline only if all six original migrations ran verbatim.
    await client.query("begin");
    await client.query("set local role tazkiyah_schema_owner");
    const { rows: legacy } = await client.query(`
      select file || ' ' || checksum as entry
      from tazkiyah_meta.migrations order by file collate "C"
    `);
    if (
      legacy.length !== legacyHistory.length ||
      legacy.some(({ entry }, index) => entry !== legacyHistory[index])
    ) {
      throw new Error(
        "Legacy migration history does not match the Drizzle baseline.",
      );
    }

    await client.query("drop table tazkiyah_meta.migrations");
    await client.query("drop schema tazkiyah_meta");
    await client.query("reset role");
    await client.query("create schema if not exists drizzle");
    await client.query(`
      create table if not exists drizzle.__drizzle_migrations (
        id serial primary key,
        hash text not null,
        created_at bigint
      )
    `);
    await client.query(
      "insert into drizzle.__drizzle_migrations (hash, created_at) values ($1, $2)",
      [baseline.hash, baseline.folderMillis],
    );
    await client.query("commit");
    console.log(
      "Adopted the existing schema into the Drizzle migration history.",
    );
  }

  await migrate(drizzle({ client }), config);
  console.log("Drizzle migrations are up to date.");
} finally {
  await client.end();
}
