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
| D-038 | PD-02-07 | [02](02-design-ui-ux.md) | No stock photos, and no generated images of the madrasa or of children, are used as placeholders. | proposed |
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
