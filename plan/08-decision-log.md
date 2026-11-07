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
