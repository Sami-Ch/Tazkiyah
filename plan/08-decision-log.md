# Decision log

Every non-trivial decision, newest at the bottom. A changed decision gets a new entry that points to the one it replaces. "Sami" means Sami decided in planning; "Main agent" means a proposed default awaiting confirmation.

## D-001
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Build for Markaz Al Azeem only, but make every part ready for more institutes.
**Options:** Multi-institute from day one; single madrasa first and rework later; single madrasa built ready to expand.
**Reason:** Launches quickly for one real user while avoiding a painful database rebuild later.

## D-002
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** One shared Postgres database, with institutes separated by row-level security.
**Options:** One shared database with RLS; a separate database per institute.
**Reason:** Cheaper, simpler for one developer, and makes the future shared community easy.

## D-003
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Each institute uses its own domain. Platform subdomains come later.
**Options:** Own domains; platform subdomains; both.
**Reason:** The madrasa already has `azeem-lateef.com`, and its own domain builds donor trust.

## D-004
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Spending is matched to donations first in, first out.
**Options:** First in, first out; proportional share across all donors; pool level only.
**Reason:** Most personal for donors and simple to explain: each donor sees which purchase their money paid for.

## D-005
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** The main agent asks its questions and waits. It then writes the master plan, checklist and decision log. Sub-agents write documents 02 to 07, and the main agent runs a final consistency check.
**Options:** Assume defaults and continue; ask and wait. One agent for everything; main agent plus sub-agents.
**Reason:** Real answers instead of guesses, and each document gets full attention.

## D-006
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Next.js, Postgres on Neon and Cloudflare hosting, all on free tiers. Sami is the main developer, working pro bono with AI agents.
**Options:** Not compared; this is the developer's existing stack and hosting.
**Reason:** Sami knows the stack, the hosting is already paid for or free, and one developer can maintain it.

## D-007
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Fully bilingual in Urdu and English from Phase 1. Visitors start in their browser's language, or English if the browser sets none.
**Options:** English first and Urdu later; both from the start. Default to Urdu or English.
**Reason:** Local users and overseas donors both need the site from day one.

## D-008
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Donations are recorded manually from bank transfers until online payments arrive. Later, cards will handle one-off and recurring donations, and JazzCash and Easypaisa one-off donations.
**Options:** Wait for gateways before launch; manual recording first.
**Reason:** Legal registration is in progress, and payment providers usually need it before opening a merchant account. Mobile wallets handle automatic monthly charges poorly.

## D-009
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Guest donations are allowed with only an email. The donor gets a private trail link and can claim the donations into an account later.
**Options:** Account required; guest allowed.
**Reason:** Fewer barriers for overseas donors and people on phones.

## D-010
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Donation amounts are public on the donor wall. Each donor chooses whether their name and details show or stay anonymous.
**Options:** Show amounts; hide amounts; donor's choice for amounts.
**Reason:** Public amounts show transparency, while identity stays the donor's choice.

## D-011
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** The admin sets which causes accept Zakat. Each cause can optionally show the name of an approving scholar.
**Options:** A scholar decides; the admin decides; a committee decides.
**Reason:** The principal runs the madrasa day to day. Showing a scholar's name builds trust where one is available (open question Q-04).

## D-012
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** The admin decides how all-needs donations are split across causes.
**Options:** Admin decides; fixed percentages.
**Reason:** Needs change through the year, so a fixed split would not fit.

## D-013
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** The principal records spending entries, in daily or weekly batches as he prefers.
**Options:** Fixed daily reporting; fixed weekly reporting; the principal's choice.
**Reason:** It fits how the madrasa actually works and keeps the load manageable.

## D-014
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** A teacher or admin creates each student account, and the student then personalises it. New users get a guided walkthrough.
**Options:** Open sign-up; staff-created accounts; hybrid.
**Reason:** Staff control who joins, and students still feel the account is their own.

## D-015
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Every student gets an anonymous persona. Admins and the student's teachers can always trace it to the real student. It stays live after the student leaves.
**Options:** Real names; personas; personas that end when a student leaves.
**Reason:** It protects minors, keeps accountability for safety, and lets students keep their identity for life.

## D-016
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Parent consent is a light form recorded by staff. There are no guardian logins and no extra consent steps for students.
**Options:** Guardian accounts; scanned paper forms; a light staff-entered form.
**Reason:** Many parents may not use apps, and student login must stay simple.

## D-017
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** A sponsor is matched to one orphan and sees only the persona name, age and progress updates. A full profile needs guardian consent with two sign-offs: the principal plus any teacher he assigns. It is shown only to that sponsor and can be withdrawn. There is no direct contact between sponsor and child.
**Options:** Fund only; matched but anonymous; full profile.
**Reason:** It gives sponsors a real connection while protecting the children. Two sign-offs avoid one person deciding alone, since the principal is both guardian and head.

## D-018
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** The content hub is an interactive community with threads, and teachers can turn a thread into a verified article.
**Options:** Blog only; threads only; both.
**Reason:** Free discussion plus a clear line between conversation and trusted knowledge.

## D-019
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Class and madrasa posts appear straight away, and teachers and admins can see and manage them. Making a post public or publishing it needs approval from the class teacher or the principal.
**Options:** Approve every post; approve only public posts.
**Reason:** Keeps the community lively while protecting what the public sees.

## D-020
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Upload sizes are capped, and videos can be linked or embedded from YouTube instead of uploaded.
**Options:** Unlimited uploads; capped uploads; links only.
**Reason:** Video would quickly use up free-tier storage and bandwidth.

## D-021
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** The clinic appears only as a cause. Clinic, canteen and development modules come later.
**Options:** Clinic records now; cause only.
**Reason:** Keeps this version focused, and patient data needs its own careful design.

## D-022
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Use the madrasa's existing logo with a new colour scheme designed for this madrasa.
**Options:** Existing logo and colours; existing logo and new colours; all new.
**Reason:** Keeps the recognised emblem while giving the site a fresh, consistent look.

## D-023
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** The platform is called Tazkiyah (تزکیہ).
**Options:** Ta'awun, Bunyan, Tayyibah, Zidni, Qalam, Tazkiyah.
**Reason:** From the Quranic idea in 62:2 of purifying people and teaching them; it shares its root with Zakat, linking giving and education.

## D-024
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** A central platform fund comes in a later version, but the trail is designed now so platform-to-institute transfers fit.
**Options:** Build it now; design for it; ignore it.
**Reason:** The fund would need its own registered trust and Zakat handling. Designing for it now avoids rework.

## D-025
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** Online payment integration is the last phase (P5), and its detail stays open until the project reaches it.
**Options:** Payments early; payments last.
**Reason:** Registration is pending, and Sami wants to discuss gateways in detail later.

## D-026
**Date:** 2026-11-07 · **Decided by:** Main agent (proposed, awaiting Sami, Q-07)
**Decision:** Target: public pages show readable content within 5 seconds on a slow 3G connection.
**Options:** No target; 3 seconds; 5 seconds.
**Reason:** A concrete number makes REQ-PRF-001 testable. Five seconds is realistic for Urdu fonts on low-end phones.

## D-027
**Date:** 2026-11-07 · **Decided by:** Main agent (proposed, awaiting Sami, Q-07)
**Decision:** Target: a taken-down post disappears from public pages within one minute.
**Options:** Immediately; within one minute; next cache refresh.
**Reason:** Makes REQ-MOD-006 testable while allowing for page caching on Cloudflare.

## D-028
**Date:** 2026-11-07 · **Decided by:** Sami
**Decision:** A student's account and persona stay active after they leave the madrasa.
**Options:** Archive the account; keep it live.
**Reason:** Matches the idea that students can keep their persona for life.

## D-029
**Date:** 2026-11-07 · **Decided by:** Consistency check, from Sami's answer on post approval
**Decision:** A post goes public with approval from the class teacher of its class or the principal (REQ-MOD-003). Widening a post's scope inside the madrasa, from class to madrasa, is done only by an admin or a teacher the admin chose (REQ-MOD-007). Going public is approval, not widening.
**Options:** Approver must meet both rules (07 draft); approval and widening are separate acts.
**Reason:** Sami said a post goes public "through the teacher or principal". The 07 draft's stricter reading was fixed to match; 04 and 05 already read it this way.

## D-030
**Date:** 2026-11-07 · **Decided by:** Consistency check (proposed with REQ-DON-015)
**Decision:** A transfer notice is stored in its own table, `transfer_notices`, and becomes a row in `donations` only when the admin confirms it. Pledges are stored in `recurring_pledges`, and each recorded payment links to its pledge.
**Options:** A *notified* status inside `donations`; a separate table.
**Reason:** The ledger then only ever holds money that has arrived, and every donation keeps a receipt number. 02, 05 and 06 each proposed the notice form; 04 had no table for it or for pledges.

## D-031
**Date:** 2026-11-07 · **Decided by:** Consistency check
**Decision:** Teachers can hide or remove any class or madrasa post, not only posts in their own classes.
**Options:** Own classes only (07 draft); any class or madrasa post (REQ-MOD-002, 05 draft).
**Reason:** The checklist outranks the specialist documents, and REQ-MOD-002 says "any". Sami can narrow it.

## Proposed decisions from the specialist documents

