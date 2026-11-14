import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { expect, it } from "vitest";

const physical =
  /(?:^|[^-.\w])(?:margin|padding|border(?:-width|-style|-color)?)-(?:left|right)\b|(?:^|[{;\s])(?:left|right)\s*:|text-align\s*:\s*(?:left|right)\b|float\s*:\s*(?:left|right)\b/;

async function cssFiles(dir: string): Promise<string[]> {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = await Promise.all(
    entries.map((entry) => {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) return cssFiles(full);
      return entry.name.endsWith(".css") ? [full] : [];
    }),
  );
  return files.flat();
}

it("keeps layout CSS on logical properties so Urdu mirrors without a second sheet", async () => {
  const root = path.join(process.cwd(), "apps/web/src");
  const files = await cssFiles(root);
  const hits: string[] = [];
  for (const file of files) {
    const source = await readFile(file, "utf8");
    source.split("\n").forEach((line, index) => {
      if (physical.test(line))
        hits.push(`${path.relative(root, file)}:${index + 1}`);
    });
  }
  expect(hits).toEqual([]);
});
