import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  can,
  permissionMatrix,
  roles,
  type Action,
  type Fact,
  type Role,
} from "./permissions";

// How each cell wording in 05 §7 maps to grants. An unknown wording fails the
// test, so a new kind of cell is decided here before it reaches the code.
const cellGrants: Record<string, Fact[][]> = {
  "—": [],
  "— ¹": [],
  yes: [[]],
  "yes ²": [[]],
  "yes (as guest)": [[]],
  "yes (sign-up)": [[]],
  "yes (becomes its teacher)": [[]],
  "principal, admin": [[]],
  own: [["own"]],
  "the verifying teacher": [["own"]],
  "own classes": [["classMember"]],
  class: [["classTeacher"]],
  "class teacher": [["classTeacher"]],
  "class teacher (student posts)": [["classTeacher", "studentPost"]],
  "class and madrasa items": [["classTeacher"], ["madrasaPost"]],
  link: [["link"]],
  "link (request)": [["link"]],
  "yes (when recording)": [["recording"]],
  "at recording, as the donor asked": [["recording"]],
  principal: [["principal"]],
  assigned: [["assignedSigner"]],
  widener: [["widener"]],
  sponsor: [["sponsor"]],
  "sponsor (own match)": [["sponsor"]],
  "sponsor, only while consent is active": [["sponsor", "consentActive"]],
  "public posts": [["publicPost"]],
  "teacher work": [["teacherWork"]],
  "teacher work items": [["teacherWork"]],
};

function planRows() {
  const plan = readFileSync(
    new URL("../../../plan/05-public-pages-roles-admin.md", import.meta.url),
    "utf8",
  );
  const section = plan.slice(
    plan.indexOf("## 7. Permission matrix"),
    plan.indexOf("## 8. Admin screens"),
  );
  return section
    .split("\n")
    .filter((line) => line.startsWith("| ") && !line.startsWith("| Action"))
    .filter((line) => !line.startsWith("| ---"))
    .map((line) => line.slice(2, -2).split(" | "));
}

describe("the shared permission matrix", () => {
  const rows = planRows();
  const byLabel = new Map<string, Action>(
    Object.entries(permissionMatrix).map(([action, rule]) => [
      rule.label,
      action as Action,
    ]),
  );

  it("has one action for every row of 05 §7 and no others", () => {
    expect(rows.map(([label]) => label).sort()).toEqual(
      [...byLabel.keys()].sort(),
    );
  });

  it.each(rows)("matches 05 §7 for “%s”", (label, ...cells) => {
    const action = byLabel.get(label)!;
    const grants = permissionMatrix[action].grants as Partial<
      Record<Role, readonly Fact[][]>
    >;
    expect(cells).toHaveLength(roles.length);
    roles.forEach((role, index) => {
      const expected = cellGrants[cells[index]];
      expect(expected, `Unknown cell wording "${cells[index]}"`).toBeDefined();
      expect(grants[role] ?? [], `${label} for ${role}`).toEqual(expected);
    });
  });
});

