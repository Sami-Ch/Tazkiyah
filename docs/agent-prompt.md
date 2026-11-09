# Agent prompt v2: Tazkiyah, starting with Markaz Al Azeem

The prompt has two parts. Part A is the overall brief that every agent reads. Part B is a sector brief for each sub-agent. A sub-agent gets Part A plus its own sector brief. The step 1 answers at the end are part of the brief and override anything above them.

## Part A: Overall brief (every agent reads this)

### A1. Role

You are a senior product architect and technical program manager. You are planning, not building. Your output is planning documents that developers and AI agents will use later. Do not write application code.

### A2. The project

The first institute is **Markaz Al Azeem** (مرکز العظیم), part of **Jama Masjid Al-Azeem**, 92/6-R Road, Sahiwal, Punjab, Pakistan, founded in 2019. Its domain is **azeem-lateef.com**. It has about 50 students, all under 18 (45 residential, 5 of them orphans), and 8 staff. It runs a free daily lunch for 100 people and a clinic that sees about 25 patients a day. Its prayer hall holds 1,000 people, and its yearly running budget is roughly Rs 6.6 million. The principal, Moazam, is the main admin and the guardian of the orphans.

The platform is called **Tazkiyah** (تزکیہ), from the Quranic idea in 62:2 of purifying people and teaching them. The word shares its root with Zakat, linking giving and education.

The website does three things:

1. Takes donations, with a full donation trail.
2. Gives students a community hub to publish and interact.
3. Gives teachers a hub to publish verified knowledge.

### A3. Long-term vision (design for it, do not build it)

This madrasa is the first user of a future platform for many Pakistani madrasas and non-profit student institutes. Later, these institutes will share a community where published work can be read across madrasas (with the source madrasa shown), with friendly competition and online education. A central platform fund may later pass donations on to member institutes.

**This plan covers only this madrasa's website.** It must be built so the platform can be added later without a rebuild:

- Every record carries an `institute_id`. For now there is one institute.
- Institute settings (name, logo, colours, payment accounts, domain) are stored as data, not in code.
- Features are switchable modules.
- Do not plan institute signup, a super-admin area, billing or the central fund. Only keep the design ready for them.

### A4. Decided stack and constraints

- Next.js, Postgres on Neon (free tier), hosted on Cloudflare. The domain and email already exist.
- The main developer is Sami, working pro bono with AI agents. The stack must be maintainable by one developer.
- One shared database. Separation between institutes is enforced by Postgres row-level security.
- Each institute uses its own domain. Platform subdomains come later.
- Fully bilingual in Urdu and English (see Localization below). It must work on low-end phones and slow connections.
- Running costs are sponsored for now. Future tech costs (developers, servers, database) will be raised as causes with their own trail.

**Localization.** The whole site works in both Urdu and English from Phase 1.

- All interface text exists in both languages: menus, buttons, forms, error messages, the onboarding walkthrough, emails, receipts and the admin area.
- No interface text is hard-coded. Strings live in translation files, so a third language can be added later without code changes.
- A language switch sits on every page. The site remembers each user's choice, and new visitors start in their browser's language.
- Urdu pages run right to left and English pages left to right, with the layout mirrored. Mixed text, such as English names or numbers inside Urdu, displays correctly.
- Each language has its own URL, for example `/ur/causes` and `/en/causes`, so search engines index both.
- Fixed admin content (cause pages, project pages, about pages) has an Urdu and an English version. A missing translation falls back to the other language with a small notice.
- Community posts are written in whichever language the author chooses, and each post records its language.
- Amounts show in rupees and dates in each language's own format.
- If the browser gives no language preference, the site opens in English.

### A5. Core and modules

- **Core:** accounts and roles, donations and trail, public pages, admin area.
- **Switchable modules:** student hub, teacher hub, new projects page.
- **Future modules (do not plan in detail):** clinic or hospital records, open canteen, development funding, online education.

### A6. Not in this version

Admissions, student fee collection, attendance, online classes, clinic patient records, and anything for multiple institutes beyond the `institute_id` foundation.

### A7. Documents to produce

```
/plan
  00-MASTER-PLAN.md
  01-requirements-checklist.md
  02-design-ui-ux.md
  03-architecture.md
  04-database.md
  05-public-pages-roles-admin.md
  06-donations-and-trail.md
  07-content-hub-student-teacher.md
  08-decision-log.md
```

### A8. How the work runs

