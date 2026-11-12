// The permission matrix of 05 §7, as one shared definition (REQ-ROL-002).
// permissions.test.ts checks every row and cell against the plan's tables.

export const roles = [
  "visitor",
  "donor",
  "student",
  "teacher",
  "editor",
  "finance_officer",
  "admin",
] as const;
export type Role = (typeof roles)[number];

/**
 * Facts about the user and the record that a grant can require. The caller
 * works them out from the database (class membership, markers, consent).
 */
export type Fact =
  | "own" // the user's own record
  | "link" // reached through a valid guest trail token
  | "classTeacher" // the user teaches the class the record belongs to
  | "classMember" // the user is a student in that class
  | "principal" // the user is the institute's principal (05 §6 markers)
  | "widener" // the user is a scope widener
  | "assignedSigner" // the user is the assigned second signer of this consent
  | "sponsor" // the user sponsors this child
  | "consentActive" // full-profile consent for this child is active
  | "recording" // the action happens while recording a donation
  | "publicPost" // the post is public
  | "madrasaPost" // the post has madrasa scope
  | "studentPost" // the post was written by a student
  | "teacherWork"; // the post is teacher work

/** One way a role may do an action: every listed fact must hold. */
type Grant = readonly Fact[];
type Rule = { label: string; grants: Partial<Record<Role, readonly Grant[]>> };

const yes: readonly Grant[] = [[]];
const only = (...facts: Fact[]): readonly Grant[] => [facts];

