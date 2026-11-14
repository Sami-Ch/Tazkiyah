import { expect, it } from "vitest";
import { listWindow, nextPageHref } from "./paging";

it("keeps public lists on 20-row steps", () => {
  expect(listWindow(null)).toEqual({ take: 20, next: 40 });
  expect(listWindow("40")).toEqual({ take: 40, next: 60 });
  expect(listWindow("15")).toEqual({ take: 20, next: 40 });
  expect(listWindow("220")).toEqual({ take: 20, next: 40 });
  expect(listWindow("200")).toEqual({ take: 200, next: 220 });
});

it("builds a show-more link that keeps the current filters", () => {
  expect(
    nextPageHref("/en/donor-wall", { cause: "wheat-stock", shown: "20" }, 40),
  ).toBe("/en/donor-wall?cause=wheat-stock&shown=40");
});
