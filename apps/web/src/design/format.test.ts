import { expect, it } from "vitest";
import {
  formatAmount,
  formatDate,
  formatDateTime,
  formatRelative,
  percentOf,
} from "./format";

it("reports how much of a target has been raised", () => {
  expect(percentOf(50n, 0n)).toBe(0);
  expect(percentOf(62n, 100n)).toBe(62);
  expect(percentOf(150n, 100n)).toBe(150);
});

it("formats rupees in both languages with Western digits", () => {
  expect(formatAmount(2_500_000n, "en")).toBe("Rs 25,000");
  expect(formatAmount(2_500_000n, "ur")).toBe("25,000 روپے");
  expect(formatAmount(660_000_000n, "en")).toBe("Rs 6,600,000");
  expect(formatAmount(660_000_000n, "ur")).toBe("6,600,000 روپے");
  expect(formatAmount(150n, "en")).toBe("Rs 1.50");
  expect(formatAmount(-500_000n, "ur")).toBe("−5,000 روپے");
  expect(formatAmount(0n, "en")).toBe("Rs 0");
});

it("formats calendar dates without locale-dependent month names", () => {
  expect(formatDate("2026-11-12", "en")).toBe("12 Nov 2026");
  expect(formatDate("2026-11-12", "ur")).toBe("12 نومبر 2026");
  expect(formatDate("2026-11-12T15:40:00.000Z", "en")).toBe("12 Nov 2026");
});

it("formats a date and time for trail rows", () => {
  expect(formatDateTime("2026-11-12T15:40:00.000Z", "en")).toBe(
    "12 Nov 2026, 3:40 pm",
  );
  expect(formatDateTime("2026-11-12T15:40:00.000Z", "ur")).toBe(
    "12 نومبر 2026، 3:40 بعد دوپہر",
  );
  expect(formatDateTime("2026-11-12T03:05:00.000Z", "en")).toBe(
    "12 Nov 2026, 3:05 am",
  );
});

it("uses a short relative phrase, then a calendar date", () => {
  const now = Date.parse("2026-11-12T15:40:00.000Z");
  expect(formatRelative("2026-11-12T13:40:00.000Z", "en", now)).toBe(
    "2 hours ago",
  );
  expect(formatRelative("2026-11-12T13:40:00.000Z", "ur", now)).toBe(
    "2 گھنٹے پہلے",
  );
  expect(formatRelative("2026-10-01T13:40:00.000Z", "en", now)).toBe(
    "1 Oct 2026",
  );
});
