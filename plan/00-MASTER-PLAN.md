# Tazkiyah master plan

**Status:** plan complete, awaiting review · **Last updated:** 2026-11-07 · **Owner:** Sami

This is the source of truth for Tazkiyah. Every agent and developer reads it first. If two documents disagree, the master plan wins, and the specialist document is fixed.

## 1. Summary, goals and non-goals

Tazkiyah (تزکیہ) is a donation and community platform for Pakistani madrasas. The first and, for now, only institute is **Markaz Al Azeem** (مرکز العظیم), Jama Masjid Al-Azeem, 92/6-R Road, Sahiwal, at `azeem-lateef.com`. It has about 50 students, all under 18, including 5 orphans. It also has 8 staff, a free daily lunch for 100 people, a clinic seeing about 25 patients a day, and a running budget of roughly Rs 6.6 million a year. The principal, Moazam, is the main admin and the guardian of the orphans.

**Goals**

1. Raise donations with a trail that shows each donor exactly what their money paid for, matched first in, first out.
2. Give students a safe, simple community hub to post, ask, answer and share, under anonymous personas.
3. Give teachers a hub to publish, and to turn good discussions into verified articles.
4. Work fully in Urdu and English, on low-end phones and slow connections.
5. Build one madrasa's site so that more institutes can join later without a rebuild.

**Non-goals for this version**

