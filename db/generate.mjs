import { spawnSync } from "node:child_process";
import { readFile, readdir, writeFile } from "node:fs/promises";

const directory = new URL("./drizzle/", import.meta.url);
const existing = new Set(await readdir(directory));
const result = spawnSync(
  "drizzle-kit",
  ["generate", ...process.argv.slice(2)],
  {
    stdio: "inherit",
  },
);
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);

for (const name of await readdir(directory)) {
  if (!name.endsWith(".sql") || existing.has(name)) continue;
  const file = new URL(name, directory);
  const contents = (await readFile(file, "utf8")).trim();
  // Drizzle writes its journal as the connection login. App DDL runs as the owner.
  await writeFile(
    file,
    `SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
${contents}
--> statement-breakpoint
RESET ROLE;
`,
  );
}
