import { gardenAndClay, nightAndPaper } from "@tazkiyah/core/theme";
import { expect, it } from "vitest";
import { themeStyle } from "./theme-style";

it("writes Direction A tokens and the names existing pages already use", () => {
  const style = themeStyle(nightAndPaper);
  expect(style["--color-bg"]).toBe("#FAF8F3");
  expect(style["--color-primary"]).toBe("#0D254D");
  expect(style["--color-accent"]).toBe("#A9CCE8");
  expect(style["--color-focus"]).toBe("#C8691C");
  expect(style["--paper"]).toBe(style["--color-bg"]);
  expect(style["--navy"]).toBe(style["--color-primary"]);
  expect(style["--radius-md"]).toBe("8px");
});

it("keeps a second institute theme on the same token names", () => {
  const style = themeStyle(gardenAndClay);
  expect(style["--color-primary"]).toBe("#1F4D3A");
  expect(style["--navy"]).toBe("#1F4D3A");
  expect(style["--color-bg"]).toBe("#F7F5EE");
});