Admissions, student fee collection, attendance, online classes, clinic patient records, institute signup, a super-admin area, billing, the central platform fund, and the cross-institute community. Only the foundations for the multi-institute features are built (see [01 Multi-institute readiness](01-requirements-checklist.md#multi-institute-readiness)).

## 2. Document map

| File | Owns |
| --- | --- |
| [00-MASTER-PLAN.md](00-MASTER-PLAN.md) | Goals, phases, epics, task registry, rules, risks, open questions, glossary |
| [01-requirements-checklist.md](01-requirements-checklist.md) | Every requirement as one testable line with priority and pointer |
| [02-design-ui-ux.md](02-design-ui-ux.md) | Visual direction, colour, type, components, RTL, mobile rules, UX flows, walkthrough |
| [03-architecture.md](03-architecture.md) | Stack, hosting, environments, auth, i18n plumbing, media, jobs, email, payments, security, backups |
| [04-database.md](04-database.md) | Entities, fields, RLS, trail storage, consent, content, audit data, migrations, retention |
| [05-public-pages-roles-admin.md](05-public-pages-roles-admin.md) | Sitemap, page specs, roles, permission matrix, admin screens, audit log screens, new projects page |
| [06-donations-and-trail.md](06-donations-and-trail.md) | Donation lifecycle, causes, Zakat, all-needs split, trail and FIFO, spending, donor identity, sponsorship, receipts |
| [07-content-hub-student-teacher.md](07-content-hub-student-teacher.md) | Accounts and personas, consent, threads, scopes, moderation, verified articles, media and child-safety rules |
| [08-decision-log.md](08-decision-log.md) | Every non-trivial decision with date, options and reason |
| [09-consistency-check.md](09-consistency-check.md) | The latest consistency check: coverage table, fixes made and items left for people |
| [../docs/agent-prompt.md](../docs/agent-prompt.md) | The brief this plan was written from |

**Rule:** if two documents disagree, the master plan wins, and the specialist document is fixed.

### Required sections in specialist documents

Every specialist document uses these headings, so checklist pointers such as `06 §8` always resolve. Sections 1 to 3 and the last three are the same in every document:

- §1 Purpose · §2 Scope and out of scope · §3 Decisions (each with its reason and a link to its `D-` entry in 08)
- Topic sections from §4, listed below
- Then, unnumbered: **Requirements covered**, **Tasks**, **Acceptance criteria**

| Doc | Topic sections |
| --- | --- |
| 02 | §4 Visual directions · §5 Colour · §6 Typography · §7 Layout, spacing and components · §8 RTL and bilingual layout · §9 Mobile and low-bandwidth · §10 Accessibility · §11 Tone of voice · §12 UX flows · §13 Onboarding walkthrough · §14 Media placeholders |
| 03 | §4 Stack and hosting · §5 Environments and deployment · §6 Authentication and sessions · §7 Localization plumbing · §8 Media storage · §9 Background jobs · §10 Email and SMS · §11 Payments integration · §12 Security · §13 Backups, logging and monitoring · §14 Free-tier limits and upgrade triggers |
| 04 | §4 Entity overview and ER diagram · §5 Institutes and settings · §6 Row-level security · §7 Users, roles and personas · §8 Causes, donations and donors · §9 Trail events and allocations · §10 Consent records · §11 Content · §12 Audit log · §13 Indexes, migrations and retention |
| 05 | §4 Sitemap · §5 Page specs · §6 Roles · §7 Permission matrix · §8 Admin screens · §9 Audit log · §10 New projects page |
| 06 | §4 Donation lifecycle · §5 Cause types · §6 Donation types and Zakat · §7 All-needs split · §8 Trail event model and FIFO · §9 Spending entries and reports · §10 Donor identity and donor wall · §11 Guest donors · §12 Orphan sponsorship · §13 Recurring giving and reminders · §14 Receipts · §15 Reconciliation, reversals and refunds · §16 Online payments (open) |
| 07 | §4 Accounts, classes and personas · §5 Consent · §6 Threads and post types · §7 Sharing scopes · §8 Moderation · §9 Verified articles · §10 Teacher hub · §11 Media rules · §12 Child safety |

## 3. Work hierarchy

Work is organised as **Phase → Epic → Task**.

- **Phase:** a stage that ends in something testable (section 5).
- **Epic:** a body of work inside a phase, owned by one specialist document. IDs look like `P2-E3`.
- **Task:** one working session of work inside an epic. IDs look like `P2-E3-T04`. Each task has an owner document, a status, dependencies and the requirement IDs it satisfies.

**Statuses:** `todo`, `in progress`, `blocked`, `done`.

The owner document of an epic writes that epic's tasks in its **Tasks** section, using this table format:

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P1-E3-T01 | Admin form to record a bank-transfer donation | todo | P0-E2-T03, P1-E2-T01 | REQ-DON-008, REQ-PAY-001 |

The **task index** in section 7 shows which document holds each epic's tasks. A task's status lives only in the document that holds its row. Tasks are numbered by document so IDs never clash: T01–T19 by the epic's owner, T20–T29 by 02, T30–T39 by 03, T40–T49 by 04, T50–T59 by 05, T60–T69 by 06 and T70–T79 by 07.

### Epics

| Epic | Title | Owner | Other docs involved |
| --- | --- | --- | --- |
| **P0** | **Foundations** | | |
| P0-E1 | Repo, environments and deployment to `azeem-lateef.com` | 03 | |
| P0-E2 | Database foundation: institutes, settings, RLS, migrations | 04 | 03 |
| P0-E3 | Localization plumbing: `/ur` and `/en`, translation files, RTL switching | 03 | 02 |
| P0-E4 | Design system: tokens, type, core components | 02 | |
| P0-E5 | Authentication, roles and permission checks | 03 | 05 |
| **P1** | **Public site and manual donations** | | |
| P1-E1 | Public pages | 05 | 02 |
| P1-E2 | Causes and cause management | 06 | 05 |
| P1-E3 | Manual donation recording and guest donors | 06 | 04 |
| P1-E4 | Donor's own trail view (received and allocated) | 06 | 02 |
| P1-E5 | Admin area shell and audit log | 05 | 04 |
| **P2** | **Transparency** | | |
| P2-E1 | Spending entries with receipts | 06 | 05 |
| P2-E2 | First-in-first-out matching | 06 | 04 |
| P2-E3 | Zakat, Sadaqah and general ring-fencing | 06 | 05 |
| P2-E4 | All-needs split | 06 | |
| P2-E5 | Donor accounts, profiles and donor wall | 06 | 05 |
| P2-E6 | Spending reports and public cause transparency | 06 | 05 |
| P2-E7 | Email receipts and notifications | 03 | 06 |
| **P3** | **Content hub** | | |
| P3-E1 | Student and teacher accounts, classes and personas | 07 | 04 |
| P3-E2 | Parent consent records | 07 | 04 |
| P3-E3 | Threads and post types | 07 | 02 |
| P3-E4 | Media upload, caps and YouTube embeds | 03 | 07 |
| P3-E5 | Sharing scopes, moderation and reports | 07 | 05 |
| P3-E6 | Teacher hub and verified articles | 07 | 02 |
| P3-E7 | Onboarding walkthrough | 02 | 07 |
| P3-E8 | Public student work and teacher work pages | 05 | 07 |
| **P4** | **Sponsorship, projects and outreach** | | |
| P4-E1 | Orphan sponsorship matching and progress updates | 06 | 07 |
| P4-E2 | Sponsorship consent with an assignable second sign-off | 06 | 04 |
| P4-E3 | Sponsor messages through the madrasa | 06 | 05 |
| P4-E4 | New projects module | 05 | 06 |
| P4-E5 | Monthly reminders and newsletter | 03 | 06 |
| **P5** | **Online payments (open: planned in detail when reached)** | | |
| P5-E1 | Gateway selection with Sami | 03 | 06 |
| P5-E2 | Card one-off and recurring donations | 03 | 06 |
| P5-E3 | JazzCash and Easypaisa one-off donations | 03 | 06 |
| P5-E4 | Multi-currency display | 06 | 02 |
| P5-E5 | Automatic reconciliation, failures and refunds | 06 | 03 |
| P5-E6 | Tax-deductible receipts after registration | 06 | |

## 4. Agent rules

1. Read `00-MASTER-PLAN.md` first, every time. It overrides everything else.
2. Work only on tasks whose dependencies are done. Pick the highest-priority open task in the earliest phase.
3. Before starting a task, open its specialist document and the requirement lines it references.
4. Never invent a requirement. If something is missing, add `- [ ] REQ-... (proposed)` and an open question, and do not build on it until it is approved.
5. If documents conflict, stop, record it in the decision log, and fix the lower document.
6. When a task is finished, tick its checklist lines, set its status to `done`, and note what changed.
7. Every changed decision is logged with a reason.
8. Privacy wins over convenience. Anonymous means anonymous in the database, API, exports, logs and emails.
9. Child safety wins over publishing speed.
10. Do not touch files outside your task's document without recording why.
11. Every table has `institute_id`, and every query respects row-level security.

## 5. Roadmap

Each phase ends in a test that a person can run by hand. Online payments come last, by Sami's decision ([D-025](08-decision-log.md#d-025)). There is no deadline: phases finish when their test passes.

| Phase | Ends when this works |
| --- | --- |
| **P0 Foundations** | `azeem-lateef.com/ur` and `/en` load a bilingual skeleton with the Markaz Al Azeem logo. The Urdu page runs right to left. An admin can log in. An automated test shows a second, test institute cannot read the first institute's rows. |
| **P1 Public site and manual donations** | The admin creates the cause "Wheat stock" in Urdu and English and records a bank transfer from a guest donor. The donor gets an email with a private link, opens it and sees *received* and *allocated* events. The public cause page shows the new total. |
| **P2 Transparency** | The admin records a wheat purchase with a receipt photo. The oldest unspent wheat donations are marked as spent, and each donor's trail shows their share of that purchase. Zakat money stays only in Zakat-eligible causes. The donor wall shows the amount, with the name or "Anonymous" as each donor chose. |
| **P3 Content hub** | A teacher creates a student account. The student logs in, follows the walkthrough, sets up a persona and posts a question to the class, which appears at once. A teacher answers it and turns the thread into a verified article. A request to make it public waits for teacher or principal approval, then appears on the student work page under the persona. |
| **P4 Sponsorship, projects and outreach** | A sponsor is matched to an orphan and sees only the persona name, age and updates. After Moazam and an assigned teacher both sign off consent, the sponsor sees the full profile, which disappears when consent is withdrawn. A new project appears as a cause, and donors who opted in receive the monthly email. |
| **P5 Online payments** | Planned in detail when reached. At minimum, a test card donation and a test wallet donation each create a *received* trail event without manual entry. |

## 6. Risks and open questions

### Risks

| ID | Risk | Effect | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| R-01 | Legal registration takes longer than expected | No payment gateway or tax receipts | Manual bank-transfer recording until P5 ([D-008](08-decision-log.md#d-008)) | Moazam |
| R-02 | Free tiers run out, especially for media | Site slows or stops | Upload caps, YouTube embeds, upgrade triggers in [03 §14](03-architecture.md) | Sami |
| R-03 | Manual recording is a heavy load on the principal | Trail falls behind | Fast, phone-friendly admin forms; daily or weekly batches | Sami |
| R-04 | A student's identity or contact details leak | Harm to a child | Personas by default, contact-detail blocking, teacher visibility, fast takedown ([07 §12](07-content-hub-student-teacher.md)) | Moazam |
| R-05 | Zakat is spent on an ineligible cause | Loss of donor trust and religious wrong | Ring-fencing at data level, admin-set eligibility per cause ([06 §6](06-donations-and-trail.md)) | Moazam |
| R-06 | One developer is a single point of failure | Work stops | Plain documents, small tasks, this plan as the hand-over | Sami |
| R-07 | Urdu web fonts are heavy | Slow pages on 3G | Font subsetting and a fallback rule in [02 §6](02-design-ui-ux.md) | Sami |

### Open questions

| ID | Question | Owner | Due |
| --- | --- | --- | --- |
| Q-01 | Which payment gateway and wallets to use | Sami | Before P5 |
| Q-02 | When registration completes, and what tax receipts need to show | Moazam | Before P5 |
| Q-03 | Who holds the editor and finance officer roles | Moazam | P1 |
| Q-04 | Which scholar's name, if any, is shown as approving Zakat causes | Moazam | P2 |
| Q-05 | When photos and videos of the madrasa will be available | Moazam | P1 |
| Q-06 | Which email sending service fits the free tier | Sami (03) | P0 |
| Q-07 | Confirm the proposed performance and takedown targets ([D-026](08-decision-log.md#d-026), [D-027](08-decision-log.md#d-027)) | Sami | P0 |
| Q-08 | Approve or reject the proposed requirements in [01](01-requirements-checklist.md#proposed-awaiting-approval) | Sami | Before the phase of each one |
| Q-09 | Approve or reject the proposed decisions from the specialist documents ([08](08-decision-log.md#proposed-decisions-from-the-specialist-documents)) | Sami | P0 |
| Q-10 | May the admin and finance officer see who gave an anonymous donation, so they can record transfers, send receipts and reconcile? (04-D11, 06-P08) | Sami | P1 |
| Q-11 | With no private messages, how can a student raise a serious worry with staff through the hub? Until answered, the walkthrough tells students to speak to a teacher in person (07 Q-07-01) | Moazam | P3 |
| Q-12 | Should media in a student's post wait for a teacher's check before other students see it? (07 Q-07-02, PD-07-05) | Moazam | P3 |
| Q-13 | May faces appear inside a class or the madrasa without consent? Proposed: no (07 Q-07-03) | Moazam | P3 |
| Q-14 | Are "lesson" and "resource" enough as labels on existing post types? (07 Q-07-04) | Sami | P3 |
| Q-15 | Does anything change when a former student turns 18? (07 Q-07-05) | Moazam | P3 |
| Q-16 | Which teachers can widen a post's scope? (07 Q-07-06) | Moazam | P3 |
| Q-17 | Who approves a verified article for public view: an editor or admin (REQ-TCH-004), or the class teacher or principal (REQ-MOD-003)? Default: editor or admin (07 Q-07-07, PD-07-07) | Sami | P3 |
| Q-18 | Can an orphan have more than one sponsor? Default: one (06-P15) | Moazam | P4 |
| Q-19 | Must a tax receipt show the real name of an anonymous donor? (06 §14) | Moazam | P5 |
| Q-20 | Who reviews the Urdu wording, for example قلمی نام for persona and کفیل for sponsor? (02 P0-E4-T17) | Moazam | P0 |
| Q-21 | Server-rendered pages may need more than the free 10 ms of CPU per request, making Workers Paid (about $5 a month) the likely first upgrade. Who pays it, and should it be raised as a tech-costs cause? (03 §14) | Sami | P0 |

## 7. Task index

Compiled in the consistency check on 2026-11-07: **327 tasks**, all `todo` (P0 76, P1 67, P2 51, P3 95, P4 26, P5 12). Every requirement in [01](01-requirements-checklist.md) is covered by at least one task, every task-level dependency points to a task that exists, and there are no dependency loops. A dependency on a whole epic means every task in that epic must be done.

| Epic | Tasks by document | Count |
| --- | --- | --- |
| P0-E1 | [03](03-architecture.md#tasks) T01–T15 | 15 |
| P0-E2 | [04](04-database.md#tasks) T01–T19 · [03](03-architecture.md#tasks) T30–T32 | 22 |
| P0-E3 | [03](03-architecture.md#tasks) T01–T09 | 9 |
| P0-E4 | [02](02-design-ui-ux.md#tasks) T01–T17 | 17 |
| P0-E5 | [03](03-architecture.md#tasks) T01–T10 · [05](05-public-pages-roles-admin.md#tasks) T50–T52 | 13 |
| P1-E1 | [05](05-public-pages-roles-admin.md#tasks) T01–T15 · [02](02-design-ui-ux.md#tasks) T20–T21 · [04](04-database.md#tasks) T40 | 18 |
| P1-E2 | [06](06-donations-and-trail.md#tasks) T01–T06 · [04](04-database.md#tasks) T40 · [05](05-public-pages-roles-admin.md#tasks) T50 | 8 |
| P1-E3 | [06](06-donations-and-trail.md#tasks) T01–T12 · [03](03-architecture.md#tasks) T30–T32 · [04](04-database.md#tasks) T40–T47 | 23 |
| P1-E4 | [06](06-donations-and-trail.md#tasks) T01–T05 · [02](02-design-ui-ux.md#tasks) T20 · [04](04-database.md#tasks) T40 | 7 |
| P1-E5 | [05](05-public-pages-roles-admin.md#tasks) T01–T10 · [04](04-database.md#tasks) T40 | 11 |
| P2-E1 | [06](06-donations-and-trail.md#tasks) T01–T05 · [03](03-architecture.md#tasks) T30–T31 · [04](04-database.md#tasks) T40 · [05](05-public-pages-roles-admin.md#tasks) T50 | 9 |
| P2-E2 | [06](06-donations-and-trail.md#tasks) T01–T05 · [04](04-database.md#tasks) T40–T42 | 8 |
| P2-E3 | [06](06-donations-and-trail.md#tasks) T01–T04 · [02](02-design-ui-ux.md#tasks) T20 · [04](04-database.md#tasks) T40 | 6 |
| P2-E4 | [06](06-donations-and-trail.md#tasks) T01–T03 · [04](04-database.md#tasks) T40 | 4 |
| P2-E5 | [06](06-donations-and-trail.md#tasks) T01–T07 · [02](02-design-ui-ux.md#tasks) T20 · [04](04-database.md#tasks) T40–T41 · [05](05-public-pages-roles-admin.md#tasks) T50–T51 | 12 |
| P2-E6 | [06](06-donations-and-trail.md#tasks) T01–T03 · [04](04-database.md#tasks) T40 · [05](05-public-pages-roles-admin.md#tasks) T50–T51 | 6 |
| P2-E7 | [03](03-architecture.md#tasks) T01–T05 · [06](06-donations-and-trail.md#tasks) T60 | 6 |
| P3-E1 | [07](07-content-hub-student-teacher.md#tasks) T01–T13 · [04](04-database.md#tasks) T40–T41 | 15 |
| P3-E2 | [07](07-content-hub-student-teacher.md#tasks) T01–T05 · [04](04-database.md#tasks) T40 | 6 |
| P3-E3 | [07](07-content-hub-student-teacher.md#tasks) T01–T14 · [02](02-design-ui-ux.md#tasks) T20–T21 · [04](04-database.md#tasks) T40–T41 | 18 |
| P3-E4 | [03](03-architecture.md#tasks) T01–T09 · [04](04-database.md#tasks) T40 · [07](07-content-hub-student-teacher.md#tasks) T70–T73 | 14 |
| P3-E5 | [07](07-content-hub-student-teacher.md#tasks) T01–T11 · [03](03-architecture.md#tasks) T30 · [04](04-database.md#tasks) T40–T41 · [05](05-public-pages-roles-admin.md#tasks) T50 | 15 |
| P3-E6 | [07](07-content-hub-student-teacher.md#tasks) T01–T06 · [02](02-design-ui-ux.md#tasks) T20 · [04](04-database.md#tasks) T40 | 8 |
| P3-E7 | [02](02-design-ui-ux.md#tasks) T01–T07 · [07](07-content-hub-student-teacher.md#tasks) T70 | 8 |
| P3-E8 | [05](05-public-pages-roles-admin.md#tasks) T01–T07 · [04](04-database.md#tasks) T40 · [07](07-content-hub-student-teacher.md#tasks) T70–T72 | 11 |
| P4-E1 | [06](06-donations-and-trail.md#tasks) T01–T04 · [02](02-design-ui-ux.md#tasks) T20 · [04](04-database.md#tasks) T40 | 6 |
| P4-E2 | [06](06-donations-and-trail.md#tasks) T01–T03 · [04](04-database.md#tasks) T40 | 4 |
| P4-E3 | [06](06-donations-and-trail.md#tasks) T01–T02 · [04](04-database.md#tasks) T40 · [05](05-public-pages-roles-admin.md#tasks) T50 | 4 |
| P4-E4 | [05](05-public-pages-roles-admin.md#tasks) T01–T05 · [06](06-donations-and-trail.md#tasks) T60 | 6 |
| P4-E5 | [03](03-architecture.md#tasks) T01–T04 · [06](06-donations-and-trail.md#tasks) T60–T61 | 6 |
| P5-E1 | [03](03-architecture.md#tasks) T01–T02 | 2 |
| P5-E2 | [03](03-architecture.md#tasks) T01–T02 | 2 |
| P5-E3 | [03](03-architecture.md#tasks) T01–T02 | 2 |
| P5-E4 | [06](06-donations-and-trail.md#tasks) T01 · [03](03-architecture.md#tasks) T30 | 2 |
| P5-E5 | [06](06-donations-and-trail.md#tasks) T01–T02 · [03](03-architecture.md#tasks) T30 | 3 |
| P5-E6 | [06](06-donations-and-trail.md#tasks) T01 | 1 |

## 8. Glossary

Every document uses these words with these meanings.

| Term | Meaning |
| --- | --- |
| **Institute** | One madrasa or non-profit on the platform. Today there is one: Markaz Al Azeem. Every record belongs to one institute through `institute_id`. |
| **Cause** | Something donors can give to, such as wheat stock or kitchen gas. Every cause has a type: *campaign*, *ongoing* or *yearly stock*. |
| **Campaign** | A cause with a target and an end date, after which it stops accepting donations. |
| **All needs** | A donation without a chosen cause. The admin later splits it across causes. |
| **Donation** | One gift of money by one donor, with an amount, a date, a type (*Zakat*, *Sadaqah* or *general*) and a cause or *all needs*. |
| **Allocation** | The link that assigns money to a cause (from an all-needs split) or assigns part of a donation to a spending entry (through first-in-first-out matching). |
| **Spending entry** | One recorded use of money from a cause, such as a wheat purchase, with an amount, a date, a description and an optional receipt. |
| **Trail** | The append-only sequence of events for a donation: *received*, *allocated*, *spent* and *reported*, plus *reversal* events that correct an earlier event without changing it. |
| **Transfer notice** | A donor's message saying they sent a bank transfer. It is the *notified* state of a donation, waiting for the admin to confirm it against the bank. It has no receipt and no trail event until confirmed. |
| **Pledge** | A promise to give monthly or yearly. Until card payments arrive, the admin records each payment as a one-off donation linked to the pledge. |
| **First in, first out (FIFO)** | The matching rule: a spending entry draws on the oldest unspent donations in its cause first. |
| **Donor** | Anyone who gives. A *guest donor* gives with only an email and gets a private trail link. An *account donor* has a login. |
| **Donor wall** | The public list of donations. It always shows amounts. It shows the donor's name only where they chose that. |
| **Persona** | A student's anonymous public identity. Only the student's teachers and admins can see who it belongs to. |
| **Sponsor** | A donor matched to one orphan through orphan sponsorship. |
| **Consent record** | A staff-entered record of a parent's or guardian's consent. For orphans, it needs two sign-offs: the principal and a teacher he assigns. |
| **Thread** | A conversation in the content hub: a first post and its replies. |
| **Post** | One item in a thread: a message, question, answer, poll, article, video, vlog, audio or slides. |
| **Scope** | Who can see a post: *class*, *madrasa* or *public*. *Community* is reserved for the future multi-institute hub. |
| **Verified article** | A published article made from a thread by a teacher and marked as authentic knowledge. |
| **Module** | A feature an institute can switch on or off: student hub, teacher hub or new projects. |
| **Admin** | The role with full control of one institute. At Markaz Al Azeem, this is the principal. |
| **Principal** | Not a role: a marker on one admin (`institute_settings.principal_user_id`). The principal gives the first sign-off on orphan consent, assigns the second, and can approve posts going public. |
