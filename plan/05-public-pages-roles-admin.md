# 05 Public pages, roles and admin

**Status:** planning · **Last updated:** 2026-11-07 · **Owner:** Sami · **Institute:** Markaz Al Azeem (`azeem-lateef.com`)

Read [00-MASTER-PLAN.md](00-MASTER-PLAN.md) first. If this document disagrees with it, the master plan wins and this document is fixed. Words such as *cause*, *all needs*, *spending entry*, *trail*, *donor wall*, *persona*, *consent record*, *scope*, *verified article* and *module* have the meanings in the glossary in 00 §8.

## 1. Purpose

This document says which pages Tazkiyah has, what each page shows and to whom, which roles exist, what each role may do, and what the admin screens look like. A developer should be able to build any page or screen from its spec here, plus the logic in 06 and 07, the data in 04 and the visual rules in 02.

## 2. Scope and out of scope

**In scope**

- The sitemap, with `/ur` and `/en` paths for every page.
- A spec for every public page, the donor pages, the sponsor area, the content hub entry page and the admin area.
- The seven roles, who holds them at Markaz Al Azeem, and the markers that sit on top of roles (principal, assigned second signer, scope widener, class teacher, sponsor).
- The permission matrix: one table of role by action.
- Admin screens: fields, actions, states and the phone-first form rules.
- The audit log: what is written, the screen, filters, who sees it and what is never stored.
- The new projects page.

**Out of scope (owned elsewhere)**