export const permissionMatrix = {
  // 7.1 Money
  "donation.give": {
    label: "Give and send a transfer notice",
    grants: { visitor: yes, donor: yes },
  },
  "donation.record": {
    label: "Record a bank-transfer donation",
    grants: { finance_officer: yes, admin: yes },
  },
  "transfer_notice.reconcile": {
    label: "Confirm or reject a transfer notice (reconcile)",
    grants: { finance_officer: yes, admin: yes },
  },
  "donation.reverse": {
    label: "Reverse a donation, with a reason",
    grants: { finance_officer: yes, admin: yes },
  },
  "donation.see_donor_identity": {
    label: "See the donor's name and email on a donation record",
    grants: { donor: only("own"), finance_officer: yes, admin: yes },
  },
  "donation.resend_receipt": {
    label: "Resend a receipt or trail link",
    grants: {
      visitor: only("link"),
      donor: only("own"),
      finance_officer: yes,
      admin: yes,
    },
  },
  "trail_link.revoke": {
    label: "Revoke a guest trail link",
    grants: { finance_officer: yes, admin: yes },
  },
  "cause.manage": {
    label: "Create a cause; set type, target, dates; close; archive",
    grants: { admin: yes },
  },
  "cause.edit_text": {
    label: "Edit cause text and photos",
    grants: { editor: yes, admin: yes },
  },
  "cause.preview_draft": {
    label: "Preview draft causes",
    grants: { editor: yes, finance_officer: yes, admin: yes },
  },
  "cause.set_zakat": {
    label: "Set `accepts_zakat` and the scholar name",
    grants: { admin: yes },
  },
  "all_needs.split": {
    label: "Split all-needs money across causes",
    grants: { admin: yes },
  },
  "spending.record": {
    label: "Record spending entries with receipts",
    grants: { finance_officer: yes, admin: yes },
  },
  "spending.reverse": {
    label: "Correct a spending entry with a reversing entry",
    grants: { finance_officer: yes, admin: yes },
  },
  "balance.view": {
    label: "See unspent balance per cause and fund type",
    grants: { finance_officer: yes, admin: yes },
  },
  "report.publish": {
    label: "Publish a daily or weekly report",
    grants: { finance_officer: yes, admin: yes },
  },
  "cause.view_public_totals": {
    label: "See public cause totals, spending and reports",
    grants: {
      visitor: yes,
      donor: yes,
      student: yes,
      teacher: yes,
      editor: yes,
      finance_officer: yes,
      admin: yes,
    },
  },

  // 7.2 Donor wall and trail visibility
  "donor_wall.view": {
    label: "View the donor wall",
    grants: {
      visitor: yes,
      donor: yes,
      student: yes,
      teacher: yes,
      editor: yes,
      finance_officer: yes,
      admin: yes,
    },
  },
  "donation.choose_name_display": {
    label: "Choose name or anonymous for a donation",
    grants: {
      visitor: only("link"),
      donor: only("own"),
      finance_officer: only("recording"),
      admin: only("recording"),
    },
  },
  "donation.make_anonymous": {
    label: "Switch a donation to anonymous",
    grants: {
      visitor: only("link"),
      donor: only("own"),
      finance_officer: yes,
      admin: yes,
    },
  },
  "donation.make_named": {
    label: "Switch a donation from anonymous to named",
    grants: { visitor: only("link"), donor: only("own") },
  },
  "trail.view": {
    label: "View a donation's trail",
    grants: {
      visitor: only("link"),
      donor: only("own"),
      finance_officer: yes,
      admin: yes,
    },
  },
  "trail.make_public": {
    label: "Make a trail public",
    grants: { visitor: only("link"), donor: only("own") },
  },
  "trail.make_private": {
    label: "Make a trail private",
    grants: {
      visitor: only("link"),
      donor: only("own"),
      finance_officer: yes,
      admin: yes,
    },
  },
  "donor_profile.set_up": {
    label: "Set up a public donor profile",
    grants: { donor: only("own") },
  },

  // 7.3 Sponsorship and consent
  "sponsorship.match": {
    label: "Match a sponsor to an orphan",
    grants: { admin: yes },
  },
  "orphan.view_persona": {
    label: "See the orphan's persona name, age and updates",
    grants: {
      donor: only("sponsor"),
      teacher: only("classTeacher"),
      admin: yes,
    },
  },
  "sponsorship_update.post": {
    label: "Post a progress update",
    grants: { teacher: only("classTeacher"), admin: yes },
  },
  "sponsor_message.send": {
    label: "Send a message to the madrasa about the child",
    grants: { donor: only("sponsor") },
  },
  "sponsor_message.reply": {
    label: "Read and reply to sponsor messages",
    grants: { admin: yes },
  },
  "orphan.view_full_profile": {
    label: "See the orphan's full profile",
    grants: {
      donor: only("sponsor", "consentActive"),
      teacher: only("classTeacher"),
      admin: yes,
    },
  },
  "consent.record": {
    label: "Record or edit a parent consent record",
    grants: { teacher: only("classTeacher"), admin: yes },
  },
  "consent.first_sign_off": {
    label: "Give the first sign-off on orphan consent",
    grants: { admin: only("principal") },
  },
  "consent.assign_second_signer": {
    label: "Assign the second sign-off to a teacher",
    grants: { admin: only("principal") },
  },
  "consent.second_sign_off": {
    label: "Give the second sign-off",
    grants: { teacher: only("assignedSigner") },
  },
  "consent.withdraw": {
    label: "Record a consent withdrawal (takes effect at once)",
    grants: { teacher: only("classTeacher"), admin: yes },
  },

  // 7.4 Accounts, classes and personas
  "donor_account.create": {
    label: "Create a donor account",
    grants: { visitor: yes, finance_officer: only("recording"), admin: yes },
  },
  "student_account.create": {
    label: "Create a student account",
    grants: { teacher: yes, admin: yes },
  },
  "staff.manage": {
    label:
      "Create teacher, editor and finance officer accounts; grant and remove roles",
    grants: { admin: yes },
  },
  "teacher.mark_widener": {
    label: "Mark a teacher as scope widener",
    grants: { admin: yes },
  },
  "account.set_active": {
    label: "Deactivate or reactivate an account",
    grants: { admin: yes },
  },
  "student.reset_password": {
    label: "Reset a student's password",
    grants: { teacher: only("classTeacher"), admin: yes },
  },
  "account.edit_own": {
    label: "Edit own name, language and password",
    grants: {
      donor: only("own"),
      student: only("own"),
      teacher: only("own"),
      editor: only("own"),
      finance_officer: only("own"),
      admin: only("own"),
    },
  },
  "class.create": {
    label: "Create a class",
    grants: { teacher: yes, admin: yes },
  },
  "class.manage_students": {
    label: "Add or remove students in a class",
    grants: { teacher: only("classTeacher"), admin: yes },
  },
  "class.manage_teachers": {
    label: "Add or remove teachers in a class",
    grants: { admin: yes },
  },
  "persona.edit_own": {
    label: "Set up and edit own persona",
    grants: { student: only("own") },
  },
  "persona.trace": {
    label: "See which student a persona belongs to",
    grants: { teacher: only("classTeacher"), admin: yes },
  },
  "persona.reset": {
    label: "Reset an unsuitable persona name or avatar",
    grants: { teacher: only("classTeacher"), admin: yes },
  },

  // 7.5 Posts, moderation and verified articles
  "post.read_class": {
    label: "Read class posts",
    grants: {
      student: only("classMember"),
      teacher: only("classTeacher"),
      admin: yes,
    },
  },
  "post.read_madrasa": {
    label: "Read madrasa posts",
    grants: { student: yes, teacher: yes, admin: yes },
  },
  "post.read_public": {
    label: "Read public posts",
    grants: {
      visitor: yes,
      donor: yes,
      student: yes,
      teacher: yes,
      editor: yes,
      finance_officer: yes,
      admin: yes,
    },
  },
  "post.create": {
    label: "Create a class or madrasa post, reply, vote",
    grants: { student: yes, teacher: yes, admin: yes },
  },
  "post.request_public": {
    label: "Ask for own post to go public",
    grants: { student: only("own"), teacher: only("own") },
  },
  "post.approve_student_public": {
    label: "Approve a student post for public view",
    grants: { teacher: only("classTeacher"), admin: yes },
  },
  "post.approve_teacher_work": {
    label: "Approve teacher work for public view",
    grants: { editor: yes, admin: yes },
  },
  "post.widen_scope": {
    label: "Widen a post's scope (class to madrasa)",
    grants: { teacher: only("widener"), admin: yes },
  },
  "post.report": {
    label: "Report a post",
    grants: {
      visitor: only("publicPost"),
      donor: only("publicPost"),
      student: yes,
      teacher: yes,
      editor: yes,
      finance_officer: yes,
      admin: yes,
    },
  },
  "post.hide": {
    label: "Hide or remove a class or madrasa post",
    grants: { teacher: yes, admin: yes },
  },
  "post.take_down": {
    label: "Take down a public post",
    grants: { teacher: yes, editor: yes, finance_officer: yes, admin: yes },
  },
  "post.restore": {
    label: "Restore a taken-down post",
    grants: {
      teacher: only("classTeacher", "studentPost"),
      editor: only("teacherWork"),
      admin: yes,
    },
  },
  "moderation_queue.view": {
    label: "See the moderation queue",
    grants: {
      teacher: [["classTeacher"], ["madrasaPost"]],
      editor: only("teacherWork"),
      admin: yes,
    },
  },
  "article.verify": {
    label: "Turn a thread into a verified article",
    grants: { teacher: yes, admin: yes },
  },
  "article.remove_verified": {
    label: "Remove a verified mark",
    grants: { teacher: only("own"), admin: yes },
  },

  // 7.6 Institute and system
  "modules.switch": {
    label: "Switch modules on or off",
    grants: { admin: yes },
  },
  "settings.edit": {
    label:
      "Edit institute settings (name, logo, contact, bank accounts, principal, batch mode)",
    grants: { admin: yes },
  },
  "site_pages.edit": {
    label: "Edit site page text and photos",
    grants: { editor: yes, admin: yes },
  },
  "audit_log.view": {
    label: "View and filter the audit log",
    grants: { admin: yes },
  },
  "audit_log.change": {
    label: "Edit or delete an audit log entry",
    grants: {},
  },
} as const satisfies Record<string, Rule>;

export type Action = keyof typeof permissionMatrix;

export type Actor = {
  /** Roles held in the current institute, from `user_roles`. */
  roles: readonly Role[];
  /** User markers from institute settings and role flags (05 §6). */
  facts?: readonly Fact[];
};

/**
 * Answers every permission question (03 §6.3). A user gets the union of their
 * roles, and everyone holds the visitor role. Anything not granted is denied.
 */
export function can(
  actor: Actor,
  action: Action,
  resource: readonly Fact[] = [],
): boolean {
  const rule: Rule | undefined = Object.hasOwn(permissionMatrix, action)
    ? permissionMatrix[action]
    : undefined;
  if (!rule) return false;
  const facts = new Set([...(actor.facts ?? []), ...resource]);
  return ["visitor" as const, ...actor.roles].some(
    (role) =>
      roles.includes(role) &&
      (rule.grants[role] ?? []).some((grant) =>
        grant.every((fact) => facts.has(fact)),
      ),
  );
}
