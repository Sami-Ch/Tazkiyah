import { expect, it } from "vitest";
import {
  staffLinkIsCurrent,
  staffLinks,
  type StaffLinkAccess,
} from "./staff-links";

const none: StaffLinkAccess = {
  canRecordTransfers: false,
  canReconcileTransfers: false,
  canRecordSpending: false,
  canInvite: false,
  canEditPages: false,
  canManageClasses: false,
  canModerate: false,
  canMatchSponsors: false,
  canRecordConsent: false,
  canPostUpdates: false,
};

function ids(access: Partial<StaffLinkAccess>) {
  return staffLinks("ur", { ...none, ...access }).map((link) => link.id);
}

it("gives a teacher the class list and keeps finance screens away", () => {
  expect(
    ids({
      canManageClasses: true,
      canModerate: true,
      canRecordConsent: true,
      canPostUpdates: true,
    }),
  ).toEqual(["home", "classes", "moderation", "consent", "progress"]);
});

it("gives a finance officer donations and the bank check", () => {
  expect(
    ids({
      canRecordTransfers: true,
      canReconcileTransfers: true,
      canRecordSpending: true,
    }),
  ).toEqual(["home", "donations", "reconciliation", "spending"]);
});

it("gives an editor site pages and the moderation queue", () => {
  expect(ids({ canEditPages: true, canModerate: true })).toEqual([
    "home",
    "pages",
    "moderation",
  ]);
});

it("gives an admin the screens that exist in the workspace", () => {
  expect(
    ids({
      canRecordTransfers: true,
      canReconcileTransfers: true,
      canRecordSpending: true,
      canInvite: true,
      canEditPages: true,
      canManageClasses: true,
      canModerate: true,
      canMatchSponsors: true,
      canRecordConsent: true,
      canPostUpdates: true,
    }),
  ).toEqual([
    "home",
    "donations",
    "reconciliation",
    "spending",
    "causes",
    "banks",
    "users",
    "audit",
    "donorLinks",
    "pages",
    "classes",
    "moderation",
    "consent",
    "progress",
    "sponsorships",
  ]);
});

it("marks only the workspace root, not every admin path, as the home link", () => {
  expect(staffLinkIsCurrent("/ur/admin", "/ur/admin")).toBe(true);
  expect(staffLinkIsCurrent("/ur/admin/donations", "/ur/admin")).toBe(false);
  expect(
    staffLinkIsCurrent(
      "/en/admin/donations/reconciliation",
      "/en/admin/donations",
    ),
  ).toBe(true);
});