Each specialist document records its own decisions in its §3, with the options it considered and its reasons. They are numbered here so they can be approved or rejected (open question Q-09). Until approved they are **proposed**: agents may plan with them, but a change to one needs a new entry here.

| D | Label | Doc | Decision (first sentence) | Status |
| --- | --- | --- | --- | --- |
| D-032 | PD-02-01 | [02](02-design-ui-ux.md) | Direction A, "Night and Paper", is the recommended visual direction (§4). | proposed |
| D-033 | PD-02-02 | [02](02-design-ui-ux.md) | Urdu text uses Naskh (Noto Naskh Arabic) everywhere. | proposed |
| D-034 | PD-02-03 | [02](02-design-ui-ux.md) | Latin body text uses the phone's system font. | proposed |
| D-035 | PD-02-04 | [02](02-design-ui-ux.md) | Numbers use Western digits (0 to 9) in both languages. | proposed |
| D-036 | PD-02-05 | [02](02-design-ui-ux.md) | Theme values live only in `institute_settings`. | proposed |
| D-037 | PD-02-06 | [02](02-design-ui-ux.md) | Students choose a persona avatar from preset pattern avatars. | proposed |
| D-038 | PD-02-07 | [02](02-design-ui-ux.md) | No stock photos, and no generated images of the madrasa or of children, are used as placeholders. | superseded by D-172 |
| D-039 | PD-02-08 | [02](02-design-ui-ux.md) | Lists use a "Show more" button with 20 items per page, not infinite scroll. | proposed |
| D-040 | AR-01 | [03](03-architecture.md) | Run Next.js on Cloudflare Workers with the OpenNext adapter (`@opennextjs/cloudflare`). | proposed |
| D-041 | AR-02 | [03](03-architecture.md) | Connect through Cloudflare Hyperdrive with node-postgres (`pg`), one explicit transaction per request, with transaction-local settings for RLS. | proposed |
| D-042 | AR-03 | [03](03-architecture.md) | Use Better Auth, self-hosted in our own Postgres, with its username and two-factor plugins. | proposed |
| D-043 | AR-04 | [03](03-architecture.md) | Use next-intl for routing and translations. | proposed |
| D-044 | AR-05 | [03](03-architecture.md) | Store media in Cloudflare R2, two buckets (public and private). | proposed |
| D-045 | AR-06 | [03](03-architecture.md) | Run background work in a separate jobs Worker using Cron Triggers and Cloudflare Queues. | proposed |
| D-046 | AR-07 | [03](03-architecture.md) | Propose Resend as the email service. | proposed |
| D-047 | AR-08 | [03](03-architecture.md) | Take the daily backup with a nightly GitHub Actions job that runs `pg_dump` and stores an encrypted file in a private R2 bucket. | proposed |
| D-048 | AR-09 | [03](03-architecture.md) | Put the Neon project in the available region nearest Pakistan (check Mumbai first, then Singapore), and turn on Smart Placement for the web Worker if it lowers response time. | proposed |
| D-049 | AR-10 | [03](03-architecture.md) | Use a monorepo with `apps/web`, `apps/jobs`, `packages/core` (domain logic, DB access, permission checks), `packages/i18n` and `packages/email`. | proposed |
| D-050 | 04-D1 | [04](04-database.md) | Money rule: every amount is a `bigint` in minor units. | proposed |
| D-051 | 04-D2 | [04](04-database.md) | Composite keys for isolation. | proposed |
| D-052 | 04-D3 | [04](04-database.md) | Isolation is a restrictive RLS policy on every table, ANDed with the role policies. | proposed |
| D-053 | 04-D4 | [04](04-database.md) | Roles come from the database, not from the session. | proposed |
| D-054 | 04-D5 | [04](04-database.md) | Bilingual fixed content uses a `localized_text` JSON domain, for example `{"ur": "گندم کا ذخیرہ", "en": "Wheat stock"}`. | proposed |
| D-055 | 04-D6 | [04](04-database.md) | The persona-to-student link lives in its own table, `persona_links`. | proposed |
| D-056 | 04-D7 | [04](04-database.md) | Users are per institute. | proposed |
| D-057 | 04-D8 | [04](04-database.md) | State fields are `text` with a `CHECK` list, not Postgres enum types. | proposed |
| D-058 | 04-D9 | [04](04-database.md) | New donations default to anonymous (`is_anonymous = true`) and trails default to private. | proposed |
| D-059 | 04-D10 | [04](04-database.md) | FIFO order is the donation's `received_at`, then `id`. | proposed |
| D-060 | 04-D11 | [04](04-database.md) | Admins and finance officers can see who gave an anonymous donation, because they record bank transfers, send receipts and reconcile. | proposed |
| D-061 | P05-01 | [05](05-public-pages-roles-admin.md) | URL slugs are the same English words under both prefixes, for example `/ur/causes` and `/en/causes`. | proposed |
| D-062 | P05-02 | [05](05-public-pages-roles-admin.md) | The admin area is a set of pages under the language prefix (`/ur/admin`, `/en/admin`) and is fully translated. | proposed |
| D-063 | P05-03 | [05](05-public-pages-roles-admin.md) | A user can hold several roles in `user_roles`. | proposed |
| D-064 | P05-04 | [05](05-public-pages-roles-admin.md) | *Principal*, *assigned second signer*, *scope widener*, *class teacher* and *sponsor* are markers on top of roles, not roles. | proposed |
| D-065 | P05-05 | [05](05-public-pages-roles-admin.md) | The finance officer records, confirms and reverses donations, records spending entries and publishes reports. | proposed |
| D-066 | P05-06 | [05](05-public-pages-roles-admin.md) | The editor edits fixed page text and cause text and reviews teacher work. | proposed |
| D-067 | P05-07 | [05](05-public-pages-roles-admin.md) | Staff can always make something more private: make a donation anonymous, make a trail private, take down a public post. | proposed |
| D-068 | P05-08 | [05](05-public-pages-roles-admin.md) | The donor wall does not show the donation type (Zakat, Sadaqah or general). | proposed |
| D-069 | P05-09 | [05](05-public-pages-roles-admin.md) | The audit log never stores a donor's name or email, or a student's real name. | proposed |
| D-070 | P05-10 | [05](05-public-pages-roles-admin.md) | The donate page has a short "Tell us about your transfer" form. | proposed |
| D-071 | P05-11 | [05](05-public-pages-roles-admin.md) | A new project is a cause with "Show on new projects page" turned on. | proposed |
| D-072 | P05-12 | [05](05-public-pages-roles-admin.md) | When a module is off, its pages return "not found", its menu items and home blocks disappear, and its data stays untouched. | proposed |
| D-073 | P05-13 | [05](05-public-pages-roles-admin.md) | Fixed page text (home intro, about, facilities, daily life) is stored as bilingual content in `institute_settings`, with photos in `media_assets`. | proposed |
| D-074 | P05-14 | [05](05-public-pages-roles-admin.md) | Any staff role can take down a public post at once. | proposed |
| D-075 | P05-15 | [05](05-public-pages-roles-admin.md) | New causes start with `accepts_zakat` off. | proposed |
| D-076 | 06-P01 | [06](06-donations-and-trail.md) | Until P5, the donor tells the madrasa about a transfer through a public transfer notice form. | proposed |
| D-077 | 06-P02 | [06](06-donations-and-trail.md) | FIFO orders money in a cause by the date it entered that cause: the donation date for a gift to a cause, and the split date for an all-needs piece. | proposed |
| D-078 | 06-P03 | [06](06-donations-and-trail.md) | A match is final. | proposed |
| D-079 | 06-P04 | [06](06-donations-and-trail.md) | A spending entry may be larger than the cause's unspent money. | proposed |
| D-080 | 06-P05 | [06](06-donations-and-trail.md) | A cause's Zakat flag cannot be switched off while the cause holds unspent Zakat. | proposed |
| D-081 | 06-P06 | [06](06-donations-and-trail.md) | The donation type (Zakat, Sadaqah or general) is never shown on public pages: not on the donor wall, a public trail, or a public profile. | proposed |
| D-082 | 06-P07 | [06](06-donations-and-trail.md) | If the donor has not chosen, a donation is anonymous. | proposed |
| D-083 | 06-P08 | [06](06-donations-and-trail.md) | For an anonymous donation, only the donor, the admin and the finance officer can see who gave it. | proposed |
| D-084 | 06-P09 | [06](06-donations-and-trail.md) | A donor's public profile counts and lists only their named donations. | proposed |
| D-085 | 06-P10 | [06](06-donations-and-trail.md) | One private trail link per guest donor, covering all their donations. | proposed |
| D-086 | 06-P11 | [06](06-donations-and-trail.md) | A spending entry has three states: *draft* (editable, not matched), *recorded* (final, matched by FIFO, visible in donors' private trails) and *reported* (in a published report, visible publicly). | proposed |
| D-087 | 06-P12 | [06](06-donations-and-trail.md) | Receipt numbers look like `MAA-2026-00042`: a prefix from institute settings, the year of recording, and a 5-digit sequence per institute per year. | proposed |
| D-088 | 06-P13 | [06](06-donations-and-trail.md) | Every receipt shows both Urdu and English on one page. | proposed |
| D-089 | 06-P14 | [06](06-donations-and-trail.md) | Sponsorship donations go to one shared cause, Orphan sponsorship. | proposed |
| D-090 | 06-P15 | [06](06-donations-and-trail.md) | An orphan has at most one active sponsor in this version. | proposed |
| D-091 | 06-P16 | [06](06-donations-and-trail.md) | A sponsor must have a donor account. | proposed |
| D-092 | 06-P17 | [06](06-donations-and-trail.md) | Full-profile consent is per sponsorship and lasts 12 months, after which it expires unless both sign-offs are given again. | proposed |
| D-093 | 06-P18 | [06](06-donations-and-trail.md) | Progress updates written by a teacher need the admin's approval before the sponsor sees them. | proposed |
| D-094 | 06-P19 | [06](06-donations-and-trail.md) | A recurring pledge is a promise, not a payment. | proposed |
| D-095 | 06-P20 | [06](06-donations-and-trail.md) | Each cause has a setting "receipt photos public by default". | proposed |
| D-029 | PD-07-01 | [07](07-content-hub-student-teacher.md) | Approving a post for public view is done by the class teacher of the post's class or by the principal (REQ-MOD-003). | settled |
| D-096 | PD-07-02 | [07](07-content-hub-student-teacher.md) | A post has two separate states: an inside state (`visible`, `hidden`, `removed`) and a public state (`none`, `draft`, `submitted`, `approved`, `published`, `taken_down`). | proposed |
| D-097 | PD-07-03 | [07](07-content-hub-student-teacher.md) | Phone numbers, email addresses and contact links are blocked when a student posts. | proposed |
| D-098 | PD-07-04 | [07](07-content-hub-student-teacher.md) | Student avatars come only from a preset set of illustrations with no human faces. | proposed |
| D-099 | PD-07-05 | [07](07-content-hub-student-teacher.md) | Media in a student's post (an upload or a YouTube link) is shown to other students only after a teacher checks it. | proposed |
| D-100 | PD-07-06 | [07](07-content-hub-student-teacher.md) | Editing a post that is `submitted`, `approved` or `published` sends it back to `submitted`, and it leaves public pages until approved again. | proposed |
| D-101 | PD-07-07 | [07](07-content-hub-student-teacher.md) | A verified article goes public only after review by an editor or an admin, and only if every student it quotes has active consent. | proposed |
| D-102 | PD-07-08 | [07](07-content-hub-student-teacher.md) | Lessons and resources in the teacher hub are labels on existing post types, not new post types. | proposed |
| D-103 | PD-07-09 | [07](07-content-hub-student-teacher.md) | The two-sign-off support for an orphan's consent record is built in P3-E2, and P4-E2 reuses it. | proposed |
| D-104 | PD-07-10 | [07](07-content-hub-student-teacher.md) | When a student reveals their real name, it shows as their first name and the first letter of their family name (for example "Ahmed R."), as entered by staff. | proposed |
| D-105 | PD-07-11 | [07](07-content-hub-student-teacher.md) | Replies in a thread are flat (one level), with an optional "replying to" link. | proposed |
| D-106 | PD-07-12 | [07](07-content-hub-student-teacher.md) | When a student leaves, an admin moves them into an "Alumni" class owned by an admin. | proposed |
| D-107 | PD-07-13 | [07](07-content-hub-student-teacher.md) | Report thresholds: three reports from different users hide a class or madrasa post until a teacher reviews it. | proposed |

## D-108

2026-11-07 · Sami · Updates [D-022](#d-022)

Use [Markaz Al Azeem Emblem.png](<../assets/logo/Markaz Al Azeem Emblem.png>) as the institute's logo source. The starter uses responsive WebP copies derived from that file.

## D-109

2026-11-07 · Implementation review · Aligns [03 §4](03-architecture.md#43-database-roles) with [04 §6](04-database.md#6-row-level-security)

Use the schema plan's `tazkiyah_owner` and `tazkiyah_app` names. The transaction supplies institute, user and request IDs, and policies check permissions against `user_roles`. The host lookup exposes only an active institute's ID. The application role stays subject to RLS. Owner-backed views and functions need the explicit tenant checks in 04. The cross-institute test suite must exist before it can run in CI.

## D-110

2026-11-07 · Implementation review

List the direct prerequisites for the cause admin, spending batch, donor wall, donor profile and moderation queue screens. Each task previously depended on its own epic, which made it wait on itself under the master plan's dependency rule. Tie public media copying to the approval and takedown actions so teacher review and media setup can be built in order. See [05 Tasks](05-public-pages-roles-admin.md#tasks) and [03 Tasks](03-architecture.md#tasks).

## D-111

Sami · Homepage direction

Give authentic institutional photos and video a prominent role in the public design. The homepage uses a campus photograph as its lead visual, with a gallery and an on-demand film below. At Sami's request, the local design preview uses labelled web-sourced examples until Markaz Al Azeem's own material is ready. See [02 §14](02-design-ui-ux.md#14-media-placeholders).

## D-112

2026-11-08 · Database implementation · Updates [D-109](#d-109)

Neon named the administrative login `tazkiyah_owner`. Use a separate `tazkiyah_schema_owner` role with no login to own schema objects, and grant the runtime role only the public view and selected functions. Add user and logo foreign keys with their target tables so tenant ownership is enforced from the moment each field exists.

## D-113

2026-11-08 · Phase 0 database implementation

Use case-insensitive indexes for email and username within an institute. Accounts start invited. The audit log stores values for a small set of status and permission fields and redacts the rest. Media uses the `pending` state from the upload flow. Public pages expose published text and ready public cover images without flagged faces. Account and role mutations follow the sign-in and staff workflows.

## D-114

2026-11-08 · Sami · Updates [D-041](#d-041)

Use Drizzle for application queries and one migration history. Keep PostgreSQL-specific role, grant, function, trigger and view SQL in custom migrations in that same history. Existing databases adopt the consolidated baseline after all six original migration hashes are verified. See [04 §13.2](04-database.md#132-migrations).

## D-115

2026-11-09 · Build agent (P0-E2-T14) · Supports [03 §5.3](03-architecture.md#53-deployment-pipeline) and [04 §6.6](04-database.md#66-testing-cross-institute-isolation)

Run the full migration history and every `db/test/*.sql` suite inside `npm test` with PGlite, an in-process build of Postgres. Every local run and pull request then gets the isolation, append-only and policy checks without a database server or Neon credentials. PGlite is PostgreSQL 17 and Neon is PostgreSQL 18, so CI still repeats the suites on a short-lived Neon branch (P0-E1-T07), and that run is the one that counts for REQ-SEC-002. Options: PGlite in Vitest; Postgres in Docker; Neon branches only. Reason: no database or Docker daemon is available on the development machine, and Neon branches need credentials and use free-tier branch slots.

## D-116

2026-11-09 · Build agent (P0-E5-T01, P0-E5-T04) · Moves a check from P0-E5-T01 to [P0-E1-T06](03-architecture.md#p0-e1-repo-environments-and-deployment-to-azeem-lateefcom)

Close P0-E5-T01 on its local proofs, and move "verify sign-in on the hosted preview through `AUTH_HYPERDRIVE`" into P0-E1-T06. That task already owns Worker bindings and secrets, and the check needs a Cloudflare account. Options: mark P0-E5-T01 `blocked` until Cloudflare is set up; move the hosted check. Reason: every database proof in 03 §6.1 passes, and blocking the task would also block every P0-E5 task after it for a reason that belongs to deployment. Sami may reverse this.

P0-E5-T04 also builds the shared matrix definition that P0-E5-T50 names. `can()` cannot be built from the 05 §7 matrix without it. P0-E5-T50 keeps its own status and dependency.

## D-117

2026-11-09 · Build agent (P0-E4-T01) · Fixes a conflict between [02 §5](02-design-ui-ux.md#5-colour) and [04 §5.3](04-database.md#53-institute_settings-one-row-per-institute)

04 showed `theme` as a flat map of colours. 02, which owns the theme shape, stores a nested object with `version`, `direction`, `color`, `font` and `radius`, and the seed already writes that shape. 04 now points to the 02 shape. The database check allows only listed names and well-formed values, so `{}` (the platform default) stays valid. Completeness and contrast are checked by `checkTheme()` before a save. Options: flat colours only; the nested 02 shape. Reason: 02 owns visual tokens, and fonts and radii need a place in the same setting.

## D-118

2026-11-09 · Build agent (P0-E5-T02) · Supports [03 §6.2](03-architecture.md#62-who-signs-in-and-how)

Donor sign-up, email verification and password reset run through Better Auth's own endpoints as `tazkiyah_auth`, so that role now has narrow write rights it did not have before: insert into `app.users`, update `email_verified`, insert a credential and update `password`. Database rules keep it safe. A trigger makes every user that role inserts an active donor with an unverified email, no username, no two-factor and no profile, and gives it only the donor role. A credential can be added only to a donor-only account that has none yet. A password can change by email reset only for accounts that are not students, and the auth role still cannot delete credentials or change a user's status, username or roles. Donor-only accounts must confirm their email before a sign-in creates a session; staff and students are created by someone who checked who they are. Emails go through `EmailSender`; until P1-E3-T30 the console adapter is used on the local origin only, and hosted sign-up and reset answer "Email is unavailable". Options: grant these narrow rights with database checks; write our own sign-up and reset endpoints that call definer functions. Reason: the library's endpoints already give neutral answers for known emails, single-use tokens and session revocation on reset, and the auth role could already create sessions, so a password write adds no new power over an account. `auth_isolation.sql` tests every rule.

## D-119

2026-11-09 · Build agent (P0-E5-T03) · Settles a difference between [03 §6.2](03-architecture.md#62-who-signs-in-and-how) and [07 §4.1](07-content-hub-student-teacher.md#41-student-accounts)

03 gives `azeem-s-0142` as an example username and says the teacher creates "a one-time password"; 07, which owns student accounts, gives `maa-2026-0142` and says the starting password is "set by staff". Usernames are built as the lower-case institute receipt prefix, the year and a four-digit number (`maa-2026-0001` for Markaz Al Azeem, whose prefix is `MAA`), numbered under a lock on the settings row. The staff member may type a starting password (8 to 128 characters); if they leave it out, the server generates 10 characters without look-alike letters. Either way it is shown once and stored only as a hash. The first sign-in must replace it through `/first-password`, which also ends the student's other sessions, and staff workspaces stay closed while `must_change_password` is set. Until classes exist (P3-E1-T41), any teacher or admin can create a student; P3-E1-T41 adds the "teacher of that class" check and the persona. Options: the 03 pattern; the 07 pattern; a random username. Reason: 07 owns the feature, and the receipt prefix is an existing per-institute code that holds no names (REQ-CHS-001).

## D-120

2026-11-10 · Build agent (P1-E3-T41) · Updates [04 §8.3](04-database.md#83-donations)

Keep the built column names `donations.credited_on` (`date`) and `donations.receipt_locale`, in place of the planned `received_at` (`timestamptz`) and `receipt_language`. 04 now uses the built names everywhere, including the FIFO order (04-D10), the donor wall view and the index list. Options: rename the columns and rewrite the recording, trail, receipt and email functions that use them; keep the names and fix 04. Reason: a manual bank transfer only has a credit date on the statement, so a time of day would be invented, and FIFO already breaks ties on `id`. The names are used by several migrations, the receipt worker and the trail page, and renaming them adds risk with no change in behaviour. If online payments in P5 need a time of arrival, a `received_at` column can be added then. Sami may reverse this.

P1-E3-T42 applies the same reasoning to `trail_events`: its date column is `occurred_on` (`date`), not `occurred_at` (`timestamptz`). Bank credits and spending entries (`spent_on`) are both dates. The column was named `credited_on` until then, and was renamed because a *spent* event's date is not a credit date.

## D-121

2026-11-10 · Build agent (P1-E3-T44) · Records a conflict between [05 §7.1](05-public-pages-roles-admin.md#71-money), [06 §11.2](06-donations-and-trail.md#112-the-private-link) and [04 §8.6](04-database.md#86-trail_links-guest-trail-tokens), for Sami

Who may issue (resend) and revoke a guest trail link? 05 §7.1, the permission matrix, says the finance officer and the admin. 06 §11.2 says a two-factor verified administrator during the first release. 04 §8.6 said admins, finance officers and the donor. The built functions keep the narrowest rule, a two-factor verified admin, and 04 now points here. Options: admin only (built); admin and finance officer (05); also the donor (old 04). Reason: widening who can hand out a link to someone's giving history is a privacy decision (00 §4 rule 8), and the matrix and the trail document disagree. **Sami to decide**; widening to finance officers needs only `identity.is_finance_session` in the two functions and the route gate in `auth.ts`.

## D-122

2026-11-10 · Build agent (P1-E3-T47) · Settles a difference between [06 §14.1](06-donations-and-trail.md#141-numbering) and [04 §8.3](04-database.md#83-donations)

06 §14.1 says a receipt number taken by a transaction that fails is "skipped and logged, never reused". 04 §8.3 says the counter row is locked inside the recording transaction, so numbers are unique and gap-free per year. Since P1-E3-T41 and T43, the built rule is 04's: a failed recording rolls back its counter update, and the next donation takes the same number. No number is ever on two receipts, and a reversed donation keeps its number. 06 §14.1 now says the same. Options: gap-free under a lock (04); a sequence that skips numbers and logs the gap (06). Reason: a log written in the failing transaction rolls back with it, so "skipped and logged" cannot be done inside one transaction, and an unbroken sequence is easier to reconcile. Sami may reverse this.

## D-123

2026-11-10 · Build agent (P1-E5-T40) · Narrows [05 §9.1 and §9.3](05-public-pages-roles-admin.md#9-audit-log) for now, for Sami

05 §9 shows "the reason where one is required" on each audit entry and offers an "only entries with a reason" filter. The audit reader returns only whether a reason exists (`has_reason`), not its text. Reasons are free text typed by staff, such as a reversal note, and 05 §9.2 says no donor name or student real name may appear in the audit log screen or its data. A test from P1-E5-T03 already required the reader not to return the reason. Safe, fixed values that explain an action are shown as approved fields instead: a reversal's category (06 §15.2) now shows as `category`. Options: show the reason text; show only that one exists and use fixed categories. Reason: privacy wins (00 §4 rule 8), and fixed categories carry the meaning without free text. Showing reasons later needs a reason category or a name check on input, not just a reader change.


## D-124

2026-11-10 · Build agent (P2-E1-T40) · Settles a difference between [06 §9.1 and §9.2](06-donations-and-trail.md#9-spending-entries-and-reports) and [04 §9.7](04-database.md#97-spending_entries-and-spending_reports), for Sami

06 §9.2 gives a spending entry four states: *draft* (editable, not in FIFO), *recorded* (not editable, reverse instead), *reported* and *reversed*. 04 §9.7 had only `recorded` and `reversed`, and locked amount, cause and date only after the first match. Under 04, an entry saved in an unfinished batch would already count as recorded. The built rule follows 06, the owner of the lifecycle. `spending_entries.status` is `draft`, `recorded` or `reversed`, with `draft` as the default. A draft can change or be deleted, and is never matched or filed in a report. From `recorded` on, amount, cause and date are fixed whether or not the entry is matched yet. The description, receipt, receipt visibility and report may still change, because 04 allows them and a receipt that shows a person must be hideable. *Reported* is not stored: a recorded entry is reported when its report is published, and a published report gains or loses no entries. 06 §9.1 also allows "one or more images" per entry, but 04 §9.7 and REQ-TRL-011 have one receipt. The table keeps one `receipt_media_id`, and 06 §9.1 now says one image for now. More images would need a child table, and that waits for Sami. Options: 04's two states; 06's four states stored as a status; three stored states with *reported* derived from the report. Reason: a derived *reported* cannot drift from the report's own status, and drafts keep unfinished batches out of FIFO and the totals. Sami may reverse this.

## D-125

2026-11-10 · Build agent (P2-E2-T40) · Settles a difference between [04-D10 (D-059)](04-database.md#3-decisions) and [06-P02 (D-077)](06-donations-and-trail.md#3-decisions), for Sami

Both are proposed. 04-D10 orders FIFO money by the donation's credit date, so all-needs money split into a cause later keeps its original date. 06-P02 orders it by the date the money entered the cause, so a split piece joins the queue on the split date, with ties going to the lower receipt number. 04-D10 itself says "06 §8 may confirm or change this", and 06 owns the FIFO rules. So `app.match_spending()` follows 06-P02. The entry date is read from the piece's `allocated` event, so no new column is needed. 04 §9.3 and 04-D10 now say so. Options: the donation date (04-D10); the date the money entered the cause (06-P02). Reason: "oldest unspent donations in its cause" (REQ-TRL-004) means oldest in the cause, and split money was not in the cause before its split. The 04 §9.3 worked example gives the same result under both. Sami may reverse this; the order is one `order by` clause in the function and its test.

## D-126

2026-11-10 · Build agent (P2-E2-T41) · Settles a difference between [06 §8.1 and §9.3](06-donations-and-trail.md#8-trail-event-model-and-fifo) and [04 §9.3 and §9.7](04-database.md#97-spending_entries-and-spending_reports), for Sami

06 said publishing writes a *reported* event for every match, each for "the same piece as the *spent* event". 04 §9.7 said one *reported* event per donation touched by the report, and its §9.3 example shows D2 with one event of 500,000 for S1 and S2 in report R1. The built event shape (P1-E3-T42) agrees with 04: a *reported* event carries only the report, not the allocation or the entry, so per-match events could not be told apart. The built rule: publishing writes one *reported* event per donation for its effective total in the report. A match made after publishing, into an entry already in a published report, gets its own *reported* event at once (06 §8.1). Reversing a spending entry reverses its *spent* events only. Its *reported* events stay as history, and the next report lists it under "Corrections" (06 §15.3). Reversing a whole donation also reverses its *reported* events. 06 §8.1 and §9.3 now say so. Options: one event per match, which needs the allocation on the event; one per donation and report. Reason: it fits the stored shape and 04's worked example, and the donor still sees each piece in its *spent* event. Sami may reverse this.

## D-127

2026-11-10 · Build agent (P2-E5-T40) · Settles a difference between [06 §11.3](06-donations-and-trail.md#113-claiming-into-an-account) and [04 §8.2](04-database.md#82-donors)

06 §11.3 says that when a guest donor claims their donations into an account, "the private link is revoked automatically. The account replaces it." 04 §8.2 said existing trail links "keep working until revoked". `app.claim_donor_records()` follows 06 and revokes the donor's live links in the same transaction, with the reason "Claimed into an account". 04 §8.2 now says so. Options: keep the links working; revoke them on claim. Reason: privacy wins (00 §4 rule 8). A link in an old email works for anyone who holds it, and once the donor has an account the link only adds another way in.

## D-128

2026-11-10 · Build agent (P2-E5-T41) · Settles a difference between [04 §8.5](04-database.md#85-donor-wall-and-anonymity) and [06 §10.1](06-donations-and-trail.md#101-profile-and-per-donation-choice), for Sami

04 §8.5's donor wall sketch showed a donor's name only when their profile was public. 06 §10.1 and REQ-DPR-006 say the name on each donation is set separately from the profile: a donor with an anonymous profile can still show their name on one donation, and a guest, who has no profile, can too. The built `public_api.donor_wall` and `public_api.public_trails` follow the requirement. A donation set to show a name shows the donor's public `display_name`, whatever the profile setting, and never the legal name. An anonymous donation never joins its donor. 04 §8.5 now says so. Today every donation is anonymous (`donations_anonymity_check`), so no name shows until named giving is built. Options: name only with a public profile (04); name whenever the donation says so (06). Reason: REQ-DPR-006 is an approved requirement, and the 04 sketch would silently ignore a donor's explicit choice. What a guest's shown name is (their `display_name`, entered on the donation form) needs confirming when the guest form is built.

## D-129

2026-11-10 · Build agent (P3-E1-T40) · Narrows [04 §6.4](04-database.md#64-policy-summary) for child safety, for Moazam and Sami

04 §6.4 lets a "class teacher" insert and update `class_members` rows without saying which roles. A teacher membership gives its holder `app.is_teacher_of()` over every student the class has ever had, which later opens their persona links (§7.4). If any class teacher could add teachers, one teacher could grant another access to children's real identities without the admin. The built rule: a class teacher adds and ends *student* memberships only. Teacher memberships are added and ended by an admin. The creator of a class joins it as its teacher automatically, so a teacher can still create a class and add students (REQ-TCH-005). 04 §6.4 now says so. Options: any class teacher manages all memberships; class teachers manage students and admins manage teachers. Reason: child safety wins (00 §4 rule 9), and the admin (the principal) stays the one who decides which adults see a child's identity. This touches open question Q-16 on which teachers may widen access, so Moazam may want to confirm it.

## D-130

2026-11-10 · Build agent (P3-E1-T41) · Fixes a conflict between [04 §7.4](04-database.md#74-personas-and-persona_links) and [07 §4.2](07-content-hub-student-teacher.md#42-first-login-and-persona-setup), Sami may reverse

04 §7.4 allowed a persona bio of up to 280 characters. 07 §4.2, which owns the persona rules (REQ-STU-002 → 07 §4), allows 160. The built `personas_bio_check` allows 160, and 04 now says so. The display name follows 07 §4.2 in the database too: 3 to 24 Urdu or Latin letters, digits, spaces and hyphens, never digits only and never a phone number. Both name and bio refuse the phone numbers, email addresses (also spelled out) and contact links of 07 §12.2. The real-name match and the word block list stay with P3-E1-T03. Options: 280 (04); 160 (07). Reason: 07 owns the rule, and the shorter limit leaves less room for a child to give away who they are (00 §4 rule 9).

## D-131

2026-11-10 · Build agent (P3-E1-T41) · Settles how [04 §7.4](04-database.md#74-personas-and-persona_links)'s `app.create_student_account()` meets the built sign-in, Sami may reverse

P0-E5-T03 had already built `identity.create_student_account(session, name, password hash)` for the auth role, which made a user and the student role but no class membership or persona. 04 §7.4 asks for one transaction that makes the user, the role, the membership, a persona with a generated name and the private link. The built shape: `app.create_student_account(full_name, username, class_id, is_orphan)` does all five and returns null unless the caller is an admin or a teacher of that open class. It is granted to no runtime role. `identity.create_student_account` now takes the class and the orphan flag, checks the staff session, generates the username, calls the app function and stores the starting password. The class is required (07 §4.1, "at least one"). The old three-argument function is dropped, so no path makes a student without a persona (REQ-STU-003). The student-account route sends `classId` and `isOrphan`. Two related narrowings: a student's own `show_real_name` cannot be set by anyone until P3-E1-T13 adds the consent check (07 §5.2), and only an admin switches a persona off (04 §7.4). The optional public name of 07 §4.1 is not stored yet, because 04 §7.1 says `public_name` is null for students while 07 §4.1 and PD-07-10 store "Ahmed R." there. That conflict is left for Sami with P3-E1-T13. Options: grant the app function to `tazkiyah_app` beside the auth function; one path through the auth function. Reason: a student without a starting password or a persona would be a broken account, and one path is easier to keep safe.

## D-132

2026-11-10 · Build agent (P3-E2-T40) · Fixes conflicts between [04 §10.1](04-database.md#101-consent_records), [07 §5](07-content-hub-student-teacher.md#5-consent) and the glossary in [00 §8](00-MASTER-PLAN.md#8-glossary), Sami may reverse

Three points. **Sign-offs:** 04 §10.1 limited the two sign-offs to the `orphan_full_profile` kind. The master plan's glossary says a consent record for an orphan needs two sign-offs, and 07 §5.4 applies that to hub consent. The master plan wins, so every record of a student who is an orphan needs the principal's and an assigned teacher's sign-offs before it counts, and the orphan flag is read live, so a student marked as an orphan later loses single-signature consent until it is signed. The sign-off and assignment functions are built now rather than in P4-E2-T40 (proposed PD-07-09 says the same). P4-E2-T40 still adds the `orphan_full_profile` kind, its sponsorship link and the sponsor view gating. **One row per item:** 07 §5.1 lets one form cover several items, each a separate yes or no; 04 stores one `kind` per row. The table keeps one row per item and adds 07's `face` item, which 04 allowed 07 to add; the form task (P3-E2-T01) writes one row per ticked item. 04 also lacked the "date given" field of 07 §5.1, now `given_on`. **Withdrawal:** 04 let any admin or either signer record a withdrawal. A teacher of the student may also record one, because that teacher may record consent (04 §6.4) and a withdrawal only ever reduces what is shown. 07 §5.4's "declines with a note" has no column; until the form task adds one, a teacher who will not sign simply does not, and the principal reassigns. Options: follow 04 as written; follow the glossary and 07. Reason: the master plan wins (00 §1), and child safety wins (00 §4 rule 9).

## D-133

2026-11-10 · Build agent (P3-E3-T40) · Narrows [04 §6.4](04-database.md#64-policy-summary) for threads and posts until P3-E3-T11 and P3-E5-T40, Sami may reverse

04 §6.4 lets the author update a post's content and teachers and admins update it for moderation. Both need rules that later tasks build: editing must keep earlier versions for teachers (REQ-CHS-003, P3-E3-T11), and every moderation step needs the transition trigger with its approver and consent checks (REQ-CHS-005, P3-E5-T40). Granting updates now would let a student change a post before a teacher sees it, or move a post to `public` without consent. So `tazkiyah_app` gets select and insert only on `threads` and `posts`, inserts are limited to `draft` or `published` in `class` or `madrasa` scope, and the thread counters are kept by a definer trigger. P3-E3-T11 and P3-E5-T40 add the update paths. Options: grant column updates now; hold them back. Reason: child safety wins over publishing speed (00 §4 rule 9), and nothing in P3 needs an edit before those tasks.

## D-134

2026-11-10 · Build agent (P3-E3-T41) · Fixes conflicts between [04 §11.5](04-database.md#115-polls), [04 §6.4](04-database.md#64-policy-summary) and [07 §6.4](07-content-hub-student-teacher.md#64-polls), Sami may reverse

04 §11.5 allowed two to ten poll options; 07 §6.4, which owns the poll rules (REQ-STU-007 → 07 §6), allows two to six of up to 80 characters, a multiple-choice maximum set by the creator, a closing date 1 hour to 30 days out (7 by default) and the creator's choice of showing results after voting or after closing. 04 had no columns for the maximum or the results choice, so `posts` gains `poll_max_choices` and `poll_results`, and 04 now follows 07. 04 §6.4 also let the author update and delete options before the first vote and voters update their own vote. Options are insert-only for now, like posts (D-133), because changing an option after classmates have read it is an edit without the kept versions of REQ-CHS-003. A vote is changed by taking it back and casting another, which the policies allow while the poll is open. 04 §6.4 lets admins read votes; 07 §6.4 also lets the voters' teachers, which is built. 04 §6.4 lets any member with access vote; 07 §4.6 says editors do not, which is built. Options: follow 04; follow 07. Reason: 07 owns the rule, and the narrower edit rights keep a child's post from changing unseen (00 §4 rule 9).

## D-135

2026-11-10 · Build agent (P3-E4-T40) · Narrows [04 §6.4](04-database.md#64-policy-summary) for `post_media` and settles who sets the face flag of [04 §11.7](04-database.md#117-media_assets), Sami may reverse

04 §6.4 lets the post's author insert and delete `post_media`. Adding or removing media on a post others have already seen is an edit, and edits must keep earlier versions for teachers (REQ-CHS-003, P3-E3-T11), as D-133 said for posts. So the author attaches media only in the transaction that creates the post, or to a draft, and removing media is left to the post's teachers and admins, who moderate (REQ-MOD-002). P3-E3-T11 can widen both once versions exist. 04 §11.7 says the face flag is "set by the uploader or a teacher" without saying who may clear it. Raising it only ever hides media, so the uploader, the uploader's teachers and admins may raise it; only staff clear it, so a student cannot undo a teacher's flag. Raising it on public media without face consent turns the media private rather than failing, so the flag can always be raised. Options: follow 04 as written; narrow as built. Reason: child safety wins (00 §4 rule 9).

## D-136

2026-11-10 · Build agent (P3-E5-T40) · Settles conflicts between [04 §11.3](04-database.md#113-moderation-states) and [07 §8](07-content-hub-student-teacher.md#8-moderation) in the moderation trigger, Sami may reverse

The trigger keeps 04's single `moderation_state` plus hide and takedown columns, because 07's separate inside and public states (PD-07-02, D-096) are still proposed; the inside state `removed` is therefore not built. Where 04 and 07 differ, the safer reading is built. **Restore:** 04 lets an admin restore a taken-down post to `published`; 07 §8.2 sends a public post back to `submitted` for fresh approval. A public post now returns to its class or madrasa scope as `submitted`; a post that was never public returns to `published`. **Reject:** 04 only has `submitted → published`; 07 has `submitted → draft`. A post that was live returns to `published`, a draft request returns to `draft`, and the author may also withdraw (07). **Consent:** 04 checks it on publishing, 07 when the request is sent; both are checked. **Approvers:** an admin or a class teacher of the post's class (D-029, REQ-MOD-003); for a student's post outside a class, a teacher of any class the student is in (07 §8.2). Editors approve only staff work (REQ-TCH-004). The principal approves as an admin. **Madrasa scope:** 07 §8.1 and §8.4 let any teacher hide or take down a madrasa-scope post; so any teacher also reads madrasa-scope posts, including widened class posts and hidden ones, or they would lose sight of what they moderate. Showing a hidden post again stays with its class teacher or an admin (07 §8.1). **System steps** (report thresholds, consent withdrawal) have no user and may only hide or take down. Options: follow 04's diagram as drawn; follow 07; the mix above. Reason: child safety wins (00 §4 rule 9) and 07 owns the moderation rules.

## D-137

2026-11-10 · Build agent (P3-E5-T41) · Fixes a conflict between [04 §11.6](04-database.md#116-post_reports) and [07 §8.5](07-content-hub-student-teacher.md#85-reports-and-the-moderation-queue), Sami may reverse

04 §11.6 listed report reasons `contact_details`, `unkind`, `unsafe`, `wrong_information`, `other` and said the final list is in 07 §8. 07 §8.5 lists personal details, face or real name shown, unkind or bullying, wrong religious information, and other with up to 300 characters. The built codes follow 07: `personal_details`, `face_or_name`, `unkind`, `wrong_information`, `other` (note required). Who may report follows 07 §8.5 (students, teachers, editors and admins, not finance officers), and who closes a report follows the moderation rights of D-136. The queue lists report items only to people who moderate the post, so an editor sees teacher-work requests but not reports (07 §8.5). Options: 04's list; 07's list. Reason: 04 deferred to 07.

## D-138

2026-11-10 · Build agent (P4-E1-T40) · Settles open points of [04 §10.3](04-database.md#103-sponsorship-tables) against [06 §12](06-donations-and-trail.md#12-orphan-sponsorship), Sami may reverse

Four points, each the narrower reading. **Sponsor view:** 04 filters `app.sponsor_child_view` to `app.my_donor_ids()`, which also admits a guest opening a trail link. 06 §12.2 says the page is visible only after logging in, and 06-P16 (proposed) makes sponsors account donors. The view reads only the signed-in account's donor row (`app.my_account_donor_id()`), and matching refuses a donor without an account. **One sponsor:** 04's partial unique index covers `active` rows; a paused sponsorship would then let a second sponsor be matched. The index covers every sponsorship that has not ended (06-P15, Q-18 default). **Teacher updates:** 06 §12.3 (06-P18, proposed) holds a teacher's update until the admin publishes it; built so, since 04 already has `published_at`. **Photos:** until full-profile consent exists (P4-E2-T40), an update photo must have `shows_face = false` (06 §12.3, REQ-CHS-001). Options: follow 04 as written; the narrower readings. Reason: child safety wins (00 §4 rule 9).

## D-139

2026-11-11 · Build agent (P3-E8-T40) · Reads [04 §6.5](04-database.md#65-public-views) "never shows author user id" for `public_api.public_posts`, Sami may reverse

04 §6.5 says `public_posts` never shows `persona_links` or the author user id. 05 §5.13 needs the teacher work item to show the author's short profile (REQ-TCH-001) from `public_api.public_teachers`, which needs a key. The view shows `teacher_id` only for staff posts, whose authors publish under their public name anyway; a student's post is written by a persona and carries no user id, so no student's user id or link can appear. Options: no key, matching teachers by public name (names may repeat); the staff author's id only. Reason: the rule protects students, and the narrow reading keeps it whole.

## D-140

2026-11-11 · Build agent (P4-E2-T40) · Fits [06 §12.4](06-donations-and-trail.md#124-full-profile-and-consent)'s full-profile states into [04 §10.1](04-database.md#101-consent_records), Sami may reverse

06 §12.4 draws *declined*, *withdrawn*, *expired* and *ended* states; 04 §10.1 computes only `pending`, `active` and `withdrawn`, with no decline column. A decline is recorded with `app.withdraw_consent`, which either signer may already use, and `app.consent_status` reads a record withdrawn before both sign-offs as `declined`. A signed record whose sponsorship is ended reads `ended`, and one whose sponsorship is paused reads `paused` and shows nothing until the sponsorship resumes; 06 does not say whether pausing ends consent, so pausing hides the profile without ending it. *Expired* waits for proposed REQ-ORP-010. 06 §12.4's short life story and study progress have no columns in 04, so the full profile returns the real name, the student's photo and current class names (04 §10.3) until they are added. Options: add a stored decline state; compute it as built. Reason: no schema change is needed, and every state that shows nothing errs towards the child (00 §4 rule 9).

## D-141

2026-11-11 · Build agent (P4-E3-T40) · Narrows [06 §12.5](06-donations-and-trail.md#125-messages-through-the-madrasa) for `sponsor_messages` until the inbox task, Sami may reverse

06 §12.5 says the admin "and any teacher he chooses" read and reply. 04 §10.3 has no column or table for that choice, so only admins read and reply for now; P4-E3-T01 (staff inbox) can add the chosen teachers with a schema change. A sponsor writes only while the sponsorship is active, matching the sponsor page, which shows active sponsorships only; an admin may still reply while it is paused, so the madrasa can explain the pause, and nobody writes after it ends. The sponsor keeps reading the history. Options: let any teacher of the child read; admins only. Reason: messages about an orphan should reach as few people as possible until the admin chooses (00 §4 rule 9).

## D-142

2026-11-12 · Sami · Vercel handoff and Resend email

Sami will deploy the current Next.js app to Vercel and chose Resend for account emails and donor receipts (Q-06). The handoff adds Vercel request handling and an authenticated receipt job endpoint using the existing outbox. The [Vercel handoff](../docs/vercel.md) describes the project settings and database roles for this release.

## D-143

2026-11-14 · Frontend · Public design system

The public shell and pages use Direction A. `themeStyle()` writes the institute theme onto `<html>`. When the database answers, the theme and enabled modules come from `public_api.institute_public`. Otherwise the seeded Night and Paper theme is used. Tasks that depended on all of P0-E1 were narrowed to P0-E1-T01, because the rest of that epic is Cloudflare, DNS and hosted secrets.

The self-hosted Noto Naskh Arabic variable file is 94,032 bytes, about 2 KB over the 90 KB Urdu budget. It stays, so Urdu buttons can be real bold rather than a second face. Noto Nastaliq Urdu is not downloaded. Public Urdu headings use it only when the phone already has the font (`local()`, `font-display: optional`). Naskh is the fallback and keeps the taller line height.

The component gallery is `/{lang}/design` and is `noindex`, so other work can reuse it without a staff login. The planned admin-only `/_design` path can replace it later.

`/{lang}/transparency` lists raised and spent for every public cause. The sitemap did not name that path. The home page and each cause page already required the same figures from `public_api.cause_summary` and `public_api.cause_spending`, and one page holds them together.

`tazkiyah_auth` may select `public_api.public_posts` and `public_api.public_teachers`, and may execute `app.module_enabled` and `app.persona_work_may_show`. That is the role the public site already uses. The views still hide student identity. A visitor's report does not write `post_reports`, because REQ-MOD-008 is still proposed. The button goes to the contact page and asks people not to send a child's details.

A spending row shows its date, amount and description. Receipt photos stay off the page until a public media URL exists. The view has a storage key, and R2 is not configured here.

Amount chips and the form error summary are added for the donate flow (D-145). The settings switch, toasts, a phone bottom sheet and the walkthrough stepper stay open.

## D-144

2026-11-14 · Build agent (P2-E2-T05) · The donor trail reads spending that `app.match_spending()` already writes

P2-E2-T05 depended on P2-E2-T01, the staff batch form. The matching function itself is done (P2-E2-T40), and the staff form is now done in the staff workspace. The private trail only reads *spent* and *reported* events; it does not record spending. A receipt photo is included only when the spending entry, the file and the face flag all say it may be shown. Options: wait for the staff form; show events that already exist. Reason: a donor cannot see where money went until the page reads the events, and waiting on a form in another workstream would hide purchases that are already matched.

## D-145

2026-11-14 · Build agent (P1-E1-T08) · Bank transfer stays the only way to give

The donate page now asks for an amount and shows card, JazzCash and Easypaisa as unavailable. No gateway keys are stored or required. The "tell us about your transfer" form stays blocked because `transfer_notices` waits on proposed REQ-DON-015 (P1-E3-T46, Q-08). Until that is approved, the page asks the donor to tell the office, which is the fallback in 02 §12.1. Guest trail email (P1-E3-T05) stays blocked on the email service (P1-E3-T30). P5-E2-T01 and P5-E3-T01 stay blocked until a gateway is chosen and credentials exist. Options: invent a notice table; leave the notice blocked and show bank instructions. Reason: rule 4 says not to build on an unapproved requirement, and rule 8 says not to add payment secrets.

## D-146

2026-11-14 · Build agent (P4-E1-T02, P4-E2-T02, P4-E3-T01, P4-E3-T02) · The sponsor page reads matches; it does not create them

The sponsor page reads matches created by the staff form (P4-E1-T01, now done). Matching is an admin insert, and `app.sponsor_child_view()` already returns only that donor's active sponsorships. The page shows the empty state until a match exists. Full-profile fields come from the same view, which hides them when consent is withdrawn. Child photographs are omitted until private short-lived image addresses exist (P2-E1-T30); showing a public URL would break child safety. Sponsor messages are screened with `app.has_contact_details` and have no child recipient. The staff inbox is left for the staff workspace, because only admins may reply (D-141). Options: wait for the matching screen; build the sponsor page on the existing view. Reason: the view is the safety boundary, and a sponsor with a match should be able to see it without this workstream editing the staff area.

## D-147

2026-11-14 · Build agent (P3-E3-T01) · The web app reaches the hub through `identity` functions

The site connects as `tazkiyah_auth`, which cannot insert threads under the `tazkiyah_app` policies. `identity.read_hub`, `identity.start_hub_thread`, `identity.reply_hub_thread` and `identity.report_hub_post` check the session, then apply the same author, scope, module and contact-detail rules. A student is stored as their persona. The response has the pen name or a staff name, never a user id or a persona link. `community` scope is rejected. Options: grant the app role to the auth login; keep definer functions. Reason: the auth login stays narrow, and child safety stays in one place (00 §4 rules 9 and 11). Pin, lock and the staff consent form are left for the staff workspace.

## D-148

2026-11-14 · Build agent (P1-E5-T01) · Staff workspace uses the shared design system, Sami may reverse

The staff menu and workspace screens live inside `/admin` and reuse `apps/web/src/design` (buttons, fields, tables, amount and date formatters, and the public tokens). Role-based links stay in the staff area. The shared button carries both a click handler for the donor screens and `name`/`value` for staff forms, so neither area keeps a second button. Options: keep a private staff stylesheet; use the shared components. Reason: the design system landed in the public branch, and one set of components keeps Urdu and English staff screens on the same type, colour, and money formatting.

## D-150

2026-11-14 · Build agent · Staff edit institute settings from the site

`/admin/settings` lets an admin with a fresh two-factor session edit the institute name, short name, parent body, address, phone, WhatsApp, email, map link, visiting times, founded year, theme direction and principal, plus the daily or weekly spending batch (D-013). The direction is one of the two approved themes. The database stores the full theme object, and staff do not type colours. The logo file and the primary domain are shown and stay read-only. Bank accounts stay on the existing bank-account screen, which this page links to. Visiting times are published inside the existing public contact object, so the contact page can show them. Options: a colour picker and a logo upload; a direction plus the fields that can be typed. Reason: the two directions are already the approved themes, and a logo file needs media storage that is not part of this screen (REQ-MIR-001, REQ-PUB-006).

## D-151

2026-11-14 · Build agent · Module switches ask before anything is hidden

`/admin/settings/modules` is limited to `modules.switch`. Turning a module on saves immediately. Turning one off asks for confirmation and does not delete student work, teacher work or project causes. The public menu and the home teaser include new projects only when `new_projects` is on. The public path is `/new-projects`, the path this task named. `/{lang}/new-projects` is not found while the module is off. Options: `/projects` as 05 wrote it; `/new-projects` as the task named it. Reason: the public nav already hides student and teacher work from the module list, and the new page follows that same switch (REQ-ROL-010).

## D-152

2026-11-14 · Build agent · A project is a cause with extra fields

Project fields are saved by `identity.set_cause_project`. `identity.create_cause` and `identity.edit_cause` keep their signatures, so other work does not have to change its calls. The projects page introduction lives in the translation catalogue. A new `site_pages` slug would rewrite the shared page editor. The technology section says running costs are sponsored until a technology project is published. Newsletter signup is not built, because there is no email sender (the same gap as D-145). Options: extend the cause functions; add a project-only save. Reason: the cause functions are shared, and the projects page only needs the extra columns (REQ-PUB-001, REQ-DON-013).

## D-153

2026-11-14 · Build agent · Platform running costs stay a sample draft

The Markaz seed includes a draft cause `platform-running-costs`. It is ongoing, monthly, Zakat off, listed as a technology project, and the wording is marked as sample. It is not on the public projects page until an admin publishes it. Options: publish a real appeal; leave a draft. Reason: the running-cost figures are not confirmed, and a draft lets the principal replace the sample text before anyone sees it (P4-E4, REQ-DON-013).

## D-154

2026-11-14 · Build agent · Expected pledges are a finance list, not a public form

`identity.refresh_expected_pledges` is for a finance or admin session. It lists active pledges with no recorded payment in the current Asia/Karachi period, and it lapses a pledge after three missed periods, because there is no scheduled-job credential. The screen does not create pledges. Public pledge creation, and linking a transfer from the donate page, stay out until Q-08 is approved. Options: a cron job; lapse when staff open the list. Reason: the list has to be right when staff look at it, and a job would need a credential this release does not have (REQ-DON-003, admin side only).

## D-155

2026-11-14 · Build agent (REQ-DPR-005) · A public donor profile is addressed by `donors.public_ref`

The public page is `/{lang}/donors/{public_ref}`. The reference is the same ten-character alphabet as a donation's `public_ref`, generated in the database, and it is not derived from the display name. Options: a slug of the display name; a random public reference. Reason: two donors may choose the same display name, and renaming the profile must not change the address.

## D-156

2026-11-14 · Build agent (REQ-ROL-006) · The all-needs screen previews the same FIFO split it saves

`identity.preview_all_needs_split` walks the unallocated pool in credit-date then receipt-number order and does not lock the pool. Saving calls `app.split_all_needs`, which takes the lock and writes the allocations. There is no reverse-split function, so the screen does not offer one. Options: a separate preview allocator; call the same order the save uses. Reason: a preview that disagrees with the save would place different gifts than the administrator just confirmed.

## D-157

2026-11-14 · Build agent (REQ-TRL-012) · A weekly spending report covers seven days, inclusive

A daily report has equal start and end dates. A weekly report ends six days after it starts. A custom report may use any end date on or after the start. Publishing calls `app.publish_spending_report`, which writes one `reported` event per donation for the matched total. Options: any date range the table check allows; a fixed seven-day week. Reason: the table only requires the end to be on or after the start, and a week the staff can explain is seven days.

## D-158

2026-11-14 · Build agent (REQ-TRL-008, REQ-TRL-009, REQ-DPR-006) · Public trails live at `/{lang}/trail/{public_ref}`

The private guest page stays `/{lang}/trail` and remains `noindex`. A trail that is not public answers 404. The donor and a guest-link holder may name a gift or make its trail public, and may turn either choice back. Staff may only make a named gift anonymous or a public trail private, and that change is audited. Recording still starts anonymous unless the person recording ticks the name. Options: publish the private `/trail` page; add the public reference as its own path. Reason: the private link must stay unlisted, and staff must not be able to put a donor's name on the wall.

## D-159

2026-11-14 · Build agent (REQ-DPR-005) · A public profile shows an initial until file storage exists

Profile photos and receipt photos stay off the public pages. The profile shows the first character of the display name and says that a photo waits on file storage. Links must be `https` and are rendered `nofollow`. The profile lists only gifts that are not anonymous, and a public profile may be empty. The anonymity scan allows the chosen display name and still rejects the legal name, email, phone, bank reference and gift type. Options: block public profiles until object storage exists; publish the name and links now. Reason: object storage is not configured, and the name and links do not need it.

## D-160

2026-11-14 · Build agent (REQ-STU-010) · First login keeps the password step, then a saved walkthrough

Students get eight screens and teachers get four. Progress is `users.onboarding_step` (1–8) and `users.onboarding_skipped` (`name`, `avatar`, `bio`). `onboarded_at` is set when the walkthrough finishes or the last screen is skipped. Replay from the account page clears those fields. A new teacher invitation leaves `onboarded_at` empty; people who already finished login are not sent back through it. Donors get no walkthrough. An admin sees a checklist of records that already exist (name, logo, bank, contact, cause, teacher), not a stepper. Each English screen is 30 words or fewer. The hub has no separate bottom tab, so the last student screen names Class, Madrasa and Account. The bio limit stays 160 characters (D-130). Options: a client-only tour; store the step on the user. Reason: a student who leaves halfway should return to the same screen, and the checklist must not invent a phone number or a bank.

## D-161

2026-11-14 · Build agent (REQ-STU-002, REQ-STU-003) · Pen names use a preset, not a photo

The avatar is `personas.avatar_preset` 1–24, drawn from theme colours. `avatar_media_id` stays for a later file store. A pen name is 3–24 characters, unique ignoring case, and rejected when it is a phone or email, an insult, or a real-name word of three letters or more. A bio is optional, at most 160 characters, and uses the same contact and real-name checks with a four-letter word. Past names are kept in `app.persona_names`. The student can rename once every 30 days through the hub functions. A teacher of that student, or an admin, can reset the name and clear the wait. Options: upload a face photo; use 24 patterns. Reason: there is no object storage, and a photo of a child is outside the safety rules (REQ-CHS-001).

## D-162

2026-11-14 · Build agent (REQ-STU-005, REQ-STU-007) · New post types go through one publish function

`identity.start_hub_thread` and `identity.reply_hub_thread` still accept only message, question and answer. Polls, articles, video, vlog, audio and slides use `identity.publish_hub_post`. A video or vlog stores an 11-character YouTube id. Audio and slides keep their title and text and set `media_gap`, because a file needs object storage. A poll has 2–6 choices, one choice or several up to the creator's maximum, and closes between one hour and 30 days. Results show after voting or after closing. A vote is replaced by deleting the old one and inserting the new one. Editors are not hub sessions, so they cannot vote. Students cannot post a link or contact details. Options: add the types to the old functions; add one function. Reason: the older tests keep their contract, and the new rules stay in one place.

## D-163

2026-11-14 · Build agent (REQ-TCH-001 to REQ-TCH-004) · A teacher submits; an editor or another admin publishes

A lesson is an article, video, audio or slides post. A resource is an article or slides post. The public profile is `public_name`, `public_role` and `public_bio` in Urdu and English, with no photo until storage exists. A teacher sends a published class or madrasa post to public review. They cannot approve their own work. An admin's own hub item is published by `app.posts_moderation` when they ask, and the audit log records `posts.published_public`. A verified article is written by the teacher, may quote a post by its pen name, and is stored by `app.make_verified_article`. Options: let a teacher publish their own lesson; keep the existing review. Reason: 07 §10 already says a teacher does not approve their own work, and the public page already shows the verified mark.

## D-164

2026-11-14 · Build agent (REQ-STU-009) · Leaving moves the student into one alumni class

An admin marks a student left. Open class memberships end, the persona stays active, and the student joins the institute's one alumni class (`classes.kind = alumni`). They can post in that class and in the madrasa. They cannot post in a class they have left. Past posts stay. A teacher of a past class can still trace them, because `app.is_teacher_of` already includes ended memberships. Changing status revokes the current sessions, so the student signs in again. Options: delete the account; keep the persona and add one alumni class. Reason: the plan says the account and the pen name stay, and child-safety checks still apply.

## D-165

2026-11-14 · Build agent · Staff record parent consent without a guardian account, Sami may reverse

REQ-CHS-006 is a staff form. Teachers record `public_work`, `real_name` and `face` for students they teach; an admin may record those for any student. A record that is not about an orphan is active as soon as it is saved, which is how `app.consent_status` already reads it. Full-profile consent stays with the principal (D-166). The paper scan stays empty: `form_media_id` needs a private upload, and that storage does not exist yet (D-146). The guardian list gains `principal`, because 07 §5.1 names the principal as the orphans' guardian and the old check only allowed father, mother, guardian and other. Notes and the guardian's name are refused when they contain a phone number, email address or social link. Options: a guardian login; a staff form with no scan. Reason: the requirement says there is no guardian account, and a scan without private storage would put a child's form on a public address (00 §4 rule 9).

## D-166

2026-11-14 · Build agent · The principal assigns the second sign-off, Sami may reverse

REQ-ORP-004 is the principal, who is the admin named in `institute_settings.principal_user_id`. That person opens full-profile consent, assigns any active teacher, and signs. Another admin can still match a sponsor, and cannot assign or open that consent. The assigned teacher signs from the consent page even when they are not an admin, so the control is not only on the sponsorship board. A non-withdrawn full-profile record blocks a second one for the same sponsorship (`already`). Options: any admin assigns; only the principal. Reason: 07 §5.1 makes the principal the guardian, and a second admin should not sign in their place (00 §4 rule 9).

## D-167

2026-11-14 · Build agent · The staff inbox stays with admins, Sami may reverse

REQ-ORP-007's sponsor message already exists (D-141, D-146). The staff inbox is the missing half. D-141 still holds: only an admin reads and replies, because there is no table of chosen teachers. Opening the sponsorship board marks `to_madrasa` messages read. A reply is `to_sponsor`, in Urdu or English, and `app.has_contact_details` blocks a phone number, email address or social link. A child is never the sender or the recipient. Teachers do not see the inbox. Options: let every teacher of the child read the thread; admins only. Reason: messages about an orphan should reach as few people as possible until the admin can choose (D-141, 00 §4 rule 9).

## D-168

2026-11-14 · Build agent · Progress notes are text, and sponsors read them, Sami may reverse

REQ-ORP-008 lets an admin or a teacher of the child write a progress note for a sponsorship that has not ended. The note is Urdu, English, or both. An admin's note is published by the existing trigger. A teacher's note waits until an admin publishes it (06 §12.3). The note is refused when it contains the child's real name or contact details. There is no photograph: private media storage does not exist yet (D-146), and the insert has no `media_id`. Sponsors already read published notes on their page. They do not write them; the row policies and 06 §12.3 give writing to staff. Options: a sponsor composer; staff write and sponsors read. Reason: the requirement names the admin and the teacher, and a photo without private storage would expose a child (00 §4 rule 9).

## D-169

2026-11-14 · Build agent · Hide, remove, takedown and widening follow the moderation trigger, Sami may reverse

The staff queue could only approve or reject a public request. Hide sets `hidden_at` and can be undone. There is no `removed` column. Remove, for a class or madrasa post, and takedown, for a public post, both set `moderation_state` to `taken_down`, which is the only transition that hides the post from its author. The public states shown are draft, submitted, approved, published and taken down. Restoring a public post returns it to `submitted` for a fresh approval; any other post returns to `published`. The trigger allows only an admin to restore, which is stricter than the permission matrix, so a teacher is not offered restore. The trigger also refuses an editor or a finance officer a takedown, so the queue does not offer them one either. Widening is still an approval of a submitted request whose target is `madrasa`. An admin can mark a teacher with `user_roles.can_widen_scope`. That flag is not a new role, so changing it does not end the teacher's session. A teacher without the flag cannot approve a madrasa request. Visitor reports (REQ-MOD-005, REQ-MOD-008) stay out of this queue. Options: add a `removed` column; use the takedown the trigger already enforces. Reason: a second column would disagree with the trigger, and the trigger is the safety boundary (00 §4 rule 9).

## D-171

2026-11-14 · Build agent · Giving, cause, trail, hub and sponsor interface text lives in the message catalogues

The six `*-copy.ts` modules no longer store sentences. They read `packages/i18n/messages/{en,ur}/donate.json`, `causes.json`, `trail.json`, `hub.json` and `sponsor.json`. The catalogue test fails when a key exists in only one language. REQ-LNG-002 stays open: sample campus alt text and a few authentication error sentences are still in code, and the literal-string lint rule from [03 §7.3](03-architecture.md) is not added. Options: leave the sentences in the TypeScript modules; move them into the catalogues now. Reason: REQ-LNG-002 says interface text belongs in the translation files, and moving these modules does not change what a visitor reads.

## D-172

2026-11-15 · Sami · Premium design rules replace the bans on gradients, motion and photographs

Sami asked for a redesign that looks premium to donors in Pakistan and abroad while staying fast. The bans in 02 §4 and PD-02-07 are withdrawn and replaced by the rules in [02 §4.1](02-design-ui-ux.md#41-premium-and-trust-cues-added-2026-11-15-d-172): photography first (real campus photographs preferred, credited sample photographs allowed with a visible *Sample* label, never a child's face, never framed as the institute); token-mixed gradients and one glow on navy surfaces; CSS-only purposeful motion with hard time limits and full `prefers-reduced-motion` support; editorial serif display type with an italic weight; sourced impact numbers; a trust strip under the hero; a Donate pill visible at every width; and a first-load budget of 350 KB with a 3-second 4G and 5-second slow-3G target. Options: keep the bans; drop all rules; replace them with context-fit rules. Reason: the bans made the site read as plain, and donors judge trust partly on finish. The new rules keep the honesty and speed goals the bans were protecting.
