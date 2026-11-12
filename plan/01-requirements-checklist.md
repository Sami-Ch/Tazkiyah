# Requirements checklist

Every requirement is one testable sentence. Each line ends with its priority (`MUST`, `SHOULD` or `LATER`) and the document and section that explain it. Section numbers follow the required headings in [00 §2](00-MASTER-PLAN.md#required-sections-in-specialist-documents).

Tick a line only when its task is `done` and its test passes. Add a missing requirement as `- [ ] REQ-... (proposed)` with an open question in [00 §6](00-MASTER-PLAN.md#open-questions), and do not build on it until it is approved.

## Donations

- [ ] REQ-DON-001 Donor can give to one specific cause. MUST → 06 §4
- [ ] REQ-DON-002 Donor can give to "all needs" instead of choosing a cause. MUST → 06 §7
- [ ] REQ-DON-003 Donor can choose one-off, monthly or yearly when giving. MUST → 06 §13
- [ ] REQ-DON-004 Every donation records its type as Zakat, Sadaqah or general. MUST → 06 §6
- [ ] REQ-DON-005 Every cause has a type of campaign, ongoing or yearly stock. MUST → 06 §5
- [ ] REQ-DON-006 A campaign stops accepting donations after its end date. MUST → 06 §5
- [ ] REQ-DON-007 Admin can set a target amount for each cause. MUST → 06 §5
- [x] REQ-DON-008 Admin can record a bank-transfer donation with amount, date, donor, cause or all needs, type and bank reference. MUST → 06 §4
- [ ] REQ-DON-009 Admin can create, edit, close and archive causes with Urdu and English text. MUST → 05 §8
- [ ] REQ-DON-010 Every recorded donation gets a unique receipt number. MUST → 06 §14
- [ ] REQ-DON-011 Donor receives an emailed receipt in their chosen language when a donation is recorded. SHOULD → 06 §14
- [ ] REQ-DON-012 Admin can reverse a recorded donation with a reason, and the original record stays. MUST → 06 §15
- [ ] REQ-DON-013 Future tech costs can be created as causes in the same way as any other cause. SHOULD → 05 §10
- [x] REQ-DON-014 The clinic appears only as a cause and stores no patient data. MUST → 06 §5

## Trail

- [ ] REQ-TRL-001 Every donation has trail events of received, allocated, spent and reported. MUST → 06 §8
- [ ] REQ-TRL-002 Trail events are append-only and are never edited or deleted. MUST → 04 §9
- [ ] REQ-TRL-003 A correction is recorded as a new reversing event that points to the event it corrects. MUST → 04 §9
- [ ] REQ-TRL-004 A spending entry draws on the oldest unspent donations in its cause first. MUST → 06 §8
- [ ] REQ-TRL-005 One spending entry can draw on several donations, and one donation can be split across several spending entries. MUST → 06 §8
- [ ] REQ-TRL-006 Zakat money is matched only to spending in Zakat-eligible causes. MUST → 06 §6
- [ ] REQ-TRL-007 Donor can see, for each of their donations, which spending entries it paid for and how much. MUST → 06 §8
- [ ] REQ-TRL-008 A donation's trail is private by default. MUST → 06 §10
- [ ] REQ-TRL-009 Donor can make the trail of a donation public. MUST → 06 §10
- [ ] REQ-TRL-010 Each cause page shows aggregated spending without any donor identity. MUST → 05 §5
- [ ] REQ-TRL-011 A spending entry records amount, date, description and an optional receipt or photo. MUST → 06 §9
- [ ] REQ-TRL-012 Admin can publish a daily or weekly report that groups spending entries. SHOULD → 06 §9
- [ ] REQ-TRL-013 Admin can see the unspent balance of each cause. MUST → 06 §9
- [x] REQ-TRL-014 The allocation model can record a future transfer from a platform fund to an institute without a schema change. MUST → 04 §9

## Donor profiles

- [ ] REQ-DPR-001 Donor can give as a guest by entering only an email address. MUST → 06 §11
- [ ] REQ-DPR-002 A guest donor receives a private link to their trail. MUST → 06 §11
- [ ] REQ-DPR-003 A guest donor can create an account later and claim past donations made with the same email. SHOULD → 06 §11
- [ ] REQ-DPR-004 Donor can create an account and log in with email. MUST → 03 §6
- [ ] REQ-DPR-005 Donor can set a public profile with a display name, photo and links to profiles elsewhere. SHOULD → 06 §10
- [ ] REQ-DPR-006 Each donation can show the donor's name or be anonymous, set separately from the profile. MUST → 06 §10
- [ ] REQ-DPR-007 The donor wall shows the amount and cause of every donation. MUST → 06 §10
- [ ] REQ-DPR-008 The donor wall shows "Anonymous" for every donation set to anonymous. MUST → 06 §10
- [ ] REQ-DPR-009 An anonymous donation never reveals the donor's name in pages, exports, logs, emails or API responses. MUST → 06 §10
- [ ] REQ-DPR-010 Donor can view all their past donations and receipts. MUST → 06 §10

## Orphan sponsorship

- [ ] REQ-ORP-001 Admin can match a sponsor to one orphan. MUST → 06 §12
- [ ] REQ-ORP-002 By default, a sponsor sees only the orphan's persona name, age and progress updates. MUST → 06 §12
- [ ] REQ-ORP-003 A sponsor sees the orphan's full profile only after guardian consent with two sign-offs. MUST → 06 §12
- [ ] REQ-ORP-004 The principal can assign the second sign-off to any teacher. MUST → 06 §12
- [ ] REQ-ORP-005 A full profile is visible only to the matched sponsor and never on public pages. MUST → 06 §12
- [ ] REQ-ORP-006 Withdrawing consent hides the full profile from the sponsor at once. MUST → 06 §12
- [ ] REQ-ORP-007 A sponsor can message the madrasa about the child, and there is no direct sponsor-to-child contact. MUST → 06 §12
- [ ] REQ-ORP-008 Admin or a teacher can post a progress update for a sponsored orphan. SHOULD → 06 §12
- [ ] REQ-ORP-009 Sponsorship donations follow the same trail rules as other donations. MUST → 06 §12

## Student hub

- [ ] REQ-STU-001 Students cannot sign up themselves, and only a teacher or admin can create a student account. MUST → 07 §4
- [ ] REQ-STU-002 A student can personalise their persona's display name, avatar and short bio after first login. MUST → 07 §4
- [ ] REQ-STU-003 Every student has an anonymous persona that is shown instead of their real name by default. MUST → 07 §4
- [ ] REQ-STU-004 A student's real name is shown only when the student chooses it and consent is on record. SHOULD → 07 §5
- [ ] REQ-STU-005 Students can create posts of type message, question, answer, poll, article, video, vlog, audio and slides. MUST → 07 §6
- [ ] REQ-STU-006 Students can reply in threads. MUST → 07 §6
- [ ] REQ-STU-007 Students and teachers can create polls, and students can vote in them. MUST → 07 §6
- [ ] REQ-STU-008 Every post has a scope of class or madrasa when created. MUST → 07 §7
- [ ] REQ-STU-009 A student's account and persona stay active after they leave the madrasa. MUST → 07 §4
- [ ] REQ-STU-010 Students see a guided walkthrough on first login. MUST → 02 §13
- [ ] REQ-STU-011 Students can report a post. MUST → 07 §8

## Teacher hub

- [ ] REQ-TCH-001 Teachers can publish articles, lessons, audio, video and resources under their real name with a short profile. MUST → 07 §10
- [ ] REQ-TCH-002 A teacher can turn a thread into a verified article. MUST → 07 §9
- [ ] REQ-TCH-003 A verified article shows a verified mark and the verifying teacher's name. MUST → 07 §9
- [ ] REQ-TCH-004 Teacher work goes through editor or admin review before it becomes public. MUST → 07 §10
- [ ] REQ-TCH-005 Teachers can create classes and add students to them. MUST → 07 §4
- [ ] REQ-TCH-006 Teachers can see the real student behind each persona in their classes. MUST → 07 §4

## Public pages

- [ ] REQ-PUB-001 The site has about, facilities, daily life, causes, new projects, donor wall, student work, teacher work and contact pages. MUST → 05 §4
- [ ] REQ-PUB-002 The home page shows active causes with their progress. MUST → 05 §5
- [ ] REQ-PUB-003 Each cause has a public page showing its target, amount raised, amount spent and spending entries. MUST → 05 §5
- [ ] REQ-PUB-004 The student work page shows only approved public posts, under personas. MUST → 05 §5
- [ ] REQ-PUB-005 The teacher work page shows approved teacher posts and verified articles. MUST → 05 §5
- [ ] REQ-PUB-006 The contact page shows the madrasa's address and contact details from institute settings. MUST → 05 §5
- [ ] REQ-PUB-007 Public pages show the logo and institute name from institute settings. MUST → 05 §5
- [ ] REQ-PUB-008 The donate page shows the institute's bank account details from institute settings. MUST → 05 §5

## Roles and admin

- [ ] REQ-ROL-001 The system has the roles visitor, donor, student, teacher, editor, finance officer and admin. MUST → 05 §6
- [ ] REQ-ROL-002 Every role's allowed actions are defined in one permission matrix. MUST → 05 §7
- [ ] REQ-ROL-003 There are no guardian logins. MUST → 05 §6
- [ ] REQ-ROL-004 Admin can create teacher, editor and finance officer accounts. MUST → 05 §8
- [x] REQ-ROL-005 Admin can set Zakat eligibility and an optional approving scholar's name for each cause. MUST → 06 §6
- [ ] REQ-ROL-006 Admin can split all-needs funds across causes. MUST → 06 §7
- [ ] REQ-ROL-007 Admin can record spending entries with receipts. MUST → 06 §9
- [ ] REQ-ROL-008 Every staff action that changes data is written to an audit log. MUST → 05 §9
- [ ] REQ-ROL-009 Admin can view and filter the audit log. MUST → 05 §9
- [ ] REQ-ROL-010 Admin can switch the student hub, teacher hub and new projects modules on or off. MUST → 05 §8

## Payments

- [x] REQ-PAY-001 Until online payments arrive, donations are recorded manually by admin from bank transfers. MUST → 06 §4
- [ ] REQ-PAY-002 The payment gateway is chosen with Sami before Phase 5 starts. MUST → 03 §11
- [ ] REQ-PAY-003 Card payments support one-off and automatic monthly or yearly donations. LATER → 06 §16
- [ ] REQ-PAY-004 JazzCash and Easypaisa support one-off donations. LATER → 06 §16
- [ ] REQ-PAY-005 Overseas donors see amounts in their own currency alongside rupees. LATER → 06 §16
- [ ] REQ-PAY-006 A gateway payment creates its received trail event without manual entry. LATER → 06 §15
- [ ] REQ-PAY-007 A one-off donor can opt in to a monthly reminder email. SHOULD → 06 §13
- [ ] REQ-PAY-008 Tax-deductible receipts are issued only after legal registration completes. LATER → 06 §14

## Security and privacy

- [ ] REQ-SEC-001 Every table has `institute_id` and row-level security policies that block reads and writes across institutes. MUST → 04 §6
- [ ] REQ-SEC-002 Automated tests show that one institute cannot read or change another institute's rows. MUST → 04 §6
- [ ] REQ-SEC-003 Admin and finance officer logins require two-factor authentication. SHOULD → 03 §6
- [ ] REQ-SEC-004 Guest trail links use unguessable tokens that admin can revoke. MUST → 04 §8
- [ ] REQ-SEC-005 Personal data is never placed in URLs or query strings. MUST → 03 §12
- [ ] REQ-SEC-006 The database is backed up daily, and a restore is tested once per phase. MUST → 03 §13
- [ ] REQ-SEC-007 Only the student's teachers and admins can read the link between a persona and a student. MUST → 04 §7
- [ ] REQ-SEC-008 Logs and error reports never contain anonymous donors' names or students' real names. MUST → 03 §13

## Child safety

- [ ] REQ-CHS-001 Students' real names and faces are hidden by default everywhere. MUST → 07 §12
- [ ] REQ-CHS-002 Posts containing phone numbers, email addresses or street addresses are blocked or flagged for a teacher. MUST → 07 §12
- [ ] REQ-CHS-003 Teachers can see every student-to-student post and reply in their classes. MUST → 07 §12
- [ ] REQ-CHS-004 Admin can take down any post immediately. MUST → 07 §8
- [ ] REQ-CHS-005 A parent consent record exists before any of a student's work becomes public. MUST → 07 §5
- [ ] REQ-CHS-006 Parent consent is recorded by staff on a light form, with no guardian account. MUST → 07 §5

## Performance

- [ ] REQ-PRF-001 Public pages show readable content within 5 seconds on a slow 3G connection (proposed target, D-026). SHOULD → 02 §9
- [ ] REQ-PRF-002 Images are served compressed and sized for the screen. MUST → 03 §8
- [ ] REQ-PRF-003 Upload sizes are capped for each media type to stay within free-tier limits. MUST → 03 §8
- [ ] REQ-PRF-004 Videos can be added as YouTube links or embeds instead of uploads. MUST → 07 §11
- [ ] REQ-PRF-005 The platform runs on the Cloudflare and Neon free tiers, with documented triggers for upgrading. MUST → 03 §14

## Accessibility

- [ ] REQ-ACC-001 Text and interface colours meet WCAG 2.1 AA contrast. MUST → 02 §10
- [ ] REQ-ACC-002 Every function works with a keyboard and a screen reader. SHOULD → 02 §10
- [ ] REQ-ACC-003 Images have alt text in the page's language. SHOULD → 02 §10
- [ ] REQ-ACC-004 Touch targets are at least 44 by 44 pixels. SHOULD → 02 §10
- [ ] REQ-ACC-005 Text can be enlarged to 200% without losing content. SHOULD → 02 §10

## Language

- [ ] REQ-LNG-001 All interface text is available in Urdu and English. MUST → 02 §8
- [ ] REQ-LNG-002 No interface text is hard-coded outside translation files. MUST → 03 §7
- [ ] REQ-LNG-003 Every page has a language switch. MUST → 02 §8
- [ ] REQ-LNG-004 The site remembers each user's language choice. MUST → 03 §7
- [ ] REQ-LNG-005 New visitors start in their browser's language, or in English if the browser sets none. MUST → 03 §7
- [ ] REQ-LNG-006 Urdu pages run right to left and English pages left to right, with the layout mirrored. MUST → 02 §8
- [ ] REQ-LNG-007 Mixed Urdu and English text, including numbers, displays in the correct order. MUST → 02 §8
- [ ] REQ-LNG-008 Each language has its own URL prefix, `/ur` and `/en`. MUST → 03 §7
- [ ] REQ-LNG-009 Fixed admin content has Urdu and English versions, and a missing version falls back to the other language with a notice. MUST → 03 §7
- [ ] REQ-LNG-010 Every community post records its language. MUST → 07 §6
- [ ] REQ-LNG-011 Emails and receipts are sent in the recipient's chosen language. MUST → 03 §10
- [ ] REQ-LNG-012 Amounts show in rupees and dates in each language's own format. MUST → 02 §8

## Moderation

- [ ] REQ-MOD-001 Class and madrasa posts appear immediately without approval. MUST → 07 §8
- [ ] REQ-MOD-002 Teachers and admins can hide or remove any class or madrasa post. MUST → 07 §8
- [ ] REQ-MOD-003 Making a post public needs approval from the class teacher or the principal. MUST → 07 §8
- [ ] REQ-MOD-004 A post going public moves through the states draft, submitted, approved, published and taken down. MUST → 07 §8
- [ ] REQ-MOD-005 Reported posts enter a moderation queue for teachers and admins. MUST → 07 §8
- [ ] REQ-MOD-006 A taken-down post disappears from public pages within one minute (proposed target, D-027). SHOULD → 07 §8
- [ ] REQ-MOD-007 Only admins or teachers chosen by the admin can widen a post's scope. MUST → 07 §7

## Multi-institute readiness

- [ ] REQ-MIR-001 Institute name, logo, theme colours, domain, contact details, bank details and enabled modules are stored as institute settings. MUST → 04 §5
- [ ] REQ-MIR-002 The request's domain selects the institute. MUST → 03 §4
- [x] REQ-MIR-003 Adding a second institute needs no schema change. MUST → 04 §5
- [ ] REQ-MIR-004 The post scope field can hold a future community value without a schema change. SHOULD → 04 §11
- [ ] REQ-MIR-005 Theme colours come from institute settings, not from code. MUST → 02 §5

## Proposed (awaiting approval)

Raised by the specialist documents and numbered in the consistency check. None of these may be built until Sami approves it (open question Q-08). Approving one means removing "(proposed)" and moving it to its category above.

- [ ] REQ-DON-015 (proposed) Donor can send a transfer notice with amount, transfer date, bank reference, email, cause or all needs, type and name choice, which the admin confirms against the bank. MUST → 06 §4
- [ ] REQ-DON-016 (proposed) Admin can record a cash donation, such as a Friday collection, with the method set to cash. SHOULD → 06 §4
- [ ] REQ-DON-017 (proposed) Admin can record a donation with no known donor, shown as anonymous and attachable to a donor later. SHOULD → 06 §4
- [ ] REQ-DON-018 (proposed) Every reminder or newsletter email has a one-click unsubscribe link that works without signing in. MUST → 03 §9
- [ ] REQ-TRL-015 (proposed) A cause cannot stop accepting Zakat while it holds unspent Zakat money. MUST → 06 §6
- [ ] REQ-TRL-016 (proposed) A spending entry larger than its cause's unspent money is recorded with a shortfall, which the next money into the cause fills first. MUST → 06 §8
- [ ] REQ-DPR-011 (proposed) Staff can make a donation anonymous or its trail private, but only the donor can make it named or public. MUST → 05 §7
- [ ] REQ-DPR-012 (proposed) A new donation is anonymous unless the donor chooses to show their name. MUST → 06 §10
- [ ] REQ-DPR-013 (proposed) On a verified request, a donor's personal details are erased while their donations and trail stay as anonymous records. SHOULD → 04 §13
- [ ] REQ-ORP-010 (proposed) Full-profile consent for a sponsor expires 12 months after its second sign-off unless both sign-offs are given again. SHOULD → 06 §12
- [ ] REQ-PUB-009 (proposed) The site has a privacy page in Urdu and English saying what is stored about donors, students and consent, and who can see it. SHOULD → 05 §5
- [ ] REQ-ROL-011 (proposed) No role, including admin, can edit or delete an audit log entry. MUST → 05 §9
- [ ] REQ-ROL-012 (proposed) Switching a module off hides its pages and menu items and leaves its data unchanged. MUST → 05 §8
- [ ] REQ-ROL-013 (proposed) The last active admin of an institute cannot remove their own admin role or deactivate their own account. SHOULD → 05 §6
- [ ] REQ-SEC-009 (proposed) Each time a staff member opens the real name behind a persona, the view is written to the audit log. SHOULD → 05 §9
- [ ] REQ-SEC-010 (proposed) Sign-in, password reset and two-factor attempts are rate-limited, and repeated failures lock the account for a short time. SHOULD → 03 §6
- [ ] REQ-SEC-011 (proposed) Donations, allocations, spending entries, trail events and the audit log are kept for at least 10 years. MUST → 04 §13
- [ ] REQ-CHS-007 (proposed) Every uploaded image, audio or video file has its location and camera details removed before it is stored. MUST → 07 §11
- [ ] REQ-CHS-008 (proposed) Withdrawing parent consent takes the student's public posts down and hides their real name and face within one minute. MUST → 07 §5
- [ ] REQ-CHS-009 (proposed) A student can raise a private concern that only their teachers and admins can see (Q-11). SHOULD → 07 §12
- [ ] REQ-CHS-010 (proposed) A persona's display name and bio are checked for phone numbers, email addresses, street addresses and full real names before saving. MUST → 07 §12
- [ ] REQ-MOD-008 (proposed) Visitors can report a published post on a public page without logging in. SHOULD → 07 §8
- [ ] REQ-MOD-009 (proposed) Media in a student's post is shown to other students only after a teacher checks it (Q-12). MUST → 07 §11
- [ ] REQ-ACC-006 (proposed) Theme colours that fail the WCAG AA contrast pairs cannot be saved in institute settings. MUST → 02 §5
- [ ] REQ-PRF-006 (proposed) Images below the first screen load only when scrolled into view, and only on tap when the browser asks to save data. SHOULD → 02 §9
