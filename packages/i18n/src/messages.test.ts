import { readdirSync, readFileSync } from "node:fs";
import { expect, it } from "vitest";

type Messages = { [key: string]: string | Messages };

function messageKeys(messages: Messages): string[] {
  return Object.entries(messages).flatMap(([key, value]) =>
    typeof value === "string"
      ? [key]
      : messageKeys(value).map((childKey) => `${key}.${childKey}`),
  );
}

const root = new URL("../messages/", import.meta.url);
const catalogues = readdirSync(new URL("en/", root))
  .filter((file) => file.endsWith(".json"))
  .sort();

it("provides the same catalogue files in English and Urdu", () => {
  expect(
    readdirSync(new URL("ur/", root))
      .filter((file) => file.endsWith(".json"))
      .sort(),
  ).toEqual(catalogues);
  expect(catalogues).toEqual([
    "causes.json",
    "common.json",
    "donate.json",
    "hub.json",
    "sponsor.json",
    "trail.json",
  ]);
});

it.each(catalogues)(
  "provides the same interface message keys in %s",
  (file) => {
    const english = JSON.parse(
      readFileSync(new URL(`en/${file}`, root), "utf8"),
    ) as Messages;
    const urdu = JSON.parse(
      readFileSync(new URL(`ur/${file}`, root), "utf8"),
    ) as Messages;
    expect(messageKeys(urdu).sort()).toEqual(messageKeys(english).sort());
  },
);
