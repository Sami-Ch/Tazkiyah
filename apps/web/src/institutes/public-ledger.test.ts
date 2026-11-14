import { nightAndPaper } from "@tazkiyah/core/theme";
import { expect, it } from "vitest";
import { causeMoney, donorWallEntry, themeFromSettings } from "./public-ledger";

it("keeps a saved theme only when every contrast pair passes", () => {
  expect(themeFromSettings(nightAndPaper)).toBe(nightAndPaper);
  expect(themeFromSettings({ color: { bg: "#ffffff" } })).toEqual(
    nightAndPaper,
  );
});

it("drops a cause row that is not a public cause", () => {
  expect(
    causeMoney({ id: "1", slug: "wheat", cause_type: "draft" }),
  ).toBeUndefined();
  expect(
    causeMoney({
      id: "1",
      slug: "wheat-stock",
      cause_type: "yearly_stock",
      title: { en: "Wheat stock", ur: "گندم" },
      status: "active",
      target_paisa: "10000",
      raised_paisa: "5000",
      lifetime_raised_paisa: "5000",
      spent_paisa: "2000",
      unspent_paisa: "3000",
      accepts_zakat: true,
      ends_on: null,
    })?.spent_paisa,
  ).toBe("2000");
});

it("never keeps a donor name on an anonymous wall row", () => {
  const entry = donorWallEntry({
    public_ref: "k7Qm2xPa",
    amount_paisa: "2500000",
    given_on: "2026-11-12",
    donor_label: null,
    cause_slug: "wheat-stock",
    cause_title: { en: "Wheat stock" },
  });
  expect(entry?.donor_label).toBeNull();
  expect(entry?.profile_ref).toBeNull();
  expect(entry?.trail_public).toBe(false);
  expect(entry && "donor_id" in entry).toBe(false);
});

it("links a named wall row only to a public profile and a public trail", () => {
  const named = donorWallEntry({
    public_ref: "abcdefghij",
    amount_paisa: "100",
    given_on: "2026-11-01",
    donor_label: "Sample",
    profile_ref: "klmnopqrst",
    trail_public: true,
  });
  expect(named?.profile_ref).toBe("klmnopqrst");
  expect(named?.trail_public).toBe(true);
  const unlabeled = donorWallEntry({
    public_ref: "abcdefghij",
    amount_paisa: "100",
    given_on: "2026-11-01",
    donor_label: "  ",
    profile_ref: "klmnopqrst",
    trail_public: true,
  });
  expect(unlabeled?.profile_ref).toBeNull();
});
