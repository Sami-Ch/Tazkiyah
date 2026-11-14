import english from "@tazkiyah/i18n/messages/en/common.json";
import urdu from "@tazkiyah/i18n/messages/ur/common.json";
import { expect, it } from "vitest";
import { samplePublicCopy, showSampleBadge } from "./public-story";

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
      const text = String(read(english, key));
      const urduText = String(read(urdu, key));
      expect(text).not.toMatch(/sample wording|not a real person|replace it when/i);
      expect(urduText).not.toMatch(/نمونہ عبارت|کوئی حقیقی شخص نہیں|نمونہ:/);
    }
  }
});

it("shows the sample badge in preview and hides it in production", () => {
  expect(showSampleBadge({ NODE_ENV: "development" })).toBe(true);
  expect(showSampleBadge({ NODE_ENV: "production" })).toBe(false);
  expect(
    showSampleBadge({ NODE_ENV: "production", TAZKIYAH_CONTENT_MODE: "preview" }),
  ).toBe(true);
  expect(
    showSampleBadge({
      NODE_ENV: "development",
      TAZKIYAH_CONTENT_MODE: "production",
    }),
  ).toBe(false);
});