1. **Step 1, questions (main agent).** List at most 10 questions whose answers would change the plan. **Stop and wait for answers.** Do not assume defaults and do not continue until they are answered.
2. **Step 2, master plan (main agent).** Write `00-MASTER-PLAN.md`, `01-requirements-checklist.md` and `08-decision-log.md`. The master plan links to every specialist document and holds the glossary.
3. **Step 3, specialist documents (sub-agents).** One sub-agent per document from 02 to 07. Each one gets Part A plus its sector brief from Part B, reads the master plan, checklist and glossary first, and writes only its own document.
4. **Step 4, consistency check (main agent).** Check every requirement ID against its task and document, make sure terms are used the same way everywhere, and fix contradictions in the lower document.

### A9. Master plan contents

1. Summary, goals and non-goals (A6).
2. A document map, with the rule: "If two documents disagree, the master plan wins, and the specialist document is fixed."
3. A work hierarchy of Phase, Epic and Task. Every task has an ID such as `P2-E3-T04`, an owner document, a status, dependencies and requirement IDs.
4. The agent rules (A11), word for word.
5. A phased roadmap where each phase ends in something testable. Phase 1 includes accounts, public pages, and a one-off donation by bank transfer to one cause, recorded manually.
6. Risks and open questions, each with an owner and a due phase.
7. A glossary: institute, cause, campaign, donation, allocation, trail, donor, persona, thread, verified article, module.

Keep it under about 3,000 words by linking out.

### A10. Checklist format

- Group requirements by: Donations, Trail, Donor profiles, Orphan sponsorship, Student hub, Teacher hub, Public pages, Roles and admin, Payments, Security and privacy, Child safety, Performance, Accessibility, Language, Moderation, Multi-institute readiness.
- Write one testable sentence per line, for example `- [ ] REQ-DON-012 Donor can make a donation trail public. MUST → 06 §4`.
- Mark each line MUST, SHOULD or LATER, and point it to its document and section. Use no sub-bullets.

### A11. Agent rules (put these in the master plan word for word)

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

### A12. Quality bar

- Use plain language. A new developer should understand any document without asking.
- Be concrete: names, fields, states and numbers.
- Every task should take one working session.
- Link to other documents instead of repeating them.
- Give schemas, diagrams, tables and examples only, with no production code.
- Every specialist document includes: purpose, scope and out of scope, decisions with reasons, requirement IDs covered, tasks in master-plan format, and acceptance criteria.

## Part B: Sector briefs (one per sub-agent)

### B1. Design, UI and UX (02-design-ui-ux.md)

- **Branding:** use the madrasa's [Markaz Al Azeem Emblem](<../assets/logo/Markaz Al Azeem Emblem.png>) with a **new colour scheme designed for this madrasa**. Store colours as theme settings per institute, so each future institute can have its own. Sami confirmed the exact source image in [D-108](../plan/08-decision-log.md#d-108).
- Propose two visual directions that are dignified, calm and trustworthy, and recommend one. Give palette contrast ratios that meet WCAG AA.
- Typography for Latin and Urdu (Nastaliq or Naskh choice with reasons), plus RTL layout rules that follow the Localization rules in A4.
- Mobile-first rules for low-end phones and slow connections, including image and video sizes.
- **Onboarding walkthrough** for new users, especially students on first login.
- UX flows: donating (local and international), viewing your own trail, choosing Zakat, sponsoring an orphan, posting in a thread, creating a poll, asking a question, and a teacher turning a thread into a verified article.
- There are no photos or videos yet, so design with placeholders that work well before media arrives.

### B2. Architecture (03-architecture.md)

- Next.js on Cloudflare, Postgres on Neon, both on free tiers. Plan within free-tier limits and note when an upgrade would be needed.
- Payments, in order: **Phase 1** is bank transfer recorded manually by the admin. **Once legal registration finishes** (it is in progress), add international card payments for one-off and automatic recurring donations, and JazzCash and Easypaisa for one-off donations.
- Multi-currency display for overseas donors.
- Media storage for images, audio, video and slides, with compression for slow connections. Cap upload sizes to stay within free-tier storage and bandwidth, and support linking or embedding videos from YouTube as an alternative to uploading them.
- Authentication with roles. Students cannot sign up themselves: a teacher or admin creates the account.
- Background jobs for card recurring charges, monthly reminder or newsletter emails, and receipts.
- Email first. Treat SMS as optional and low priority.
- Backups, monitoring, security, environments, and row-level security setup.
- Domain handling: each institute uses its own domain, chosen by matching the request domain to the institute.

### B3. Database (04-database.md)