describe("can()", () => {
  const as = (...held: Role[]) => ({ roles: held });

  it("denies actions that are not in the matrix", () => {
    expect(can(as("admin"), "audit_log.delete" as Action)).toBe(false);
    expect(can(as("admin"), "toString" as Action)).toBe(false);
    expect(can(as("admin"), "audit_log.change")).toBe(false);
  });

  it("gives every signed-in person the visitor's rights", () => {
    expect(can(as("teacher"), "donation.give")).toBe(true);
    expect(can(as(), "donor_wall.view")).toBe(true);
    expect(can(as(), "trail.view")).toBe(false);
    expect(can(as(), "trail.view", ["link"])).toBe(true);
  });

  it("ignores role names that are not in the matrix", () => {
    expect(can({ roles: ["guardian" as Role] }, "orphan.view_persona")).toBe(
      false,
    );
    expect(can({ roles: ["guardian" as Role] }, "donor_wall.view")).toBe(true);
  });

  it("lets a donor act only on their own records", () => {
    expect(can(as("donor"), "trail.make_public")).toBe(false);
    expect(can(as("donor"), "trail.make_public", ["own"])).toBe(true);
    expect(can(as("donor"), "donation.record")).toBe(false);
  });

  it("limits a student to own classes and own persona", () => {
    expect(can(as("student"), "post.read_class")).toBe(false);
    expect(can(as("student"), "post.read_class", ["classMember"])).toBe(true);
    expect(can(as("student"), "post.read_class", ["classTeacher"])).toBe(false);
    expect(can(as("student"), "persona.edit_own", ["own"])).toBe(true);
    expect(can(as("student"), "persona.trace", ["own"])).toBe(false);
  });

  it("limits a teacher's class rights to classes they teach", () => {
    expect(can(as("teacher"), "persona.trace")).toBe(false);
    expect(can(as("teacher"), "persona.trace", ["classTeacher"])).toBe(true);
    expect(can(as("teacher"), "post.widen_scope")).toBe(false);
    expect(
      can({ roles: ["teacher"], facts: ["widener"] }, "post.widen_scope"),
    ).toBe(true);
    expect(can(as("teacher"), "post.restore", ["classTeacher"])).toBe(false);
    expect(
      can(as("teacher"), "post.restore", ["classTeacher", "studentPost"]),
    ).toBe(true);
    expect(can(as("teacher"), "moderation_queue.view", ["madrasaPost"])).toBe(
      true,
    );
  });

  it("keeps editors and finance officers away from persona links", () => {
    expect(can(as("editor"), "persona.trace", ["classTeacher"])).toBe(false);
    expect(can(as("finance_officer"), "persona.trace", ["classTeacher"])).toBe(
      false,
    );
    expect(can(as("editor"), "site_pages.edit")).toBe(true);
    expect(can(as("editor"), "cause.manage")).toBe(false);
  });

  it("lets a finance officer handle money but not causes or staff", () => {
    expect(can(as("finance_officer"), "donation.record")).toBe(true);
    expect(can(as("finance_officer"), "cause.manage")).toBe(false);
    expect(can(as("finance_officer"), "staff.manage")).toBe(false);
    expect(can(as("finance_officer"), "donation.choose_name_display")).toBe(
      false,
    );
    expect(
      can(as("finance_officer"), "donation.choose_name_display", ["recording"]),
    ).toBe(true);
  });

  it("never lets staff make a donation more public for the donor", () => {
    for (const role of roles.filter((r) => r !== "visitor" && r !== "donor")) {
      expect(can(as(role), "donation.make_named")).toBe(false);
      expect(can(as(role), "trail.make_public")).toBe(false);
    }
    expect(can(as("admin"), "donation.make_anonymous")).toBe(true);
  });

  it("reserves the principal's sign-offs for the principal", () => {
    expect(can(as("admin"), "consent.first_sign_off")).toBe(false);
    expect(
      can({ roles: ["admin"], facts: ["principal"] }, "consent.first_sign_off"),
    ).toBe(true);
    expect(can(as("teacher"), "consent.second_sign_off")).toBe(false);
    expect(
      can(as("teacher"), "consent.second_sign_off", ["assignedSigner"]),
    ).toBe(true);
  });

  it("shows a sponsor the full profile only while consent is active", () => {
    expect(can(as("donor"), "orphan.view_full_profile", ["sponsor"])).toBe(
      false,
    );
    expect(
      can(as("donor"), "orphan.view_full_profile", [
        "sponsor",
        "consentActive",
      ]),
    ).toBe(true);
  });

  it("gives several roles the union of their rights", () => {
    expect(can(as("teacher", "editor"), "site_pages.edit")).toBe(true);
    expect(can(as("teacher", "editor"), "class.create")).toBe(true);
  });
});
