import { describe, expect, it } from "vitest";
import { parseDonationRupees } from "./donation-amount";

describe("parseDonationRupees", () => {
  it("accepts a whole rupee amount and stores paisa", () => {
    expect(parseDonationRupees("500")).toBe(50_000n);
    expect(parseDonationRupees("1,000")).toBe(100_000n);
  });

  it("refuses empty, decimal, zero and oversized amounts", () => {
    expect(parseDonationRupees("")).toBeNull();
    expect(parseDonationRupees("0")).toBeNull();
    expect(parseDonationRupees("12.50")).toBeNull();
    expect(parseDonationRupees("10000000000000")).toBeNull();
  });
});
