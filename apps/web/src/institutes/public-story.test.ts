import english from "@tazkiyah/i18n/messages/en/common.json";
import urdu from "@tazkiyah/i18n/messages/ur/common.json";
import { expect, it } from "vitest";
import { samplePublicCopy } from "./public-story";

function read(source: unknown, path: string) {
  return path.split(".").reduce<unknown>((value, key) => {
    if (!value || typeof value !== "object") return undefined;
    return (value as Record<string, unknown>)[key];
  }, source);
}

it("keeps every sample public line in both languages", () => {
  for (const item of samplePublicCopy) {
    for (const key of item.keys) {
      expect(typeof read(english, key), key).toBe("string");
      expect(typeof read(urdu, key), key).toBe("string");
      expect(read(english, key)).not.toBe(read(urdu, key));
    }
  }
});