- Donation lifecycle, FIFO matching, Zakat ring-fencing, the all-needs split logic, receipts and reversals: 06.
- Threads, post types, scopes, moderation states, verified article rules, media and child-safety rules: 07.
- Table columns, row-level security and retention: 04. Column names in this document are indicative; 04 is final.
- Login mechanics, sessions, two-factor, caching, email sending, upload compression: 03.
- Colours, type, components, RTL rules, placeholders and the walkthrough: 02.
- Online payments (P5), institute signup, a super-admin area, billing, the central fund, the cross-institute community, admissions, fees, attendance and clinic records (00 §1).
- A public contact form. The contact page uses links only, so no visitor messages are stored in this version.
- Guardian logins of any kind (REQ-ROL-003, [D-016](08-decision-log.md#d-016)).

## 3. Decisions

Decisions already in the log that shape this document:

| ID | What it means here |
| --- | --- |
| [D-001](08-decision-log.md#d-001) | Every page reads the institute from the request domain and every query carries `institute_id`. Nothing on a page names Markaz Al Azeem in code; it comes from `institute_settings`. |
| [D-007](08-decision-log.md#d-007) | Every page, including the admin area, exists under `/ur` and `/en`. |
| [D-008](08-decision-log.md#d-008), [D-025](08-decision-log.md#d-025) | The donate page shows bank details and a transfer notice form. There is no online payment button until P5. |
| [D-009](08-decision-log.md#d-009) | A guest can give with only an email. There is a guest trail link page that needs no login. |
| [D-010](08-decision-log.md#d-010) | The donor wall always shows amounts. It shows a name only where the donor chose that. |
| [D-011](08-decision-log.md#d-011) | Only the admin sets `accepts_zakat` and the optional scholar name on a cause. |
| [D-012](08-decision-log.md#d-012) | Only the admin splits all-needs money. |
| [D-013](08-decision-log.md#d-013) | The spending screen works in daily or weekly batches, set in institute settings. |
| [D-014](08-decision-log.md#d-014) | No public sign-up for students. Teachers and admins create student accounts. |
| [D-015](08-decision-log.md#d-015), [D-028](08-decision-log.md#d-028) | Public student work shows personas only. A student who leaves keeps an active account and persona; leaving ends a class membership, not the account. |
| [D-016](08-decision-log.md#d-016) | Consent is a staff-entered form. No guardian role exists. |
| [D-017](08-decision-log.md#d-017) | The sponsor area shows persona name, age and updates. The full profile shows only with two sign-offs; the principal assigns the second signer to any teacher. |
| [D-019](08-decision-log.md#d-019) | Class and madrasa posts never pass through the moderation queue. Public requests do. |
| [D-021](08-decision-log.md#d-021) | The clinic appears on the facilities page and as a cause only. |
| [D-027](08-decision-log.md#d-027) | A takedown must clear public pages within one minute (proposed target). |

New decisions made in this document. They are not yet in 08 and are logged there in step 4.

| ID | Decision | Reason |
| --- | --- | --- |
| P05-01 | URL slugs are the same English words under both prefixes, for example `/ur/causes` and `/en/causes`. Cause slugs are stored once per cause. | Matches the example in the brief (A4), keeps links shareable across languages, and avoids Urdu characters in URLs that break in some messaging apps. |
| P05-02 | The admin area is a set of pages under the language prefix (`/ur/admin`, `/en/admin`) and is fully translated. | The brief requires the admin area in both languages, and the principal may prefer Urdu. |
| P05-03 | A user can hold several roles in `user_roles`. Their permissions are the union of their roles. | A teacher may also be the editor. Staff who give money hold the donor role on the same account. |
| P05-04 | *Principal*, *assigned second signer*, *scope widener*, *class teacher* and *sponsor* are markers on top of roles, not roles. The principal is the one admin named in `institute_settings` (Moazam today). | The requirements give special powers to "the principal" (REQ-MOD-003, REQ-ORP-004) that not every future admin should have. A marker keeps the seven roles of REQ-ROL-001 unchanged. |
| P05-05 | The finance officer records, confirms and reverses donations, records spending entries and publishes reports. They do not change causes, Zakat rules or the all-needs split. Pending Q-03. | D-011 and D-012 give Zakat rules and the split to the admin. Recording is the heavy, repeatable work that is worth handing on (R-03). |
| P05-06 | The editor edits fixed page text and cause text and reviews teacher work. They cannot approve student work, change money fields or see the persona-to-student link. Pending Q-03. | REQ-TCH-004 names the editor for teacher work. REQ-MOD-003 and REQ-SEC-007 keep student approval and the persona link with teachers and admins. |
| P05-07 | Staff can always make something more private: make a donation anonymous, make a trail private, take down a public post. Only the donor can make their own donation named or their trail public, and only approvers can restore a taken-down post. | Agent rule 8 (privacy wins) and rule 9 (child safety wins). Making things more private is never harmful, so it should never wait. |
| P05-08 | The donor wall does not show the donation type (Zakat, Sadaqah or general). | D-010 makes amounts public, not types. Showing that a named person paid Zakat reveals more than they agreed to. |
| P05-09 | The audit log never stores a donor's name or email, or a student's real name. It stores internal references and resolves safe labels when the screen is drawn. | A donor can switch a donation to anonymous later. If names were stored, old log entries would leak them (REQ-DPR-009, REQ-SEC-008). |
| P05-10 | The donate page has a short "Tell us about your transfer" form. It creates an unconfirmed transfer notice that the admin or finance officer confirms against the bank. The state names are set in 06 §4. | With manual recording, this is how a guest "gives by entering only an email" (REQ-DPR-001) and how the donor's choices (cause, type, name or anonymous) reach the admin without a phone call. |
| P05-11 | A new project is a cause with "Show on new projects page" turned on. There is no separate projects table. | The brief says new initiatives are causes. Reusing causes gives projects the trail, Zakat rules and donor wall for free (REQ-DON-013). |
| P05-12 | When a module is off, its pages return "not found", its menu items and home blocks disappear, and its data stays untouched. | Switching a module back on must restore everything. Hiding is safer than deleting. |
| P05-13 | Fixed page text (home intro, about, facilities, daily life) is stored as bilingual content in `site_pages` (04 §5), with photos in `media_assets`. Settled in the consistency check. | The shared table list has no pages table, and this text is per institute, rarely changes and is small. |
| P05-14 | Any staff role can take down a public post at once. | Fast takedown is a child-safety control (REQ-CHS-004, R-04). A wrong takedown costs little and is restored by an approver. |
| P05-15 | New causes start with `accepts_zakat` off. The admin must turn it on per cause. | R-05: an ineligible cause receiving Zakat is the worse error. |

## 4. Sitemap

Every page exists under both prefixes. The table shows the path once, after the prefix: `/{lang}` is `/ur` or `/en`. Paths never carry personal data (REQ-SEC-005). Tokens and references in paths are opaque random strings, not emails, names or sequential numbers.

**Public pages**

| Page | Path after `/{lang}` | Example | In main menu | Module | Phase |
| --- | --- | --- | --- | --- | --- |
| Home | `/` | `/ur`, `/en` | Logo | Core | P1 |
| About | `/about` | `/ur/about` | Yes | Core | P1 |
| Facilities | `/facilities` | `/en/facilities` | Under About | Core | P1 |
| Daily life | `/daily-life` | `/en/daily-life` | Under About | Core | P1 |
| Causes list | `/causes` | `/ur/causes` | Yes | Core | P1 |
| Cause page | `/causes/{slug}` | `/en/causes/wheat-stock` | No | Core | P1 (spending section P2) |
| Donate | `/donate` and `/donate/{slug}` | `/ur/donate/wheat-stock` | Button on every page | Core | P1 |
| Contact | `/contact` | `/en/contact` | Yes | Core | P1 |
| Donor wall | `/donor-wall` | `/ur/donor-wall` | Yes | Core | P2 |
| Public trail of one donation | `/trail/{public_ref}` | `/en/trail/k7Qm2xPa` | No | Core | P2 |
| Donor public profile | `/donors/{handle}` | `/en/donors/abdullah-k` | No | Core | P2 |
| Student work list | `/student-work` | `/ur/student-work` | Yes | Student hub | P3 |
| Student work item | `/student-work/{post_ref}` | `/ur/student-work/r4Tz9` | No | Student hub | P3 |
| Teacher work list | `/teacher-work` | `/en/teacher-work` | Yes | Teacher hub | P3 |
| Teacher work item | `/teacher-work/{post_ref}` | `/en/teacher-work/b8Lw1` | No | Teacher hub | P3 |
| New projects | `/projects` | `/ur/projects` | Yes | New projects | P4 |
| Not found | any unknown path | | No | Core | P1 |

**Pages for signed-in people and link holders** (all `noindex`)

| Page | Path after `/{lang}` | Who | Phase |
| --- | --- | --- | --- |
| Login | `/login` | Anyone | P1 |
| Create donor account | `/signup` | Visitors | P1 |
| Guest trail link page | `/my-trail/{token}` | Holder of a valid guest token | P1 |
| Account | `/account` | Any signed-in user | P1 |
| My donations | `/account/donations` | Donor | P1 |
| One donation's trail | `/account/donations/{donation_ref}` | Donor who owns it | P1 (*spent* and *reported* events from P2) |
| Sponsor area | `/account/sponsorship` | Donor with an active sponsorship | P4 |
| Content hub entry | `/hub` | Student, teacher, editor, admin | P3 (inner hub pages: 07) |

**Admin area** (all `noindex`, staff roles only, menu items shown per role; see §8)

| Screen | Path after `/{lang}` | Phase |
| --- | --- | --- |
| Dashboard | `/admin` | P1 |
| Causes | `/admin/causes`, `/admin/causes/new`, `/admin/causes/{id}` | P1 |
| Donations and reconciliation | `/admin/donations`, `/admin/donations/new`, `/admin/donations/notices`, `/admin/donations/reconciliation`, `/admin/donations/{id}` | P1 |
| All-needs split | `/admin/all-needs` | P2 |
| Spending entries and reports | `/admin/spending`, `/admin/spending/{batch_id}`, `/admin/reports` | P2 |
| Consent records | `/admin/consent`, `/admin/consent/{id}` | P3 (orphan sign-offs P4) |
| Sponsorships | `/admin/sponsorships` | P4 |
| Users | `/admin/users`, `/admin/users/new`, `/admin/users/{id}` | P1 (students from P3) |
| Classes and personas | `/admin/classes`, `/admin/classes/{id}`, `/admin/personas` | P3 |
| Moderation queue | `/admin/moderation` | P3 |
| Site pages | `/admin/pages` | P1 |
| Audit log | `/admin/audit` | P1 |
| Institute settings and modules | `/admin/settings`, `/admin/settings/modules` | P1 |

**Menu order** (visual treatment in 02 §7): Home (logo), About (with Facilities and Daily life), Causes, New projects, Donor wall, Student work, Teacher work, Contact. A Donate button and the language switch sit on every page (REQ-LNG-003). A Login link, or the account menu when signed in, sits beside them. Menu items for a module that is off, or a phase not yet shipped, are not shown.

**Search engines:** public pages carry `hreflang` links to their other-language twin and appear in `sitemap.xml`. Private pages and the admin area are `noindex` and are left out of `sitemap.xml`.

## 5. Page specs

### 5.0 Rules for every page

- The header shows the logo and institute name from `institute_settings` (REQ-PUB-007). The footer shows the address and contact links from the same row.
- Every text block written by staff has an Urdu and an English version. If the version for the page's language is missing, the other is shown with a small notice ("This text is not yet available in English") (REQ-LNG-009).
- Amounts show in rupees, dates in each language's own format (REQ-LNG-012; digit and date style in 02 §8).
- No photo on any public page shows a student's face or full name (REQ-CHS-001). Photo uploads for public pages need a "No student faces or names are visible" tick before they publish (see §8.10).
- Where no photo exists yet, the page uses the placeholder pattern in 02 §14. No page is ever blank because media is missing (open question Q-05).
- Lists are paginated at 20 items, so pages stay light on 3G (REQ-PRF-001).

### 5.1 Home

- **Purpose:** show who the madrasa is, what needs money now, and where money went.
- **Who:** everyone.
- **Blocks in order:**
  1. Hero: logo, institute name, one-line purpose, Donate button.
  2. Active causes: up to 6 cards in admin-set order, each with title, type label, progress bar (raised against target where a target exists) and a Donate link (REQ-PUB-002). "See all causes" link.
  3. Facts strip: students, daily lunches, clinic patients a day, prayer hall size. The numbers are editable text in site pages (§8.10), not computed.
  4. Where the money went: the 3 latest spending entries with cause, date and amount (P2, task P2-E6-T51).
  5. New projects teaser: up to 3 projects (P4, module on).
  6. Student and teacher work teasers: up to 3 items each (P3, modules on).
  7. Donor wall teaser: the 5 latest wall entries (P2).
  8. Contact strip: address, phone, WhatsApp link.
- **Data:** `institute_settings`, `causes`, `donations` (sums), `allocations` (all-needs money placed in a cause), `spending_entries`, `posts`, `media_assets`.
- **Empty states:** no active causes shows "New causes will be announced soon" and the contact strip. Any teaser with nothing to show is left out entirely, not shown empty. No hero photo shows the logo on the theme background.
- **Phase:** P1, with blocks 4 to 7 added in their phases.

### 5.2 About

- **Purpose:** the story and trustworthiness of the madrasa.
- **Who:** everyone.
- **Blocks:** 1. Title and intro. 2. History (founded 2019, part of Jama Masjid Al-Azeem). 3. Mission, including what Tazkiyah means. 4. Message from the principal. 5. Staff in numbers (no staff photos unless the person agrees). 6. Registration status, for example "Legal registration is in progress. Donations are not yet tax-deductible" (REQ-PAY-008). 7. Links to Facilities and Daily life.
- **Data:** site page text in `site_pages` (P05-13), `media_assets`.
- **Empty states:** a missing section is left out. No photos uses placeholders.
- **Phase:** P1.

### 5.3 Facilities

- **Purpose:** show what the money keeps running.
- **Who:** everyone.
- **Blocks:** 1. Intro. 2. One card per facility: prayer hall (1,000 people), residence (45 residential students), kitchen (free lunch for 100 a day), clinic (about 25 patients a day), classrooms. Each card has text, an optional photo, and an optional link to its cause, for example the clinic card to the clinic cause (REQ-DON-014).
- **Data:** site page text in `institute_settings`, `causes` (linked cause), `media_assets`.
- **Empty states:** a card without a photo uses an icon placeholder. A card with no linked cause shows no Donate link.
- **Phase:** P1.

### 5.4 Daily life

- **Purpose:** a day at the madrasa, told without exposing children.
- **Who:** everyone.
- **Blocks:** 1. Intro. 2. A timeline of the day (prayers, classes, lunch, study), edited as rows of time and text. 3. Photo strip (only photos that passed the no-faces tick). 4. Link to student work (module on).
- **Data:** site page text in `institute_settings`, `media_assets`.
- **Empty states:** no photos hides the photo strip and keeps the timeline.
- **Phase:** P1.

### 5.5 Causes list

- **Purpose:** every cause that can take money, at a glance.
- **Who:** everyone.
- **Blocks:** 1. Title and short intro on Zakat, Sadaqah and general giving (link to 06 §6 wording). 2. Filter chips: All, Accepts Zakat, Campaigns, Ongoing, Yearly stock. 3. Cause cards: title, type label, "Accepts Zakat" badge, progress (raised and target, or raised this year for yearly stock), days left for a campaign, Donate link. 4. "Give to all needs" card, always last. 5. Closed campaigns, collapsed.
- **Data:** `causes` with status `active` or `closed` (archived causes are hidden), `donations`, `allocations`.
- **Empty states:** no causes shows "Causes will be announced soon" and the all-needs card. A cause without a photo uses the placeholder for its type.
- **Phase:** P1. Projects also appear here, because they are causes (P05-11).

### 5.6 Cause page

- **Purpose:** everything about one cause, including where its money went.
- **Who:** everyone. Draft causes return "not found" to the public; staff can preview them.
- **Blocks in order:**
  1. Title, type label and photo or placeholder.
  2. Status banner: "Closed on {date}" for an ended campaign (REQ-DON-006), "Archived" for an archived cause.
  3. Money box: target (if set), amount raised, amount spent, and a progress bar (REQ-PUB-003). Amount spent shows from P2.
  4. Zakat line: "Accepts Zakat" or "Does not accept Zakat", and "Approved by {scholar}" where a name is set (Q-04).
  5. Story text.
  6. Donate button. On a closed campaign it is replaced by "Give to all needs" and links to two active causes.
  7. Spending: entries with date, description, amount and receipt photo where the entry's receipt is public, newest first, plus published daily or weekly reports (P2, REQ-TRL-010, REQ-TRL-012). This block never shows a donor's identity.
  8. Recent donations to this cause, as on the donor wall (P2).
- **Data:** `causes`, `donations`, `allocations`, `spending_entries`, `trail_events` (report events), `media_assets`.
- **Empty states:** before any spending, block 7 says "No spending has been recorded for this cause yet." Before any donations, block 3 shows "Rs 0 raised" and the target. No receipt photo shows the entry without a thumbnail.
- **Phase:** P1 (blocks 1 to 6), P2 (blocks 7 and 8).

### 5.7 Donate

- **Purpose:** let anyone give by bank transfer and tell the madrasa about it.
- **Who:** everyone. Signed-in donors get their email and name filled in.
- **Blocks in order:**
  1. Choose: a cause (preselected from `/donate/{slug}`) or all needs (REQ-DON-001, REQ-DON-002).
  2. Choose the type: Zakat, Sadaqah or general (REQ-DON-004). Choosing Zakat narrows the cause list to causes that accept Zakat, and a cause that does not accept Zakat greys out the Zakat option. Ring-fencing rules: 06 §6.
  3. Amount and frequency. Before P5, monthly and yearly are offered as a reminder, not a charge (06 §13).
  4. Bank details from `institute_settings`: bank, account title, account number, IBAN and SWIFT, each with a copy button (REQ-PUB-008). An account may carry a label such as "for Zakat only" if the madrasa keeps one.
  5. "Tell us about your transfer" form (P05-10): email (required), name (optional), show my name on the donor wall or stay anonymous (default from 06 §10), bank reference or last 4 digits of the sending account, date sent, language for emails (defaults to the page language), monthly reminder opt-in (off by default, REQ-PAY-007).
  6. After sending: "Thank you. We will confirm when the money arrives and email you a private link to your donation trail."
  7. "Prefer WhatsApp?" link with the madrasa number, for donors who will not use a form.
- **Data:** `causes`, `institute_settings` (bank accounts), writes an unconfirmed notice to `donations` and a `donors` row for a new email (06 §4, §11).
- **Empty states:** no bank account in settings hides block 4 and 5 and shows contact details instead. The admin dashboard warns about this.
- **Phase:** P1.

### 5.8 Contact

- **Purpose:** how to reach and find the madrasa.
- **Who:** everyone.
- **Blocks:** 1. Address in both languages (92/6-R Road, Sahiwal). 2. Phone and WhatsApp as tap-to-call and tap-to-chat links. 3. Email link. 4. A static map image with a link to open in a map app (no embedded map, to stay light on 3G). 5. Visiting times, if set.
- **Data:** `institute_settings` (REQ-PUB-006).
- **Empty states:** any missing contact field is left out. No map image shows the address with an "Open in maps" link.
- **Phase:** P1.

### 5.9 Donor wall

- **Purpose:** public proof that people give, without forcing anyone to be named.
- **Who:** everyone.
- **Blocks:** 1. Title and a line saying amounts are always shown and names only by the donor's choice. 2. Filters: cause, month. 3. Entries, newest first: date, amount, cause (or "All needs"), and the donor's display name or "Anonymous" (REQ-DPR-007, REQ-DPR-008). A display name links to the donor's public profile if one exists. A "View trail" link shows where the donor made the trail public. 4. Pagination.
- **Data:** confirmed `donations` (not unconfirmed notices and not reversed ones, 06 §15), `donors` (display name only where the donation shows a name), `causes`.
- **Privacy rules:** for an anonymous entry, the page and its data response carry no donor name, no donor ID and no profile link, so anonymous entries cannot be linked to each other or to a person (REQ-DPR-009). The donation type is not shown (P05-08).
- **Empty states:** "The first donations will appear here soon."
- **Phase:** P2 (task P2-E5-T50).

### 5.10 Public trail of one donation

- **Purpose:** let a donor share where one gift went.
- **Who:** everyone, only if the donor made that trail public (REQ-TRL-009). Otherwise "not found".
- **Blocks:** 1. Cause, amount, date, name or "Anonymous" as the donation is set. 2. Trail events in order: received, allocated, spent (with the spending entry and share), reported. Event wording: 06 §8.
- **Data:** `donations`, `trail_events`, `allocations`, `spending_entries`.
- **Empty states:** a trail with only *received* says "This gift has not been spent yet. Spending is matched oldest first."
- **Phase:** P2.

### 5.11 Donor public profile

- **Purpose:** a donor's chosen public face (REQ-DPR-005).
- **Who:** everyone, only if the donor turned on a public profile.
- **Blocks:** display name, photo or initial placeholder, links, and the list of this donor's donations that show their name. Anonymous donations never appear here and are left out of any total, so a total cannot reveal them.
- **Data:** `donors`, `donations` (named only).
- **Empty states:** a profile with no named donations shows the profile and "No public donations yet."
- **Phase:** P2 (task P2-E5-T51).

### 5.12 Student work (list and item)

- **Purpose:** show the best of students' work to the public, safely.
- **Who:** everyone, when the student hub module is on.
- **List blocks:** 1. Intro. 2. Filters: post type, language. 3. Cards: persona name and avatar, post type, title or first line, language tag, date, verified mark where the work became a verified article. Class names are not shown, to keep personas harder to trace.
- **Item blocks:** 1. The post, or the posts of a thread that were approved for public view (never the rest of the thread). 2. Persona name and avatar; a real name only where the student chose it and consent is on record (REQ-STU-004). 3. Report button, open to everyone (07 §8). 4. Link back to the list.
- **Data:** `posts` with scope public and moderation state *published* (REQ-PUB-004), `threads`, `personas`, `poll_options` and `poll_votes` (totals only), `media_assets`, writes `post_reports`.
- **Empty states:** "Student work will appear here once teachers approve it." A post without media shows its text only.
- **Takedown:** a taken-down post disappears from the list, the item page and caches within one minute (D-027); its URL then shows "This item is no longer available."
- **Phase:** P3 (epic P3-E8).

### 5.13 Teacher work (list and item)

- **Purpose:** publish teachers' lessons and verified knowledge.
- **Who:** everyone, when the teacher hub module is on.
- **List blocks:** 1. Intro. 2. Tabs: Verified articles, Lessons and articles, Audio, Video, Resources. 3. Cards: title, teacher's real name, type, language, date, verified mark.
- **Item blocks:** 1. Content (video as a YouTube embed where linked, 07 §11). 2. Verified mark with "Verified by {teacher name}" (REQ-TCH-003). 3. Author's short profile (REQ-TCH-001). 4. Report button.
- **Data:** `posts` from teachers with scope public that passed editor or admin review, verified articles (REQ-PUB-005), `users` (teacher name and short profile), `media_assets`.
- **Empty states:** "Teachers' work will appear here soon." A teacher without a photo shows an initial.
- **Phase:** P3.

### 5.14 New projects

See §10.

### 5.15 Login and create donor account

- **Purpose:** one sign-in for every role.
- **Who:** anyone.
- **Blocks:** 1. Email or username (students sign in with the username their teacher gave them). 2. Password, or the method set in 03 §6. 3. Two-factor step for admin and finance officer (REQ-SEC-003). 4. "Forgot password": donors and staff reset by email; students see "Ask your teacher to reset it." 5. "Create a donor account" link to `/signup` (email, name, password, language). There is no student or guardian sign-up anywhere (REQ-STU-001, REQ-ROL-003).
- **After login:** donors go to `/account`, students and teachers to `/hub` (or `/account` when hub modules are off), editors, finance officers and admins to `/admin`.
- **Data:** `users`, `user_roles`.
- **Phase:** P1.

### 5.16 Guest trail link page

- **Purpose:** a guest donor sees their donations without an account (REQ-DPR-002).
- **Who:** the holder of a valid, unrevoked token (REQ-SEC-004).
- **Blocks:** 1. "Donations made with this email" list: receipt number, date, cause, amount, state. 2. Each donation opens its trail (received and allocated in P1; spent and reported from P2). 3. Controls the donor has over each donation, as allowed by 06 §10 and §11 (for example name or anonymous, trail public or private). 4. "Create an account to keep these in one place" (REQ-DPR-003).
- **Invalid or revoked token:** "This link no longer works." A form asks for the email and always answers "If we have donations for this email, we have sent a new link," whether or not the email exists.
- **Data:** `donors`, `donations`, `trail_events`, `allocations`.
- **Empty states:** a donor whose notices are not yet confirmed sees "Waiting for the madrasa to confirm your transfer."
- **Phase:** P1. Built in P1-E3 and P1-E4 (06).

### 5.17 Account

- **Purpose:** a signed-in person's own settings.
- **Who:** any signed-in user. Sections show per role.
- **Blocks:** 1. Name, email, language (REQ-LNG-004), password. 2. Two-factor for staff. 3. Donor: link to My donations, default name choice for new donations, public profile settings (P2), reminder opt-in, "Claim donations made with my email" (06 §11). 4. Sponsor: link to the sponsor area (P4). 5. Roles held, read only. Students change their persona in the hub (07 §4), not here.
- **Data:** `users`, `user_roles`, `donors`, `sponsorships`.
- **Phase:** P1.

### 5.18 My donations and one donation's trail

- **Purpose:** the donor always sees their own trail (REQ-DPR-010, REQ-TRL-007).
- **Who:** the donor who owns the donations; finance officers and admins reach the same data through the admin area.
- **List blocks:** receipt number, date, cause, amount, type, state, and a receipt download link.
- **Trail blocks:** 1. Summary. 2. Events received, allocated, spent and reported, with the spending entries it paid for and how much. 3. Name on donor wall: shown or anonymous. 4. Trail: private (default, REQ-TRL-008) or public, with a switch (REQ-TRL-009) and the public link when on.
- **Data:** `donations`, `trail_events`, `allocations`, `spending_entries`, `causes`.
- **Empty states:** "You have not given yet" with links to causes. A trail with no spending says "Not spent yet. Spending is matched oldest first."
- **Phase:** P1 (received and allocated), P2 (spent and reported). Built in P1-E4 (06).

### 5.19 Sponsor area

- **Purpose:** a sponsor follows the one orphan they support, safely (06 §12).
- **Who:** a donor with an active sponsorship. Nobody else, ever; there is no public version.
- **Blocks:** 1. Child card: persona name, age, persona avatar (never a face unless consent is active) (REQ-ORP-002). 2. Progress updates, newest first. 3. Full profile, only while a consent record with both sign-offs is active (REQ-ORP-003, REQ-ORP-005); it disappears at once when consent is withdrawn (REQ-ORP-006). 4. Messages to the madrasa: a thread with the madrasa only, never with the child (REQ-ORP-007). 5. Sponsorship donations with their trails (REQ-ORP-009).
- **Data:** `sponsorships`, `sponsorship_updates`, `sponsor_messages`, `personas`, `consent_records`, `donations`.
- **Empty states:** "The madrasa will post the first update soon." No active consent shows no full-profile block and no hint of what it would contain.
- **Phase:** P4 (task P4-E3-T50).

### 5.20 Content hub entry

- **Purpose:** the door into the student and teacher hubs.
- **Who:** signed-in students, teachers, editors and admins. Visitors and donors see a short explanation and a login button.
- **Blocks:** 1. Greeting by persona name (students) or real name (staff). 2. First-login walkthrough for students (02 §13). 3. Links: my classes, madrasa feed, teacher hub, and for teachers "Needs your approval" with a count. Inner pages are specified in 07.
- **Data:** `users`, `personas`, `classes`, `class_members`.
- **Module rules:** student links show only with the student hub on, teacher links only with the teacher hub on. With both off, `/hub` returns "not found".
- **Phase:** P3.

### 5.21 Admin area

See §8. Only users with a staff role (teacher, editor, finance officer, admin) can open `/admin`. Others get "not found", not "forbidden", so the admin area does not advertise itself.

## 6. Roles

There are seven roles (REQ-ROL-001) and no guardian role (REQ-ROL-003). Roles are stored per institute in `user_roles`, so one person can hold different roles at different institutes later. A user may hold several roles (P05-03).

| Role | Who it is | How someone gets it | Held at Markaz Al Azeem today |
| --- | --- | --- | --- |
| Visitor | Anyone not signed in. A guest donor with a trail link is a visitor who also holds a token for their own donations. | No account | Everyone |
| Donor | A person with a donor account. | Signs up at `/signup`, claims guest donations, or is created by staff when recording a donation | None yet |
| Student | A student of the madrasa, always under a persona in public. | Created by a teacher or admin (REQ-STU-001). Keeps the role after leaving (D-028). | About 50 students, accounts from P3 |
| Teacher | A teaching staff member. | Created by the admin (REQ-ROL-004) | Teaching staff among the 8 staff; names not yet given |
| Editor | Reviews teacher work and edits site and cause text. | Granted by the admin | Open, Q-03 |
| Finance officer | Records and reconciles donations and spending. | Granted by the admin; needs two-factor | Open, Q-03. Until filled, Moazam does this work as admin. |
| Admin | Full control of one institute. | Granted by an admin; needs two-factor | Moazam, the principal |

**Markers** (P05-04). These are not roles. They narrow or extend a role for specific records.

| Marker | Meaning | Stored in | Today |
| --- | --- | --- | --- |
| Principal | The one admin who gives the first orphan consent sign-off, assigns the second signer, and approves public student work alongside class teachers. | `institute_settings` (principal user) | Moazam |
| Class teacher | A teacher who is a teacher member of a class. Their class rights apply to that class's students and posts. | `class_members` | Set in P3 |
| Scope widener | A teacher the admin has chosen to widen post scopes (REQ-MOD-007). | `user_roles` flag (04 §7) | None yet |
| Assigned second signer | The teacher the principal assigned to give the second sign-off on one orphan's consent record (REQ-ORP-004). Any teacher can be assigned. | `consent_records` | Set in P4 |
| Sponsor | A donor matched to one orphan. | `sponsorships` | Set in P4 |

**Rules**

- The principal must hold the admin role. The assigned second signer must hold the teacher role and cannot be the principal.
- The last active admin cannot remove their own admin role or deactivate their own account (proposed REQ-ROL-013).
- Sami's technical access for support is set in 03 §6 and §12. This document gives him no role unless the admin grants one.

## 7. Permission matrix

This table is the one place where role rights are defined (REQ-ROL-002). Code reads it from one shared definition (task P0-E5-T50). Row-level security in 04 §6 enforces the same rules in the database.

**Key:** **yes** = allowed for all records of the institute. **own** = only their own records. **class** = only for students and posts in classes they teach. **link** = through a valid guest token. **—** = not allowed. Markers (principal, assigned, widener, sponsor) are named where they apply. A user with several roles gets the union.

### 7.1 Money

| Action | Visitor | Donor | Student | Teacher | Editor | Finance officer | Admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Give and send a transfer notice | yes (as guest) | yes | — ¹ | — ¹ | — ¹ | — ¹ | — ¹ |
| Record a bank-transfer donation | — | — | — | — | — | yes | yes |
| Reconcile a bank statement | — | — | — | — | — | yes | yes |
| Confirm or reject a transfer notice (reconcile) | — | — | — | — | — | yes | yes |
| Reverse a donation, with a reason | — | — | — | — | — | yes | yes |
| See the donor's name and email on a donation record | — | own | — | — | — | yes | yes |
| Resend a receipt or trail link | link (request) | own | — | — | — | yes | yes |
| Revoke a guest trail link | — | — | — | — | — | yes | yes |
| Create a cause; set type, target, dates; close; archive | — | — | — | — | — | — | yes |
| Edit cause text and photos | — | — | — | — | yes | — | yes |
| Preview draft causes | — | — | — | — | yes | yes | yes |
| Set `accepts_zakat` and the scholar name | — | — | — | — | — | — | yes |
| Split all-needs money across causes | — | — | — | — | — | — | yes |
| Record spending entries with receipts | — | — | — | — | — | yes | yes |
| Correct a spending entry with a reversing entry | — | — | — | — | — | yes | yes |
| See unspent balance per cause and fund type | — | — | — | — | — | yes | yes |
| Publish a daily or weekly report | — | — | — | — | — | yes | yes |
| See public cause totals, spending and reports | yes | yes | yes | yes | yes | yes | yes |

¹ Any person can give as a visitor. Staff and students who want their gifts in an account hold the donor role on the same account.

### 7.2 Donor wall and trail visibility

| Action | Visitor | Donor | Student | Teacher | Editor | Finance officer | Admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| View the donor wall | yes | yes | yes | yes | yes | yes | yes |
| Choose name or anonymous for a donation | link | own | — | — | — | at recording, as the donor asked | at recording, as the donor asked |
| Switch a donation to anonymous | link | own | — | — | — | yes | yes |
| Switch a donation from anonymous to named | link | own | — | — | — | — | — |
| View a donation's trail | link | own | — | — | — | yes | yes |
| Make a trail public | link | own | — | — | — | — | — |
| Make a trail private | link | own | — | — | — | yes | yes |
| Set up a public donor profile | — | own | — | — | — | — | — |

Staff can make things more private but never more public on a donor's behalf (P05-07).

### 7.3 Sponsorship and consent

| Action | Visitor | Donor | Student | Teacher | Editor | Finance officer | Admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Match a sponsor to an orphan | — | — | — | — | — | — | yes |
| See the orphan's persona name, age and updates | — | sponsor (own match) | — | class | — | — | yes |
| Post a progress update | — | — | — | class | — | — | yes |
| Send a message to the madrasa about the child | — | sponsor | — | — | — | — | — |
| Read and reply to sponsor messages | — | — | — | — | — | — | yes |
| See the orphan's full profile | — | sponsor, only while consent is active | — | class | — | — | yes |
| Record or edit a parent consent record | — | — | — | class | — | — | yes |
| Give the first sign-off on orphan consent | — | — | — | — | — | — | principal |
| Assign the second sign-off to a teacher | — | — | — | — | — | — | principal |
| Give the second sign-off | — | — | — | assigned | — | — | — |
| Record a consent withdrawal (takes effect at once) | — | — | — | class | — | — | yes |

### 7.4 Accounts, classes and personas

| Action | Visitor | Donor | Student | Teacher | Editor | Finance officer | Admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Create a donor account | yes (sign-up) | — | — | — | — | yes (when recording) | yes |
| Create a student account | — | — | — | yes | — | — | yes |
| Create teacher, editor and finance officer accounts; grant and remove roles | — | — | — | — | — | — | yes |
| Mark a teacher as scope widener | — | — | — | — | — | — | yes |
| Deactivate or reactivate an account | — | — | — | — | — | — | yes |
| Reset a student's password | — | — | — | class | — | — | yes |
| Edit own name, language and password | — | own | own | own | own | own | own |
| Create a class | — | — | — | yes (becomes its teacher) | — | — | yes |
| Add or remove students in a class | — | — | — | class | — | — | yes |
| Add or remove teachers in a class | — | — | — | — | — | — | yes |
| Set up and edit own persona | — | — | own | — | — | — | — |
| See which student a persona belongs to | — | — | — | class | — | — | yes |
| Reset an unsuitable persona name or avatar | — | — | — | class | — | — | yes |

The persona-to-student link is visible only to the student's teachers and admins (REQ-SEC-007, REQ-TCH-006). Editors and finance officers never see it, even inside the admin area. Whether a student's past teachers keep this view after the student leaves is set in 07 §4.

### 7.5 Posts, moderation and verified articles

| Action | Visitor | Donor | Student | Teacher | Editor | Finance officer | Admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Read class posts | — | — | own classes | class | — | — | yes |
| Read madrasa posts | — | — | yes | yes | — | — | yes |
| Read public posts | yes | yes | yes | yes | yes | yes | yes |
| Create a class or madrasa post, reply, vote | — | — | yes | yes | — | — | yes |
| Ask for own post to go public | — | — | own | own | — | — | — |
| Approve a student post for public view | — | — | — | class teacher | — | — | principal, admin |
| Approve teacher work for public view | — | — | — | — | yes | — | yes |
| Widen a post's scope (class to madrasa) | — | — | — | widener | — | — | yes |
| Report a post | public posts | public posts | yes | yes | yes | yes | yes |
| Hide or remove a class or madrasa post | — | — | — | yes ² | — | — | yes |
| Take down a public post | — | — | — | yes | yes | yes | yes |
| Restore a taken-down post | — | — | — | class teacher (student posts) | teacher work | — | yes |
| See the moderation queue | — | — | — | class and madrasa items | teacher work items | — | yes |
| Turn a thread into a verified article | — | — | — | yes | — | — | yes |
| Remove a verified mark | — | — | — | the verifying teacher | — | — | yes |

² Teachers can hide or remove any class or madrasa post, as REQ-MOD-002 says (D-031). REQ-CHS-003 is the minimum: every teacher sees all posts in their own classes.

Any staff role can take down a public post (P05-14); only approvers can restore it. The public-approval and scope-widening rows follow REQ-MOD-003 and REQ-MOD-007; see the note in "Tasks" about how 07 should reconcile them.

### 7.6 Institute and system

| Action | Visitor | Donor | Student | Teacher | Editor | Finance officer | Admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Switch modules on or off | — | — | — | — | — | — | yes |
| Edit institute settings (name, logo, contact, bank accounts, principal, batch mode) | — | — | — | — | — | — | yes |
| Edit site page text and photos | — | — | — | — | yes | — | yes |
| View and filter the audit log | — | — | — | — | — | — | yes |
| Edit or delete an audit log entry | — | — | — | — | — | — | — |

## 8. Admin screens

### 8.0 Rules for every admin screen

The principal records donations and spending by hand on a phone (R-03). Every admin form follows these rules (built once in task P1-E5-T02):

- One column, labels above fields, inputs at least 48 pixels tall, primary button fixed at the bottom of the screen.
- Amount fields open the number keypad, accept Urdu and English digits, and show thousands separators as you type.
- Sensible defaults: date is today; cause, type and bank account default to the last ones this user used.
- At most 8 fields visible by default. Optional fields sit behind "More details".
- "Save and add another" on every recording form.
- Photo fields open the camera directly and shrink the photo on the phone before upload (03 §8).
- A form being filled is kept on the phone until it is sent. If the connection drops, the screen says "Saved on this phone, not sent yet" and retries. Each submission carries a one-time key so a retry never records the same donation or spending entry twice (03 §12).
- After saving, a confirmation card shows what was recorded and offers the correct next action (for a donation: "Reverse" with a reason, never "Delete").
- Bilingual text uses an Urdu and English pair of tabs. One language is required; the other is optional and falls back with a notice (REQ-LNG-009).
- Every save writes an audit log entry (§9). Actions that need a reason ask for it in the same sheet.
- Target: recording one bank-transfer donation takes under 60 seconds on a low-end phone.

**Menu by role:** admin sees every screen. Finance officer: dashboard, donations, spending and reports. Editor: dashboard, causes (text only), site pages, moderation (teacher work). Teacher: dashboard, users (students only), classes and personas, consent records, moderation (their items). Menu items for modules that are off are hidden.

### 8.1 Dashboard (`/admin`)

- **Tiles (each opens its screen):** transfer notices waiting for confirmation; unallocated all-needs balance by type (P2); unspent balance per cause (P2); spending batch open for today or this week (P2); moderation items waiting (P3); consent records waiting for a sign-off (P4); warnings, such as "No bank account in settings" or "A cause is missing its English text".
- **Quick actions:** "Record donation" and "Record spending", as two large buttons at the top.
- **Data:** counts from `donations`, `allocations`, `spending_entries`, `post_reports`, `posts`, `consent_records`, `institute_settings`.

### 8.2 Causes (`/admin/causes`)

- **List:** title, type, status, raised, target, accepts Zakat. Filters: status, type, project. Order is drag or up-and-down arrows to set display order.
- **Form fields:** title (Urdu, English); slug (made from the English title, editable while draft); summary and story (Urdu, English); type: campaign, ongoing or yearly stock (REQ-DON-005); target amount (optional for ongoing, REQ-DON-007); start date; end date (required for a campaign, REQ-DON-006); year (for yearly stock); accepts Zakat, off by default (P05-15); approved by scholar name (optional, Q-04) (REQ-ROL-005); cover photo with the no-faces tick; linked facility (optional); project fields (§10).
- **States and actions:** *draft* (save, preview, publish) → *active* (edit, close) → *closed* (reopen if no end date has passed, archive) → *archived* (unarchive). A campaign moves to *closed* by itself after its end date. A cause with donations can never be deleted, only archived; archived causes keep their page and trail (REQ-DON-009).
- **Guards:** turning `accepts_zakat` off on a cause that holds unspent Zakat is blocked with an explanation (06 §6). Editors can change only text and photos; money and Zakat fields are read only for them.
- **Tables:** `causes`, `media_assets`.

### 8.3 Donations and reconciliation (`/admin/donations`)

- **List:** receipt number, date, amount, cause or all needs, type, state, donor (name and email shown to finance officer and admin only). Filters: state, cause, type, date range, bank account. Search by receipt number or bank reference.
- **Record form** (`/admin/donations/new`, REQ-DON-008, REQ-PAY-001). Visible by default: amount; date received; donor (search by email, or enter a new email with an optional name); cause or all needs; type (choosing Zakat limits causes to Zakat ones); bank account received into; bank reference; name on donor wall or anonymous. Under "More details": frequency, email language, trail public or private (private by default), reminder opt-in, internal note.
- **Transfer notices** (`/admin/donations/notices`): notices sent from the donate page, oldest first, each showing what the donor said. Actions: *Confirm* (with an optional edit of amount or date to match the bank), *Reject* with a reason (the donor is emailed), *Merge* with an existing recorded donation. Confirming creates the *received* trail event and the receipt (06 §4, §14).
- **Bank check view:** total confirmed per bank account per day, so the admin can compare with the bank statement line by line (06 §15).
- **Donation detail actions:** resend receipt; resend or revoke the guest trail link (REQ-SEC-004); switch to anonymous; make trail private; *Reverse* with a required reason (REQ-DON-012). There is no edit of amount, cause or type after confirmation; a mistake is reversed and recorded again (06 §15).
- **Tables:** `donations`, `donors`, `trail_events`, `causes`, `institute_settings`.

### 8.4 All-needs split (`/admin/all-needs`, admin only)

- **Shows:** unallocated all-needs money, split by type (Zakat, Sadaqah, general), with the number of donations behind each.
- **Form:** pick a type, then add rows of cause and amount. Zakat rows offer only Zakat causes. A running total shows how much is left. The total cannot exceed the unallocated balance of that type.
- **Preview:** before saving, the screen lists which donations each row will draw from, using the rule in 06 §7.
- **Action:** *Save split* creates the *allocated* events. A wrong split is corrected by a reversing allocation, never an edit.
- **Tables:** `donations`, `allocations`, `trail_events`, `causes`.

### 8.5 Spending entries and reports (`/admin/spending`)

- **Batch:** the screen opens today's batch, or this week's, depending on the institute's batch mode (D-013). The admin can switch mode in settings at any time.
- **Row fields:** cause; amount; date; description (in the user's language, the other optional); receipt photo (camera); receipt public, on by default; fund type where the cause holds more than one (Zakat, Sadaqah, general; matching rules in 06 §6).
- **Live help:** each row shows the cause's unspent balance for that fund type. An amount larger than the balance shows a warning and cannot be submitted (06 §9).
- **Actions:** *Add row*, *Save* (rows stay as draft, no trail events yet), *Submit batch* (runs first-in-first-out matching and creates *spent* events, 06 §8), *Correct* a submitted entry with a reversing entry and a reason (REQ-TRL-003).
- **Reports** (`/admin/reports`): a submitted batch can be published as a daily or weekly report with an optional note in both languages. Publishing creates *reported* events and shows the report on each cause page (REQ-TRL-012).
- **Tables:** `spending_entries`, `allocations`, `trail_events`, `media_assets`, `causes`.

### 8.6 Consent records (`/admin/consent`)

- **List:** student (persona name, with the real name shown to the student's teachers and admins only), consent kind, status, date. Filters: status, class, kind.
- **Parent consent form** (07 §5, REQ-CHS-005, REQ-CHS-006): student; guardian name; relationship; how consent was given (in person, phone, paper form); date; what is consented to (the kinds in 07 §5, such as public work and showing the real name); recorded by (filled in); note.
- **Orphan full-profile consent** (P4, 06 §12): the same fields, plus two sign-off slots. Status moves *waiting for first sign-off* → *waiting for second sign-off* → *active*, or → *withdrawn*.
  - The principal gives the first sign-off and picks the second signer from a list of all teachers (REQ-ORP-004).
  - The assigned teacher sees the record on their dashboard and gives the second sign-off.
  - The principal can reassign the second sign-off while it is still waiting.
- **Withdraw:** one button with a reason. It takes effect at once: the sponsor's full-profile block and any public real-name display disappear (REQ-ORP-006).
- **Tables:** `consent_records`, `personas`, `users`, `class_members`.

### 8.7 Sponsorships (`/admin/sponsorships`, admin)

- **List:** sponsor (donor), orphan (persona name), start date, status, consent status.
- **Actions:** *Match* a sponsor to one orphan (REQ-ORP-001); *Post update* (also open to the orphan's class teachers); *Messages*: read and reply to sponsor messages; *End* a sponsorship with a reason.
- **Tables:** `sponsorships`, `sponsorship_updates`, `sponsor_messages`, `personas`, `donors`.

### 8.8 Users (`/admin/users`)

- **List:** name (students show persona name, with the real name for their teachers and admins), roles, status, last login. Filters: role, class, status.
- **Create staff** (admin, REQ-ROL-004): name, email, phone (optional), roles (teacher, editor, finance officer, admin), language. The new user gets a sign-in email. Admin and finance officer accounts must set up two-factor at first login (REQ-SEC-003).
- **Create student** (teacher or admin, from P3, 07 §4): real name, class, username, first password (shown once), language. No email needed.
- **Actions:** change roles; mark a teacher as scope widener; reset a password; deactivate or reactivate. A student who leaves is removed from their class, not deactivated (D-028). The last-admin guard applies (§6).
- **Tables:** `users`, `user_roles`, `class_members`, `personas`.

### 8.9 Classes and personas (`/admin/classes`, `/admin/personas`)

- **Class fields:** name (Urdu, English), year or session, teachers, students.
- **Class actions:** add or remove students and teachers; end a student's membership when they leave (account and persona stay).
- **Personas:** list of persona name, avatar and class. The real-name column shows only to the student's teachers and admins. Action: *Reset* a persona name or avatar that breaks the rules in 07 §4, with a reason. Opening the real-name column is logged (proposed REQ-SEC-009).
- **Tables:** `classes`, `class_members`, `personas`, `users`.

### 8.10 Site pages (`/admin/pages`, editor and admin)

- **Pages:** home intro and facts strip, about, facilities (cards), daily life (timeline rows and photos).
- **Fields:** text pairs (Urdu, English) per section; photos with alt text in both languages (REQ-ACC-003) and the required "No student faces or names are visible" tick.
- **Actions:** save draft, preview, publish.
- **Tables:** `site_pages` (P05-13), `media_assets`.

### 8.11 Moderation queue (`/admin/moderation`)

- **Tabs:**
  1. *Reports*: reported posts with reason and count (REQ-MOD-005). Actions: dismiss, hide, take down.
  2. *Public requests*: student posts in state *submitted*. Actions: approve, reject with a note. Approval is blocked with an explanation if the student has no parent consent record that covers public work (REQ-CHS-005). Approvers: the student's class teacher or the principal (REQ-MOD-003).
  3. *Teacher work review*: teacher posts and verified articles waiting for editor or admin review (REQ-TCH-004).
  4. *Taken down*: with who took it down and why. Action: restore (approvers only).
- **Each item shows:** content, persona name (real name for the student's teachers and admins only), scope, state, history.
- **Tables:** `posts`, `threads`, `post_reports`, `consent_records`, `personas`.
- **Rules:** class and madrasa posts never enter the queue unless reported (D-019). Moderation states and timings: 07 §8.

### 8.12 Audit log (`/admin/audit`)

See §9.

### 8.13 Institute settings and modules (`/admin/settings`, admin)

- **Identity:** name (Urdu, English), logo, theme colours (picked from the palette rules in 02 §5, REQ-MIR-005), domain (read only).
- **Contact:** address (Urdu, English), phone, WhatsApp, email, map link, visiting times.
- **Bank accounts:** one or more, each with bank name, account title, account number, IBAN, SWIFT, branch, an optional label (such as "for Zakat only"), shown on donate page yes or no, default for recording yes or no.
- **People:** principal (pick one admin).
- **Money:** spending batch mode, daily or weekly (D-013).
- **Modules** (`/admin/settings/modules`, REQ-ROL-010): student hub, teacher hub, new projects, each with an on/off switch and a line explaining what switching off hides. Switching off asks for confirmation and changes nothing in the data (P05-12).
- **Tables:** `institute_settings`, `institutes`.

## 9. Audit log

### 9.1 What is logged

Every staff action that changes data writes one row to `audit_log` (REQ-ROL-008). The schema is in 04 §12. Each entry records: when; the acting user; the role they acted under; the action (such as `donation.reversed`); the entity type and internal ID; a safe label (receipt number, cause title, persona name, staff name); the fields changed with before and after values, with hidden fields marked "hidden"; and the reason where one is required.

| Area | Actions logged |
| --- | --- |
| Donations | recorded, notice confirmed, notice rejected, notice merged, reversed, switched to anonymous, trail made private, receipt resent, trail link resent, trail link revoked |
| Causes | created, edited (fields listed), published, closed, reopened, archived, Zakat setting changed, scholar name changed |
| All needs | split saved, split reversed |
| Spending | entry saved, batch submitted, entry corrected, report published |
| Consent | recorded, edited, first sign-off, second signer assigned or reassigned, second sign-off, withdrawn |
| Sponsorship | matched, ended, update posted, message replied |
| Accounts | staff account created, student account created, role granted, role removed, scope widener set, password reset, deactivated, reactivated, two-factor reset |
| Classes and personas | class created, member added, member removed, persona reset, persona real name viewed (proposed REQ-SEC-009) |
| Content | post hidden, post removed, public request approved or rejected, teacher work approved or rejected, taken down, restored, scope widened, verified article created, verified mark removed |
| Settings | settings changed, bank account added or changed, module switched on or off, principal changed, site page published |
| Security | staff login, failed staff login, two-factor set up |

Actions by donors and students on their own records (a student's own post, a donor's own trail switch) are not staff actions. Their history lives in the records themselves (trail events, post history), not in the audit log.

### 9.2 What is never stored

- No donor name or donor email, for any donor, anonymous or not (P05-09). A donor appears as their receipt number or an internal donor reference, such as "Donor ref 0412". An admin who needs the identity opens the donation record, where their role allows it.
- No student real name. A student appears by persona name.
- No passwords, two-factor secrets, guest trail tokens, or full bank account numbers.

So an anonymous donor's name can never appear on the audit log screen, in its data responses or in any future export (REQ-DPR-009, REQ-SEC-008).

### 9.3 Screen

- **List:** newest first, 50 per page. Each row shows time, actor, action in plain words ("Moazam reversed donation R-2026-0031: duplicate entry"), and the safe label.
- **Filters** (in a bottom sheet on phones): date range with presets (today, 7 days, 30 days); actor; area (the rows of 9.1); action; reference search (receipt number, cause slug, persona name); "only entries with a reason".
- **Entry detail:** all recorded fields, before and after values, and a link to the record (the record screen applies its own permissions).
- **No export** in this version, to keep the leak surface small.

### 9.4 Who can see it and rules

- Only admins can open the audit log (REQ-ROL-009).
- No role can edit or delete an entry (proposed REQ-ROL-011). Corrections to data create new entries.
- Retention: 04 §13.

## 10. New projects page

### 10.1 What a project is

A new project is a cause with "Show on new projects page" turned on (P05-11, REQ-DON-013). It has every cause feature: type, target, Zakat setting, trail, donor wall entries and spending. It appears on the causes list as well. Examples: a new classroom, a water cooler for the prayer hall, and future technology costs.

**Project fields on the cause form** (stored on `causes`, columns set in 04 §8):

- Show on new projects page: yes or no.
- Project category: facilities, education, community service, technology. Category names live in translation files, so more can be added without code.
- Planned start (month and year, optional).
- Why this matters (Urdu, English).
- What it will cost: a short list of cost lines as text (Urdu, English), for example "Desks Rs 120,000; whiteboard Rs 15,000".

**Project stage** shown on cards is worked out, not stored: *Raising* (active, below target), *Funded* (raised reaches the target), *Closed*.

### 10.2 Technology costs

Tazkiyah's running costs (developers, servers, database) are sponsored for now (A4). When they need funding, the admin creates them as causes in category *technology*, usually of type *ongoing*, with their own trail and spending entries (for example a monthly hosting bill as a spending entry with the invoice as its receipt). Task P4-E4-T04 prepares a draft cause "Platform running costs" that stays in draft until Moazam and Sami decide to publish it. Like every new cause, it starts with `accepts_zakat` off (P05-15).

### 10.3 Page spec (`/{lang}/projects`)

- **Purpose:** announce what the madrasa is starting next and raise money for it.
- **Who:** everyone, when the new projects module is on.
- **Blocks in order:**
  1. Title and intro text (from site pages).
  2. Category chips: All, Facilities, Education, Community service, Technology.
  3. Project cards: photo or category placeholder, title, stage, planned start, progress bar, Zakat badge, "Read more" (the cause page) and Donate.
  4. Technology costs section: an explanation of how tech costs are funded, and any active technology projects.
  5. "Get updates on new projects": the monthly reminder and newsletter opt-in (REQ-PAY-007, sending in 03 §10 and P4-E5).
  6. Past projects: closed projects with what was raised and spent, collapsed.
- **Data:** `causes` (project flag, status active or closed), `donations`, `allocations`, `spending_entries`, `media_assets`.
- **Empty states:** no active projects shows "New projects will be announced here" with the updates opt-in. A category with no projects hides its chip. No photo shows the category placeholder (02 §14).
- **Module off:** `/projects` returns "not found", the menu item and home teaser disappear, and project causes stay on the causes list and keep taking donations (P05-12).
- **Phase:** P4 (epic P4-E4). The P4 test in 00 §5 ("a new project appears as a cause") is checked by task P4-E4-T05.

## Requirements covered

**Owned here (checklist points to 05):**

| Requirement | Where |
| --- | --- |
| REQ-PUB-001 | §4, §5 |
| REQ-PUB-002 | §5.1 |
| REQ-PUB-003 | §5.6 |
| REQ-PUB-004 | §5.12 |
| REQ-PUB-005 | §5.13 |
| REQ-PUB-006 | §5.8, §8.13 |
| REQ-PUB-007 | §5.0 |
| REQ-PUB-008 | §5.7, §8.13 |
| REQ-TRL-010 | §5.6 |
| REQ-DON-009 | §8.2 |
| REQ-DON-013 | §10 |
| REQ-ROL-001 | §6 |
| REQ-ROL-002 | §7 |
| REQ-ROL-003 | §6, §5.15 |
| REQ-ROL-004 | §8.8 |
| REQ-ROL-008 | §9.1 |
| REQ-ROL-009 | §9.3, §9.4 |
| REQ-ROL-010 | §8.13, §10.3 |

**Supported here (owned by other documents):** REQ-DON-001, REQ-DON-002, REQ-DON-004, REQ-DON-005, REQ-DON-006, REQ-DON-007, REQ-DON-008, REQ-DON-012, REQ-DON-014, REQ-TRL-003, REQ-TRL-007, REQ-TRL-008, REQ-TRL-009, REQ-TRL-012, REQ-TRL-013, REQ-DPR-001, REQ-DPR-002, REQ-DPR-003, REQ-DPR-004, REQ-DPR-005, REQ-DPR-006, REQ-DPR-007, REQ-DPR-008, REQ-DPR-009, REQ-DPR-010, REQ-ORP-001, REQ-ORP-002, REQ-ORP-003, REQ-ORP-004, REQ-ORP-005, REQ-ORP-006, REQ-ORP-007, REQ-ORP-008, REQ-ORP-009, REQ-STU-001, REQ-STU-004, REQ-STU-011, REQ-TCH-001, REQ-TCH-003, REQ-TCH-004, REQ-TCH-005, REQ-TCH-006, REQ-ROL-005, REQ-ROL-006, REQ-ROL-007, REQ-PAY-001, REQ-PAY-007, REQ-PAY-008, REQ-SEC-003, REQ-SEC-004, REQ-SEC-005, REQ-SEC-007, REQ-SEC-008, REQ-CHS-001, REQ-CHS-003, REQ-CHS-004, REQ-CHS-005, REQ-CHS-006, REQ-PRF-001, REQ-PRF-002, REQ-ACC-003, REQ-ACC-004, REQ-LNG-001, REQ-LNG-003, REQ-LNG-004, REQ-LNG-008, REQ-LNG-009, REQ-LNG-012, REQ-MOD-002, REQ-MOD-003, REQ-MOD-005, REQ-MOD-006, REQ-MOD-007, REQ-MIR-001, REQ-MIR-005.

## Tasks

In "Depends on", a bare epic ID (such as `P0-E3`) means "all tasks of that epic that this work needs are done".

### P1-E1 Public pages (owner 05)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P1-E1-T01 | Public layout: header with logo and name from institute settings, main menu, Donate button, language switch, footer with contact | todo | P0-E3, P0-E4 | REQ-PUB-007, REQ-LNG-003, REQ-MIR-001 |
| P1-E1-T02 | Routes and page stubs for every public and signed-in page under `/ur` and `/en`; not-found page; module-off handling; `noindex` on private pages | todo | P1-E1-T01 | REQ-PUB-001, REQ-LNG-008 |
| P1-E1-T03 | Media placeholder block for pages, facility cards and causes without photos | todo | P0-E4 | REQ-PUB-001, REQ-ACC-003 |
| P1-E1-T04 | About, facilities and daily life pages reading bilingual text from `site_pages`, with fallback notice | in progress | P1-E1-T02, P1-E1-T03, P1-E5-T05 | REQ-PUB-001, REQ-LNG-009, REQ-CHS-001, REQ-DON-014 |
| P1-E1-T05 | Causes list page: filter chips, cause cards with progress and type labels, all-needs card, closed campaigns | in progress | P1-E1-T02, P1-E2 | REQ-PUB-001, REQ-DON-005, REQ-LNG-012 |
| P1-E1-T06 | Cause page: money box, Zakat line, story, Donate; closed, archived and draft states; empty spending block | in progress | P1-E1-T05 | REQ-PUB-003, REQ-DON-006, REQ-DON-007, REQ-ROL-005 |
| P1-E1-T07 | Home page: hero, active causes with progress, facts strip, contact strip; later blocks hidden until their phase | todo | P1-E1-T05 | REQ-PUB-002, REQ-PUB-007 |
| P1-E1-T08 | Donate page: cause or all-needs choice, type with Zakat filter, amount, bank details with copy buttons | in progress | P1-E1-T06, P1-E5-T03 | REQ-PUB-008, REQ-DON-001, REQ-DON-002, REQ-DON-004 |
| P1-E1-T09 | "Tell us about your transfer" form on the donate page and its thank-you state | todo | P1-E1-T08, P1-E3-T07 | REQ-DPR-001, REQ-DPR-006, REQ-PAY-001, REQ-PAY-007 |
| P1-E1-T10 | Contact page from institute settings, with tap-to-call, WhatsApp and static map link | done | P1-E1-T02, P1-E5-T03 | REQ-PUB-006 |
| P1-E1-T11 | Login and create-donor-account pages, with two-factor step for staff and role-based landing | in progress | P0-E5 | REQ-DPR-004, REQ-SEC-003, REQ-STU-001, REQ-ROL-003 |
| P1-E1-T12 | Account page: profile, language, password, two-factor, donor links | in progress | P1-E1-T11 | REQ-DPR-004, REQ-LNG-004 |
| P1-E1-T13 | Per-language page titles, `hreflang` links, `sitemap.xml` and share previews with logo fallback | done | P1-E1-T02 | REQ-LNG-008 |
| P1-E1-T14 | Check public pages on a slow 3G profile and a low-end phone; fix page weight, alt text and touch targets | in progress | P1-E1-T04, P1-E1-T07, P1-E1-T08, P1-E1-T10 | REQ-PRF-001, REQ-PRF-002, REQ-ACC-003, REQ-ACC-004 |
| P1-E1-T15 | Phase 1 public check: "Wheat stock" in both languages, a recorded guest donation, and the new total on the cause page | in progress | P1-E1-T06, P1-E2-T50, P1-E3, P1-E4 | REQ-PUB-003, REQ-DON-009 |

2026-11-12 · The bilingual sign-in flow now links to donor signup and password recovery. The signed-in account page shows the user's name and roles and requires students to change their starting password. Admins and finance officers still use the existing two-factor gate, and editors reach the admin workspace after sign-in. Hosted email verification, account editing, and donor links still need verification or implementation.

### P1-E5 Admin area shell and audit log (owner 05)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P1-E5-T01 | Admin shell: `/admin` layout, phone-first navigation, menu by role, staff-only guard returning not found | todo | P0-E5-T51, P0-E4 | REQ-ROL-002, REQ-LNG-001 |
| P1-E5-T02 | Admin form kit: amount field, date defaulting to today, Urdu/English text pair, camera photo field, save-and-add-another, on-phone draft and one-time submit key | todo | P1-E5-T01 | REQ-LNG-009, REQ-LNG-012, REQ-ACC-004 |
| P1-E5-T03 | Institute settings screen: identity, contact, bank accounts, principal, spending batch mode | in progress | P1-E5-T02, P0-E2 | REQ-MIR-001, REQ-PUB-006, REQ-PUB-008 |
| P1-E5-T04 | Module switches screen and module gating of menus, routes, home blocks and hub links | todo | P1-E5-T03 | REQ-ROL-010 |
| P1-E5-T05 | Site pages editor for home intro, facts strip, about, facilities and daily life, with the no-faces photo tick | in progress | P1-E5-T02 | REQ-LNG-009, REQ-CHS-001, REQ-ACC-003 |
| P1-E5-T06 | Users screen: list and filters, create teacher, editor and finance officer accounts, change roles, deactivate, last-admin guard | in progress | P1-E5-T02, P0-E5 | REQ-ROL-001, REQ-ROL-003, REQ-ROL-004, REQ-SEC-003 |
| P1-E5-T07 | Audit log writer called by every staff change, with redaction of donor names and emails, student real names and secrets | todo | P0-E2 | REQ-ROL-008, REQ-DPR-009, REQ-SEC-008 |
| P1-E5-T08 | Audit log screen: list, filters in a bottom sheet, entry detail, admin only | in progress | P1-E5-T07, P1-E5-T01 | REQ-ROL-009 |
| P1-E5-T09 | Automated checks: each admin action writes exactly one audit entry, and no donor name, donor email or student real name is ever in `audit_log` | todo | P1-E5-T07 | REQ-ROL-008, REQ-DPR-009, REQ-SEC-008 |
| P1-E5-T10 | Admin dashboard: two quick actions and tiles with counts, each tile appearing when its phase ships | todo | P1-E5-T01 | REQ-TRL-013, REQ-ROL-007 |

### P3-E8 Public student work and teacher work pages (owner 05)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P3-E8-T01 | Student work list page: published public posts under personas, type and language filters, empty state | todo | P3-E5, P1-E1-T02 | REQ-PUB-004, REQ-CHS-001 |
| P3-E8-T02 | Student work item page: only approved posts of a thread, persona, poll totals, report button | todo | P3-E8-T01 | REQ-PUB-004, REQ-STU-004, REQ-MOD-005 |
| P3-E8-T03 | Teacher work list page: tabs for verified articles, lessons, audio, video and resources | todo | P3-E6, P1-E1-T02 | REQ-PUB-005 |
| P3-E8-T04 | Teacher work item page: verified mark with verifying teacher's name, author profile, YouTube embeds, report button | todo | P3-E8-T03 | REQ-PUB-005, REQ-TCH-001, REQ-TCH-003, REQ-PRF-004 |
| P3-E8-T05 | Takedown clears the item from lists, item pages and caches within one minute, with a "no longer available" page | todo | P3-E8-T02, P3-E8-T04 | REQ-MOD-006, REQ-CHS-004 |
| P3-E8-T06 | Content hub entry page `/hub`: login gate, greeting, links by role and module | todo | P3-E1, P1-E5-T04 | REQ-ROL-010, REQ-STU-001 |
| P3-E8-T07 | Home page teasers for student and teacher work, hidden when a module is off or nothing is published | todo | P3-E8-T01, P3-E8-T03 | REQ-PUB-004, REQ-PUB-005, REQ-ROL-010 |

### P4-E4 New projects module (owner 05)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P4-E4-T01 | Project fields on the cause form: show on projects page, category, planned start, why it matters, cost lines | todo | P1-E2-T50 | REQ-DON-013 |
| P4-E4-T02 | New projects page: intro, category chips, project cards with worked-out stage, technology section, updates opt-in, past projects | todo | P4-E4-T01, P1-E1-T06 | REQ-DON-013, REQ-PUB-001, REQ-PAY-007 |
| P4-E4-T03 | New projects in menu and home teaser, hidden with the module off; project causes stay on the causes list | todo | P4-E4-T02, P1-E5-T04 | REQ-ROL-010 |
| P4-E4-T04 | Draft technology cause "Platform running costs" in both languages, Zakat off, ready for Moazam to publish | todo | P4-E4-T01 | REQ-DON-013 |
| P4-E4-T05 | Phase 4 check: a new project appears as a cause, takes a recorded donation and shows on the donor wall | todo | P4-E4-T03, P1-E3, P2-E5-T50 | REQ-DON-013 |

### Tasks in epics owned by other documents

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P0-E5-T50 | Permission matrix of §7 as one shared definition, with one automated test per row | todo | P0-E2 | REQ-ROL-001, REQ-ROL-002 |
| P0-E5-T51 | Route and action guards for `/admin`, `/account`, `/hub` and the sponsor area, driven by the shared matrix | todo | P0-E5-T50 | REQ-ROL-002, REQ-SEC-007 |
| P0-E5-T52 | Seed Moazam as admin and principal of Markaz Al Azeem; confirm no guardian role exists | todo | P0-E5-T50 | REQ-ROL-001, REQ-ROL-003 |

2026-11-09 · P0-E5-T04 (03) built the shared definition in [`packages/core/src/permissions.ts`](../packages/core/src/permissions.ts), with a test for every §7 row that compares it with these tables. P0-E5-T50 stays `todo` until its P0-E2 dependency is done. Then it only needs a review.
| P1-E2-T50 | Cause admin screens: list with ordering, bilingual form, Zakat and scholar fields, states draft, active, closed and archived, editor read-only money fields | todo | P1-E5-T02, P1-E2-T03, P1-E2-T04, P1-E2-T40 | REQ-DON-009, REQ-DON-005, REQ-DON-006, REQ-DON-007, REQ-ROL-005 |
| P2-E1-T50 | Spending batch screen on the phone: rows, live unspent balance, receipt camera, save, submit batch, report publish | todo | P1-E5-T02, P2-E1-T02, P2-E1-T05, P2-E1-T40, P2-E6-T01 | REQ-ROL-007, REQ-TRL-011, REQ-TRL-012, REQ-TRL-013 |
| P2-E5-T50 | Donor wall page: amount, cause, date, name or "Anonymous", filters; no donor ID in anonymous rows | todo | P1-E1-T02, P2-E5-T04, P2-E5-T20, P2-E5-T41 | REQ-DPR-007, REQ-DPR-008, REQ-DPR-009 |
| P2-E5-T51 | Donor public profile page listing only named donations | todo | P1-E1-T02, P2-E5-T02, P2-E5-T41 | REQ-DPR-005, REQ-DPR-009 |
| P2-E6-T50 | Cause page spending block: amount spent, spending entries, public receipts and published reports | todo | P1-E1-T06, P2-E1 | REQ-TRL-010, REQ-PUB-003, REQ-TRL-012 |
| P2-E6-T51 | Home page "where the money went" block | todo | P2-E6-T50 | REQ-TRL-010 |
| P3-E5-T50 | Moderation queue screen: reports, public requests with consent check, teacher work review, taken down | todo | P1-E5-T01, P3-E5-T05, P3-E5-T06, P3-E5-T08, P3-E5-T40, P3-E5-T41, P3-E6-T03 | REQ-MOD-003, REQ-MOD-005, REQ-CHS-004, REQ-CHS-005, REQ-TCH-004 |
| P4-E3-T50 | Sponsor area page: child card, updates, full profile only with active consent, messages to the madrasa | todo | P4-E1, P4-E2 | REQ-ORP-002, REQ-ORP-003, REQ-ORP-005, REQ-ORP-006, REQ-ORP-007 |

**Notes for other documents**

- Screens specified in §8 for epics where 05 is not listed (all-needs split in P2-E4, consent records in P3-E2 and P4-E2, classes and personas in P3-E1, donation recording and notices in P1-E3, my donations and the guest trail page in P1-E4) are built by those epics' owners from the specs here.
- 06 §4 should name the state of an unconfirmed transfer notice (P05-10).
- 07 §7 and §8 should state how REQ-MOD-003 (class teacher or principal approves public) and REQ-MOD-007 (only admin or chosen teachers widen scope) fit together. This document reads them as: going public is an approval by the class teacher or principal; widening between class and madrasa is for the admin and chosen teachers.
- Settled in the consistency check: site page text lives in `site_pages` (04 §5), and `causes.listed_as_project` marks a new project (04 §8.1).

## Acceptance criteria

1. Every page in the §4 tables loads under both `/ur` and `/en`; Urdu pages run right to left, and each page links to its twin.
2. With no photos uploaded, every public page renders with placeholders and no broken image or empty block.
3. Changing the institute name, logo, contact details or bank account in settings changes the header, footer, contact page and donate page with no code change.
4. The cause page for "Wheat stock" shows target, amount raised and, from P2, amount spent and its spending entries with no donor identity anywhere on the page or in its data response.
5. A closed campaign shows the closed banner and no Donate button; an archived cause is missing from the causes list but its URL still works.
6. A guest sends a transfer notice with only an email; the admin confirms it in under 60 seconds on a phone; the guest receives a link that opens the guest trail page showing the *received* event.
7. A revoked guest link shows "This link no longer works," and the new-link form gives the same answer for known and unknown emails.
8. On the donor wall, every entry shows its amount; anonymous entries show "Anonymous" and their data responses contain no donor name, ID or profile link; no entry shows the donation type.
9. For every row of the §7 matrix, an automated test signs in as each role and gets the allowed or refused result shown.
10. A user without a staff role who opens `/admin` gets "not found".
11. An editor or finance officer never sees a student's real name anywhere in the admin area; a class teacher and an admin do.
12. Only the principal can give the first orphan consent sign-off and assign the second; only the assigned teacher can give the second; withdrawing consent removes the full-profile block from the sponsor area on the next page load.
13. A finance officer can record, confirm and reverse donations and record spending, and is refused when changing a cause's Zakat setting or saving an all-needs split.
14. Every staff action listed in §9.1 writes one audit entry; a scan of `audit_log` after a test run finds no donor name, donor email or student real name; only an admin can open the audit log; no role can edit or delete an entry.
15. Switching the new projects module off removes `/projects`, its menu item and home teaser, while project causes still appear on the causes list and take donations; switching it on restores everything.
16. Switching off the student hub removes student work pages, menu items and hub links without changing any post.
17. A taken-down public post is gone from the student work list and its item page within one minute.
18. A spending batch with five rows and receipt photos can be entered and submitted on a low-end phone, and a dropped connection mid-way loses no rows and records none twice.
19. The new projects page lists a project cause with category technology under the technology section, and its card links to a normal cause page with a trail.

### Proposed requirements

These are not approved. Nothing is built on them until Sami approves each line (proposed open question for 00 §6: "Approve the proposed requirements in 05", owner Sami, due P1).

- [ ] REQ-PUB-009 (proposed) The site has a privacy page in Urdu and English that says what is stored about donors, students and consent, and who can see it. SHOULD → 05 §5
- [ ] REQ-ROL-011 (proposed) No role, including admin, can edit or delete an audit log entry. MUST → 05 §9
- [ ] REQ-ROL-012 (proposed) Switching a module off hides its pages and menu items and leaves its data unchanged. MUST → 05 §8
- [ ] REQ-ROL-013 (proposed) The last active admin of an institute cannot remove their own admin role or deactivate their own account. SHOULD → 05 §6
- [ ] REQ-SEC-009 (proposed) Each time a staff member opens the real name behind a persona in the admin area, the view is written to the audit log. SHOULD → 05 §9
- [ ] REQ-DPR-011 (proposed) Staff can make a donation anonymous or its trail private, but only the donor can make it named or public. MUST → 05 §7