- `institute_id` on every table, with row-level security policies.
- Institute settings as data: name, logo, theme colours, domain, payment accounts, enabled modules.
- **Donation trail:** an append-only event table (received, allocated, spent, reported). Spending is matched to donations **first in, first out**: the oldest unspent donations in a cause pay first, and one spend can draw on several donations.
- Design allocations so that a future "platform fund to institute" transfer fits without changing the schema.
- Donation types: Zakat, Sadaqah and general, kept separate. Each cause has an admin-set `accepts_zakat` flag and an optional "approved by" scholar name.
- Donor anonymity and public or private flags enforced at data level. Guest donors are stored with an email and a private trail-link token, and can later be linked to an account.
- **Student personas:** each student has an anonymous persona linked privately to their real identity. Only the student's teachers and admins can see the link. The real identity is revealed only by the student's choice, with consent.
- **Orphan sponsorship:** a sponsor is matched to one child. A consent record controls whether the full profile is visible, with two sign-offs (the principal plus a second person), and consent can be withdrawn.
- Light consent records for students' parents, entered by staff.
- Content: posts (message, question, answer, poll, article, video, vlog, audio, slides), threads, sharing scope (class, institute, and later community), moderation state, verified flag.
- Migrations, indexes, retention, and an ER diagram.

### B4. Public pages, roles and admin (05-public-pages-roles-admin.md)

- Sitemap: about, facilities, daily life, causes, new projects, donor wall, student work, teacher work, contact.
- Roles: visitor, donor, student, teacher, editor, finance officer, admin. There are no guardian logins.
- Permission matrix of role by action.
- The admin (principal) manages causes, sets Zakat rules per cause, decides how "all needs" donations are split, and records spending with receipts as daily or weekly reports, whichever he prefers.
- Either the class teacher or the principal can approve student work for public view.
- Admin screens: causes, donation recording and reconciliation, spending entries, consent records, user and persona management, moderation queue, audit log.
- **New projects page:** the madrasa can announce new initiatives as causes, including future tech costs.

### B5. Donations and trail (06-donations-and-trail.md)

- Donors can give to a specific cause or to "all needs". The admin decides how "all needs" money is split.
- Frequency: one-off, or recurring monthly or yearly. **Recurring payments are by card only.** JazzCash and Easypaisa donors make one-off gifts and can opt in to a monthly reminder or newsletter with updates and new projects.
- Cause types: one-time campaign, ongoing recurring, yearly stock.
- The trail lifecycle works first in, first out, as described in B3. The donor always sees their own trail. Whether it is public is the donor's choice and defaults to private. Aggregated spending per cause is always public, without donor identity.
- Donor identity: anonymous, or a public profile with display name, photo and links. Each donation is public or anonymous separately. Guest donations are allowed: a donor can give without an account by entering an email, and gets a private link to their trail. They can create an account later and claim those donations.
- When a donor chooses Zakat, only Zakat-eligible causes are offered, and the money is ring-fenced.
- **Orphan sponsorship:** anonymous by default (persona name, age and progress updates). A full profile shows only with guardian consent and two sign-offs, only to that one sponsor and never publicly. There is no direct sponsor-to-child contact, so messages go through the madrasa.
- Failure, refund and reconciliation handling, plus receipts. Note that tax-deductible receipts depend on registration.

### B6. Content hub (07-content-hub-student-teacher.md)

- The hub is an **interactive community with threads**, not just a blog. Post types: short messages and concerns, questions with answers, polls, articles, videos, vlogs, audio and slides.
- Sharing scopes: class, whole madrasa, and later the multi-institute community. Admins or chosen teachers decide what is shared more widely.
- Teachers can **turn a thread into a verified article**, marked as authentic knowledge.
- Students post under their anonymous persona by default. Personas are always traceable by admins and the student's teachers.
- Student accounts are created by a teacher, then personalised by the student. Keep student login and posting simple, with no extra consent steps for students.
- Posts within the class or madrasa appear straight away, with no approval step. Teachers and admins can see and manage all of them, including hiding or removing a post. Making a post public, or publishing it as an article, needs approval from the class teacher or the principal. Moderation states for public posts: draft, submitted, approved, published, taken down. Include a report button and fast takedown.
- Child safety: teachers can see student-to-student posts and replies. Faces and full names are hidden by default. No personal contact details are allowed.
- Teacher publishing goes through a simple editor or admin review before going public.

## Step 1 answers (7 November 2026)

These answers come from Sami and override anything above where they differ.

1. **Name and domain:** Markaz Al Azeem (Jama Masjid Al-Azeem, Sahiwal); domain `azeem-lateef.com`.
2. **Existing website:** none. There is no content to migrate.
3. **Second sign-off for orphan consent:** assignable. The principal (Moazam) can assign the second sign-off to any teacher.
4. **Payments:** gateway integration is the last step and stays open. It will be discussed in detail when the project reaches it. Until then, donations are recorded manually.
5. **Donor wall:** donation amounts are public. Each donor chooses whether their name and details show or whether they stay anonymous.
6. **Students who leave:** the account and persona stay live and can keep being used afterwards.
7. **Timeline:** there is no deadline. Work continues until the target is reached.
