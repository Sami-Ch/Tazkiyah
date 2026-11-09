# 03 Architecture

**Status:** planning · **Last updated:** 2026-11-07 · **Owner:** Sami

Read [00-MASTER-PLAN.md](00-MASTER-PLAN.md) first. It wins over this document if they disagree.

## 1. Purpose

This document says how Tazkiyah runs. It covers the stack, hosting, environments, sign-in, the Urdu and English plumbing, media storage, background jobs, email, the payment seam, security, backups, logging and free-tier limits.

It is written for Sami and for AI agents who will build the system. A new developer should be able to set up, deploy and restore the platform from this document alone, using links to the other plan documents for business rules.

## 2. Scope and out of scope

**In scope**

- How Next.js runs on Cloudflare, and how it reaches Postgres on Neon.
- How each request finds its institute (by domain) and its user, and how both reach row-level security.
- Sign-in, roles, permission checks and two-factor authentication.
- Localization plumbing: `/ur` and `/en` routes, translation files, language detection and fallback.
- Media storage, upload caps, image compression and YouTube embeds.
- Background jobs (cron triggers and queues), email sending, optional SMS.
- The payment seam that the code leaves for Phase 5, without picking a gateway.
- Security controls, backups, restore tests, logging rules, monitoring.
- Free-tier limits, checked on 2026-11-07, with upgrade triggers.

**Out of scope (owned elsewhere)**

| Topic | Owner |
| --- | --- |
| Tables, fields, RLS policy text, migrations, retention | [04](04-database.md) |
| Pages, roles list, permission matrix, admin screens, audit log screens | [05](05-public-pages-roles-admin.md) |
| Donation rules, trail, FIFO, receipts content, reversals, online payment rules | [06](06-donations-and-trail.md) |
| Personas, consent, threads, moderation, media rules for students, child safety | [07](07-content-hub-student-teacher.md) |
| Visual design, RTL layout rules, fonts, mobile rules | [02](02-design-ui-ux.md) |
| Choice of payment gateway | Open question Q-01, decided with Sami in P5-E1 |
| Institute signup, super-admin area, billing, central fund | Non-goals ([00 §1](00-MASTER-PLAN.md#1-summary-goals-and-non-goals)) |

## 3. Decisions

### Decisions already logged

| Decision | What it means here |
| --- | --- |
| [D-002](08-decision-log.md#d-002) One shared database with RLS | One Neon project. Every request sets the institute inside its database transaction (§4.4). |
| [D-003](08-decision-log.md#d-003) Each institute uses its own domain | The request's host selects the institute (§4.5). |
| [D-006](08-decision-log.md#d-006) Next.js, Neon, Cloudflare, free tiers | §4 and §14. |
| [D-007](08-decision-log.md#d-007) Bilingual from Phase 1, browser language first, English default | §7. |
| [D-008](08-decision-log.md#d-008), [D-025](08-decision-log.md#d-025) Manual bank transfers first, payments last | §11. The manual flow already goes through the payment seam. |
| [D-009](08-decision-log.md#d-009) Guest donors with a private trail link | Token handling in §12. |
| [D-014](08-decision-log.md#d-014) Staff create student accounts | Username sign-in with no student self-signup (§6). |
| [D-020](08-decision-log.md#d-020) Capped uploads, YouTube for video | §8. |
| [D-027](08-decision-log.md#d-027) Takedown within one minute (proposed) | Cache times and purge rules in §5.5 and §8.6. |

### New architecture decisions (proposed)

These are this document's proposals. Each needs a `D-` entry in [08](08-decision-log.md) during the consistency check (step 4). Until then they are referred to as AR-01 to AR-10.

| ID | Decision | Options considered | Reason |
| --- | --- | --- | --- |
| AR-01 | Run Next.js on **Cloudflare Workers with the OpenNext adapter** (`@opennextjs/cloudflare`). | OpenNext; vinext (Cloudflare's Vite-based re-implementation); the old `next-on-pages`. | OpenNext supports Next.js 16 and the features we need (App Router, Server Actions, middleware, ISR). vinext is still marked beta as of 2026-11-05, although Cloudflare now recommends it for new apps. We revisit vinext when it leaves beta. |
| AR-02 | Use **Drizzle with node-postgres (`pg`) through Cloudflare Hyperdrive**. Run each tenant-scoped request in one explicit transaction with transaction-local settings for RLS. Fall back to the Neon serverless driver over WebSockets if needed. | Hyperdrive with `pg`, the Neon serverless driver, or direct TCP. | Hyperdrive pools connections near the database and supports normal interactive transactions. P0-E1-T05 tests the connection. |
| AR-03 | Use **Better Auth**, self-hosted in our own Postgres, with its username and two-factor plugins. | Better Auth; Auth.js; a hosted service (Clerk, Neon Auth). | User data stays in our database under RLS. It has TOTP two-factor, backup codes and username sign-in for students who have no email. It runs on Workers. No per-user cost. |
| AR-04 | Use **next-intl** for routing and translations. | next-intl; hand-rolled dictionaries; i18next. | It handles `/[locale]` routing, detection, ICU messages and typed keys with little code. |
| AR-05 | Store media in **Cloudflare R2**, two buckets (public and private). Compress and resize images **in the browser before upload**. No dependency on paid image transformations. | R2 with client resizing; R2 with Cloudflare Images transformations; Neon storage. | R2 has no egress fees. Client resizing keeps slow uploads small and avoids the 5,000-per-month transformation cap. |
| AR-06 | Run background work in a separate **jobs Worker** using **Cron Triggers and Cloudflare Queues**. | Separate jobs Worker; jobs inside the OpenNext Worker; an external scheduler. | Keeps the web bundle small, and both features are on the Workers Free plan. |
| AR-07 | Propose **Resend** as the email service. Final pick is open question **Q-06**. | Resend; Cloudflare Email Service; Brevo. | Resend's free plan gives 3,000 emails a month and 100 a day. Cloudflare Email Service needs Workers Paid. Brevo was not verified. See §10. |
| AR-08 | Take the **daily backup with a nightly GitHub Actions job** that runs `pg_dump` and stores an encrypted file in a private R2 bucket. | GitHub Actions to R2; rely on Neon history only. | Neon Free keeps only 6 hours of restore history and 1 manual snapshot, which does not meet REQ-SEC-006. |
| AR-09 | Put the Neon project in the **available region nearest Pakistan** (check Mumbai first, then Singapore), and turn on Smart Placement for the web Worker if it lowers response time. | Nearest region; US or EU default. | Most users are in Pakistan. Overseas donors see cached public pages. |
| AR-10 | Use a **monorepo** with `apps/web`, `apps/jobs`, `packages/core` (domain logic, DB access, permission checks), `packages/i18n` and `packages/email`. | Monorepo; one app. | The jobs Worker and the web app share the same rules without copying code. |

## 4. Stack and hosting

### 4.1 The stack at a glance

| Layer | Choice | Notes |
| --- | --- | --- |
| Framework | Next.js 16 (App Router, Server Components, Server Actions), TypeScript strict | Pin the exact minor version that the OpenNext release supports. |
| Hosting | Cloudflare Workers through `@opennextjs/cloudflare` (AR-01) | Needs the `nodejs_compat` flag and a compatibility date of 2024-09-23 or later. The Edge runtime is not supported by OpenNext, so every route uses the Node.js runtime. |
| Database | Postgres on Neon, Free plan | One project, branches per environment (§5). |
| DB connection | Hyperdrive + `pg` (AR-02) | Direct (non-pooled) Neon connection string inside Hyperdrive, as Cloudflare's Neon guide says. |
| Auth | Better Auth (AR-03) | §6. |
| i18n | next-intl (AR-04) | §7. |
| Media | Cloudflare R2 (AR-05) | §8. |
| Jobs | Cron Triggers + Queues in a jobs Worker (AR-06) | §9. |
| Email | Resend proposed, Q-06 open (AR-07) | §10. |
| Bot checks | Cloudflare Turnstile | On public forms (§12). |
| CI and backups | GitHub Actions | §5, §13. |

### 4.2 Request path

```
Browser (phone, 3G)
   │  https://azeem-lateef.com/ur/causes
   ▼
Cloudflare edge ── static assets (/_next/static, fonts, logo) served directly
   │
   ▼
Web Worker (OpenNext)
   1. middleware: host → institute_id (§4.5), locale from path (§7)
   2. route / server action
   3. session check (Better Auth) → user_id, roles (§6)
   4. withInstituteTx(...)  ──►  Hyperdrive  ──►  Neon Postgres (RLS on)
   5. render HTML in the request's language
   │
   ├──► R2 public bucket (media.azeem-lateef.com) for images
   └──► Queue "jobs" for emails and other slow work (§9)
```

### 4.3 Database roles

RLS only protects data if the app never connects as a role that skips it.

| Postgres role | Used by | Rights |
| --- | --- | --- |
| `tazkiyah_schema_owner` | CI migrations and ownership of schema objects | Owns tables, public views and definer functions. It has no login. The database administrator assumes it during migrations. |
| `tazkiyah_app` | Web Worker and jobs Worker (through Hyperdrive) | Non-owner with `NOBYPASSRLS`. Policies and grants govern runtime reads and writes. |
| `backup_reader` | Nightly backup job | Planned read-only credential. Prove it can dump all rows over a direct connection in P0-E1-T12. Keep it in GitHub Actions secrets. |

Create `tazkiyah_app` through SQL so it starts without `neon_superuser` membership. Use a direct connection for migrations and backups. The [schema plan](04-database.md#42-schemas-and-database-roles) enables RLS on every app table and defines explicit tenant checks for owner-backed public views and definer functions. See [D-109](08-decision-log.md#d-109) and [Neon's database access documentation](https://neon.com/docs/manage/database-access).

### 4.4 Getting the institute and user into each database session

Tenant-scoped calls go through `withInstituteTx` in `packages/core`. It sets tenant context and hands the caller a Drizzle transaction on the same connection. The core database module also owns the narrow lookups in §4.5 that run before the institute context exists. Limit application `pg` imports to that module.

What the wrapper does for every request or job step:

```sql
BEGIN;
SELECT set_config('app.institute_id', $1, true);   -- uuid from the host lookup
SELECT set_config('app.user_id',      $2, true);   -- '' for visitors
SELECT set_config('app.request_id',   $3, true);   -- for audit correlation
-- ... the route's queries ...
COMMIT;
```

- The third argument `true` makes each setting **local to the transaction**. It disappears at `COMMIT`, so a pooled connection can never carry one institute's setting into another request.
- The values come only from the server (host lookup and session), never from the browser.
- RLS checks `user_roles` for the current institute and user. Jobs set `app.actor_kind` to `job` in their transaction ([04 §6.1](04-database.md#61-how-the-session-supplies-institute-and-user)).
- RLS policies in [04 §6](04-database.md) read them with `current_setting('app.institute_id', true)`. If the setting is missing, policies return no rows. 04 must use these exact setting names.
- Hyperdrive does not support changes to per-session state, so we never use plain `SET` or session-level settings. Transaction-local `set_config` inside an explicit transaction is expected to work, because the pooled connection stays with us for the whole transaction. **This is not yet proven.** P0-E1-T05 tests it. If it fails, we switch to the Neon serverless driver with a WebSocket `Pool` created per request, which gives a normal session.
- Hyperdrive also does not support SQL `PREPARE` or session-level advisory locks. Use transaction-level advisory locks if FIFO matching needs a lock ([06 §8](06-donations-and-trail.md)).

### 4.5 Selecting the institute from the request domain

REQ-MIR-002. Each institute's domain is stored as data in institute settings ([04 §5](04-database.md)).

1. Middleware reads the `Host` header, lowercases it, removes the port and a leading `www.`.
2. It calls `app.resolve_institute(host)`. This definer function returns the active institute's ID or null before `app.institute_id` is set.
3. The result is cached in memory in the Worker isolate for 5 minutes.
4. No match: return a plain 404 page "No institute at this address" in English and Urdu. Never fall back to the first institute.
5. Extra hosts per environment are stored as aliases in settings:

| Environment | Host | Institute |
| --- | --- | --- |
| Production | `azeem-lateef.com`, `www.azeem-lateef.com` | Markaz Al Azeem |
| Preview | `preview.azeem-lateef.com` | Markaz Al Azeem (preview data) |
| Preview | `test-institute.preview.azeem-lateef.com` | "Test Institute" (for cross-institute tests) |
| Local | `localhost`, `test.localhost` | Markaz Al Azeem, Test Institute |

The jobs Worker has no host. It loops over active institutes with a second `SECURITY DEFINER` function `list_active_institutes()` and runs each institute's work in its own `withInstituteTx`.

## 5. Environments and deployment

### 5.1 Environments

| Environment | Web Worker | Jobs Worker | Neon branch | R2 buckets | Who uses it |
| --- | --- | --- | --- | --- | --- |
| Local | `next dev` (OpenNext dev bindings) | `wrangler dev` | `dev` branch, or local Postgres in Docker | local R2 emulation | Sami and agents |
| Preview | `tazkiyah-web-preview` at `preview.azeem-lateef.com` | `tazkiyah-jobs-preview` | `preview` (seeded test data, two institutes) | `tz-preview-public`, `tz-preview-private` | Sami, Moazam for review |
| Production | `tazkiyah-web-prod` at `azeem-lateef.com` | `tazkiyah-jobs-prod` | `main` | `tz-prod-public`, `tz-prod-private`, `tz-prod-backups` | Everyone |
| CI | none | none | short-lived branch per run, deleted after | none | GitHub Actions |

- Preview is protected so search engines and the public do not see it: `noindex` headers plus Cloudflare Access or a simple shared password. Check Cloudflare Access's free seat limit in P0-E1-T06 (not verified here).
- Preview never holds real donor or student data. Seed data uses invented names.
- Neon Free allows 10 branches per project. We use 3 long-lived branches, which leaves 7 for CI and restore tests.

### 5.2 Secrets and configuration

- Secrets live in Wrangler secrets (Workers) and GitHub Actions secrets (CI and backups). Never in the repo.
- Every Worker validates its environment at start-up with one typed schema. A missing secret fails the deploy, not a user request.
- Institute data (name, logo, colours, domain, bank details, enabled modules) is **data**, not configuration ([04 §5](04-database.md)).
- Workers Free allows 64 environment variables per Worker. We expect about 20.

### 5.3 Deployment pipeline

```
pull request ─► CI: lint · typecheck · unit tests · missing-translation check
                    · create Neon branch · run migrations · RLS tests · delete branch
merge to main ─► migrate preview branch ─► deploy preview Workers
tag vX.Y.Z    ─► migrate main branch    ─► deploy production Workers
```

- Migrations run before the deploy as `tazkiyah_schema_owner`. Each migration must be backward compatible with the code already running (add first, remove later). Migration tooling and naming belong to [04 §13](04-database.md).
- Rollback: redeploy the previous tag with Wrangler's version rollback. Database rollbacks are new forward migrations, never edits to applied ones.
- The P0 phase test's cross-institute check runs in CI on every pull request (REQ-SEC-002).

### 5.4 Domain and DNS

- `azeem-lateef.com` must be a Cloudflare zone so Workers can serve it as a custom domain. The domain and its email already exist. Before moving nameservers, copy **every** existing DNS record, especially `MX`, `SPF`, `DKIM` and `DMARC`, then confirm the existing mailbox still sends and receives (P0-E1-T03).
- `www.azeem-lateef.com` redirects to the apex with a 301.
- `media.azeem-lateef.com` points at the public R2 bucket (§8).

### 5.5 Caching

- Static assets (`/_next/static`, fonts, logo) are cached for a year with hashed file names.
- Public pages that change slowly (about, facilities, cause pages, donor wall, student work, teacher work) use incremental static regeneration with `revalidate = 60` seconds, plus on-demand revalidation by tag when data changes. This keeps most public views away from Neon (§14).
- **Cache keys must include the host and the locale.** With many institutes on one Worker, a page cached for one domain must never be served for another. P0-E1-T14 checks how OpenNext builds cache keys. If it cannot include the host, public pages render dynamically until it can.
- Signed-in pages, the admin area and guest trail pages are never cached (`Cache-Control: private, no-store`).
- A takedown calls tag revalidation and purges the page path, so the post is gone within 60 seconds (D-027, REQ-MOD-006).

## 6. Authentication and sessions

### 6.1 Library and storage

The Next.js app hosts Better Auth (AR-03). Better Auth uses the restricted `tazkiyah_auth` database role and runs in a Drizzle transaction scoped to the institute resolved from the request host.

- Its user model maps onto our `users` table, with `institute_id` added as a required field.
- Sessions, credentials, verification, TOTP and rate limits live in the `identity` schema. Each table has `institute_id` and RLS. The application role has no access to that schema.
- Cookies: `HttpOnly`, `Secure`, `SameSite=Lax`, host-only (no `Domain` attribute), so a session on one institute's domain never works on another's.
- Passwords are hashed by the library (scrypt by default). We never log or email passwords.
- In P0-E5-T01, prove that sign-in and session lookup can resolve the necessary auth row with only the host's institute context. Test two institutes with the same email and username, and confirm that public callers cannot retrieve credentials or session rows.

### 6.2 Who signs in and how

| Person | Sign-in | Created by | Two-factor |
| --- | --- | --- | --- |
| Visitor | none | – | – |
| Guest donor | none; private trail link ([06 §11](06-donations-and-trail.md)) | admin records donation | – |
| Account donor | email + password; email verified | self sign-up (REQ-DPR-004) | optional |
| Student | **username** + password | teacher or admin only (REQ-STU-001, D-014) | no |
| Teacher, editor | email or username + password | admin | optional |
| Finance officer | email + password | admin | **required** (TOTP) |
| Admin | email + password | first admin by bootstrap script; others by admin | **required** (TOTP) |

- **No self-signup for students or staff.** The public sign-up form creates only donor accounts. Student and staff accounts are created by server actions that check the creator's role.
- Students often have no email. A teacher creates a username such as `azeem-s-0142` and a one-time password, printed or shown once. On first sign-in the student must set a new password, then sees the walkthrough ([02 §13](02-design-ui-ux.md)). Forgotten student passwords are reset by a teacher, not by email.
- Usernames contain no real names (REQ-CHS-001).
- There are no guardian logins (REQ-ROL-003).

### 6.3 Roles and permission checks

- Roles come from `user_roles` (`institute_id`, `user_id`, `role`). Class assignments come from `class_members`. The role list is visitor, donor, student, teacher, editor, finance officer and admin ([05 §6](05-public-pages-roles-admin.md)). A person can hold several roles.
- One function `can(user, action, resource)` in `packages/core` answers every permission question. Its table is generated from the permission matrix in [05 §7](05-public-pages-roles-admin.md). Anything not in the matrix is denied.
- Checks happen in three layers:
  1. Middleware blocks `/[locale]/admin/**` for anyone without a staff role.
  2. Every server action and route handler calls `can()` before doing anything.
  3. RLS policies match `app.user_id` and `app.institute_id` against `user_roles` ([04 §6](04-database.md)).
- Role changes end the user's other sessions, so new rights or removed rights apply at once.

### 6.4 Two-factor for admin and finance officer

REQ-SEC-003.

- Method: TOTP from an authenticator app (30-second codes). Not SMS.
- Enrolment is forced: a user with the admin or finance officer role who has not enrolled is sent to the enrolment page and can open nothing else.
- 10 single-use backup codes are shown once at enrolment. Moazam should print them and keep them at the madrasa.
- "Trust this device" is **off** for these two roles. Every sign-in asks for a code.
- After 5 failed codes the account is locked for 15 minutes (the library locks by default; we set the numbers). Every failure is written to `audit_log`.
- If Moazam loses both phone and backup codes, Sami resets two-factor with a script that needs production database access, and the reset is written to `audit_log`.

### 6.5 Session rules

| Role group | Idle timeout | Absolute lifetime |
| --- | --- | --- |
| Admin, finance officer | 30 minutes | 12 hours |
| Teacher, editor | 7 days | 30 days |
| Student, donor | 30 days | 90 days |

Users can sign out of all devices. A password reset ends all sessions.

### 6.6 Brute-force protection

- Rate limits per IP and per account on sign-in, password reset and two-factor (for example 10 attempts per 15 minutes). Counters live in Workers KV or Postgres; pick in P0-E5-T07. Workers KV Free allows 1,000 writes a day, so only failed attempts are counted.
- Turnstile appears on sign-in after 3 failures, and always on donor sign-up and password reset.
- Error messages do not say whether an email or username exists.

## 7. Localization plumbing

This section is the plumbing. Layout, fonts, mirroring and number display rules are in [02 §8](02-design-ui-ux.md).

### 7.1 Routes

- Every page lives under `app/[locale]/...`, with `locale` in `ur` or `en` (REQ-LNG-008). Examples: `/ur/causes`, `/en/causes/wheat-stock`.
- Slugs stay the same in both languages (Latin letters), so the switch only swaps the prefix.
- `/` and any path without a prefix redirect (307) to the chosen locale.
- Each page outputs `hreflang` alternate links for `ur`, `en` and `x-default` (English). Each host serves its own `sitemap.xml` listing both languages.

### 7.2 Choosing the language

REQ-LNG-004, REQ-LNG-005.

| Order | Source | Rule |
| --- | --- | --- |
| 1 | The URL prefix | Always wins when present. |
| 2 | `users.preferred_language` | For a signed-in user. Updated when they use the language switch. |
| 3 | `NEXT_LOCALE` cookie | Set for one year whenever the visitor uses the switch. |
| 4 | `Accept-Language` header | First supported language in the list: any `ur*` gives `ur`, any `en*` gives `en`. |
| 5 | Default | `en` (D-007). |

The institute's default locale in settings is **not** used for visitors, because D-007 says browser language first, then English.

The language switch links to the same path in the other locale, sets the cookie, and saves `users.preferred_language` if signed in (REQ-LNG-003).

### 7.3 Translation files

REQ-LNG-001, REQ-LNG-002.

```
packages/i18n/messages/
  en/  common.json  donate.json  trail.json  hub.json  admin.json  email.json  errors.json
  ur/  common.json  donate.json  trail.json  hub.json  admin.json  email.json  errors.json
```

- Keys are dotted and describe meaning, not wording: `donate.form.amount.label`.
- Messages use ICU format for plurals and values: `"trail.spentShare": "Rs {amount} of your gift paid for {item}"`.
- English files are the source. Keys are typed, so a missing key fails the build.
- CI fails if any key exists in one language but not the other.
- A lint rule (`no-literal-string` in JSX and in server action error returns) blocks hard-coded interface text. Exceptions need an inline comment with a reason.
- Adding a third language means adding a folder and a locale code. No other code changes.
- Server errors return a message **key**, not text, and the page translates it.

### 7.4 Bilingual admin content and fallback

REQ-LNG-009. Fixed content such as cause, project and about pages has Urdu and English versions. The storage format is set in [04](04-database.md) (either paired columns or a JSON object with `ur` and `en`).

One helper `pickLocalized(value, locale)` returns `{ text, shownLocale, isFallback }`:

- If the requested language has text, return it.
- Otherwise return the other language with `isFallback = true`. The page then shows a small notice ("This page is not yet available in Urdu") and sets `lang` and `dir` on that block to the language actually shown.

Community posts are not translated. Each post stores its own `language` ([07 §6](07-content-hub-student-teacher.md), REQ-LNG-010), and the post block gets `lang` and `dir` from it.

### 7.5 Direction, formats and fonts

- The root layout sets `<html lang="ur" dir="rtl">` or `<html lang="en" dir="ltr">` from the locale (REQ-LNG-006).
- One formatting module wraps `Intl` for rupee amounts, numbers and dates per locale (REQ-LNG-012). The display rules (Western or Urdu digits, "Rs" or "روپے") come from [02 §8](02-design-ui-ux.md). P0-E3-T05 checks that the Workers runtime has full Urdu locale data. If it does not, the module uses fixed patterns from the translation files instead.
- Font loading and subsetting follow [02 §6](02-design-ui-ux.md). The plumbing serves fonts as static assets with long cache times.

### 7.6 Emails

Email templates take a locale and use the `email` namespace. The recipient's language is `users.preferred_language` for account holders, or the language stored with a guest donor ([06 §11](06-donations-and-trail.md)). See §10.

## 8. Media storage

Who may upload what, and what students may show, is set in [07 §11](07-content-hub-student-teacher.md) and [07 §12](07-content-hub-student-teacher.md). This section is how files are stored and served.

### 8.1 Buckets and keys

| Bucket | Served from | Holds |
| --- | --- | --- |
| `tz-<env>-public` | `media.azeem-lateef.com` through Cloudflare's cache | Media approved for public pages: cause photos, published post media, teacher work, donor profile photos. |
| `tz-<env>-private` | Only through a permission-checked route | Class and madrasa post media, receipts not yet public, consent scans if 07 allows them. |
| `tz-prod-backups` | Never served | Encrypted database dumps (§13). |

Object keys contain no personal data (REQ-SEC-005):

```
{institute_id}/{kind}/{yyyy}/{mm}/{media_asset_id}-{variant}.{ext}
e.g. 7f3c…/image/2027/03/9b1e…-w1280.webp
```

Every file has a row in `media_assets` ([04 §11](04-database.md)) with `institute_id`, owner, kind, bucket, key, bytes, MIME type, width and height, status (`pending`, `ready`, `rejected`, `deleted`) and, for linked videos, a YouTube video id.

### 8.2 Upload flow

```
1. Browser compresses the file (images) and asks:  POST /api/media/upload-request {kind, bytes, mime}
2. Server: can() check · cap check (8.3) · storage quota check (8.7)
           → insert media_assets (status=pending) → return a presigned R2 PUT URL (10-minute expiry,
             fixed Content-Type and Content-Length)
3. Browser uploads straight to R2 (the Worker never carries the file)
4. Browser calls POST /api/media/{id}/complete
5. Server reads the object head and first bytes: size within cap, file signature matches the MIME type
           → status=ready, or delete the object and set status=rejected
6. A daily job deletes pending rows and objects older than 24 hours.
```

### 8.3 Upload caps per type

REQ-PRF-003. These are proposed numbers. 07 may lower them per role.

| Kind | Accepted input | Cap on input | What is stored |
| --- | --- | --- | --- |
| Image (posts, causes, receipts, profiles) | JPEG, PNG, WebP, HEIC | 15 MB on the phone (before compression) | Two WebP variants: `w480` and `w1280` (longest side), quality about 0.8. Server rejects any stored variant over 600 KB. |
| Avatar | same as image | 15 MB before compression | One 256 px WebP, max 60 KB. |
| Receipt document | PDF | 5 MB | As uploaded. |
| Audio | MP3, M4A (AAC), WebM/Opus | 10 MB (about 20 minutes at 64 kbps mono) | As uploaded. |
| Slides | PDF only | 10 MB and 60 pages | As uploaded. |
| Video file | MP4 (H.264) | 25 MB and 90 seconds | As uploaded. Anything longer must be a YouTube link. |
| Video link | YouTube URL | – | Video id only. No file. |

### 8.4 Image compression and serving

REQ-PRF-002.

- The browser resizes and re-encodes images before upload with a canvas-based library. Re-encoding also **removes EXIF data, including GPS location and device details**. The server checks the stored WebP has no EXIF block (see proposed REQ-CHS-007).
- Pages use `srcset` with the two variants and `sizes`, `loading="lazy"` below the fold, and fixed `width` and `height` to avoid layout shift.
- Public media is served from `media.azeem-lateef.com` with `Cache-Control: public, max-age=31536000, immutable`. Keys never change; a new version gets a new key.
- We do not depend on Cloudflare Images transformations. If we later use them, the Free plan allows 5,000 unique transformations a month; past that, new transformations fail with error 9422 while cached ones keep working.
- Placeholders before media exists follow [02 §14](02-design-ui-ux.md).

### 8.5 Private media

- Private files are fetched through `/api/media/{id}`. The route runs `can()` and RLS, then returns a short-lived (5-minute) signed R2 URL or streams the file, with `Cache-Control: private, no-store`.
- When a post is approved for public view ([07 §8](07-content-hub-student-teacher.md)), its media is **copied** to the public bucket under a new key. The private original stays.

### 8.6 Takedown and deletion

- On takedown or delete, the public copy is deleted from R2 and its URL is purged from Cloudflare's cache. The page is revalidated (§5.5). Target: gone within 60 seconds (D-027, REQ-MOD-006, REQ-CHS-004).
- Deleted private files are removed after the retention period in [04 §13](04-database.md).

### 8.7 YouTube links and embeds

REQ-PRF-004.

- Accept `youtube.com/watch?v=`, `youtu.be/`, `youtube.com/shorts/` and `youtube.com/embed/` links. Store only the 11-character video id after checking its format.
- Show a "lite" embed: a static thumbnail and a play button. The real player (`https://www.youtube-nocookie.com/embed/{id}`) loads only when tapped. This saves about 1 MB per page on slow connections.
- The content security policy allows frames only from `youtube-nocookie.com`.
- Whether students may link their own YouTube videos, given faces are hidden by default, is decided in [07 §11](07-content-hub-student-teacher.md) and [07 §12](07-content-hub-student-teacher.md).

### 8.8 Storage quota

- Each institute has a storage quota in settings. For Markaz Al Azeem: warn the admin at 5 GB of media, block new uploads at 7 GB. This leaves room in R2's free 10 GB for backups and the page cache.
- A running total of bytes per institute is kept from `media_assets`. The admin area shows it.
- Rough estimate: 200 images a week at about 310 KB for both variants is about 3.2 GB a year. Audio, slides and video come on top.

## 9. Background jobs

### 9.1 Where jobs run

A separate jobs Worker (`tazkiyah-jobs-<env>`, AR-06) has two handlers:

- `scheduled` for Cron Triggers.
- `queue` for messages on the `jobs-<env>` queue.

Both use `packages/core`, so they apply the same rules and RLS as the web app.

### 9.2 Cron schedule

Workers Free allows **5 Cron Triggers per account**, shared by preview and production. We use 2 per environment (4 in total). Pakistan is UTC+5 with no daylight saving.

| Cron (UTC) | Pakistan time | Work |
| --- | --- | --- |
| `*/15 * * * *` | every 15 minutes | Sweeper: find donations with no receipt email sent and enqueue them; retry deferred emails; release expired upload requests. |
| `0 5 * * *` | 10:00 daily | Daily work: on the 1st of the month, start the monthly reminder run (§9.4); clean pending uploads older than 24 hours; spread queued reminders that wait for today's email allowance. |

Database backups do **not** run on Cloudflare. They run in GitHub Actions (§13).

Cron runs on Workers Free also have the 10 ms CPU limit. Waiting on the database or network does not count as CPU time, but each cron run must only find work and enqueue it, not do it all.

### 9.3 Queue messages

| Message type | Sent by | Consumer does |
| --- | --- | --- |
| `receipt.email` | Donation recording (after commit), sweeper | Builds the receipt email in the donor's language and sends it ([06 §14](06-donations-and-trail.md)). |
| `guest.trail-link.email` | Guest donation recording | Sends the private trail link ([06 §11](06-donations-and-trail.md)). |
| `reminder.monthly` | Daily cron on the 1st | Sends one donor's monthly reminder or newsletter (§9.4). |
| `auth.email` | Sign-up, password reset | Verification and reset emails. |
| `media.purge` | Takedown | Deletes the public copy and purges the cache. |
| `payment.event` (P5) | Payment webhook | Applies a provider event to the trail (§11). |

Rules:

- Messages carry **IDs only** (`institute_id`, `donation_id`, `user_id`), never names, emails or amounts. The consumer reads the rest from the database under RLS.
- Every handler is idempotent. A receipt is sent only if the donation's "receipt sent" marker is empty, and the marker is set in the same transaction as the provider's accepted response. Where the marker lives is set by [04](04-database.md).
- Batch size 10 messages, up to 3 retries with back-off, then a dead-letter queue `jobs-<env>-dlq`. The admin sees a count of dead-letter items.
- Queues on Workers Free keep messages for **24 hours**, and this cannot be changed. That is why the database, not the queue, is the source of truth: the 15-minute sweeper re-enqueues anything not marked as done.
- Workers Free allows 50 subrequests per request, so a consumer batch of 10 stays well within it.

### 9.4 Monthly reminders and newsletter

REQ-PAY-007 (opt-in rules in [06 §13](06-donations-and-trail.md)).

1. On the 1st at 10:00 Pakistan time, the daily cron loops over active institutes.
2. For each, it selects donors who opted in and have not unsubscribed, and records a "run" for that month so a re-run does not send twice.
3. It enqueues `reminder.monthly` messages, but only as many as today's email allowance leaves free after receipts (§10.3). The rest wait for the next days' daily runs.
4. Each email is in the donor's language, has a one-click unsubscribe link with an opaque token (no email in the URL), and a `List-Unsubscribe` header.
5. The newsletter body is written by the admin in Urdu and English ([05 §8](05-public-pages-roles-admin.md)) and can list new projects ([05 §10](05-public-pages-roles-admin.md)).

### 9.5 Card recurring charges (Phase 5)

Recurring card charges are normally run by the gateway's own subscription feature, which calls our webhook each time. Our jobs only record the events (§11). If the chosen gateway cannot schedule charges itself, P5-E2 adds a daily charge job. That is decided in P5.

## 10. Email and SMS

### 10.1 Service choice (Q-06)

| Option | Free allowance (as of 2026-11-07) | Fit |
| --- | --- | --- |
| **Resend** (proposed) | 3,000 emails a month, **100 a day**, 3 custom domains, 30 days of logs, 1 webhook | Simple HTTP API from Workers. Daily cap is the main limit. |
| Cloudflare Email Service | Sending to any address is **not available on Workers Free**. Workers Paid includes 3,000 a month, then $0.35 per 1,000. | Good if we move to Workers Paid anyway (§14). |
| Brevo | Not verified in this session. | Check before deciding. |

The final pick is **open question Q-06** (owner Sami, due P0). The code talks to one `EmailSender` interface in `packages/email` (`send(to, locale, template, data)`), so switching services means writing one adapter.

### 10.2 Domain setup

- Send from a subdomain, for example `notify.azeem-lateef.com`, with addresses such as `receipts@notify.azeem-lateef.com`. This keeps the existing mailbox's reputation and SPF record separate.
- Add the service's SPF and DKIM records, and a DMARC policy starting at `p=none`, moving to `quarantine` once reports are clean.
- `Reply-To` is the madrasa's existing contact address from institute settings.

### 10.3 Daily allowance and priority

With 100 emails a day on the proposed service, the app keeps its own daily counter and stops at 90, leaving room for urgent auth emails.

| Priority | Email | When over the daily allowance |
| --- | --- | --- |
| 1 | Sign-in verification, password reset | Always sent (uses the 10 spare). |
| 2 | Donation receipts, guest trail links | Deferred to the next day by the sweeper. |
| 3 | Staff notifications | Deferred. |
| 4 | Monthly reminders and newsletter | Spread over the following days. |

### 10.4 Language and content rules

- Each template exists in Urdu and English (REQ-LNG-011). Urdu emails use `dir="rtl"` and `lang="ur"` on the body, a web-safe Urdu font stack, and always include a plain-text part.
- Subjects carry a receipt number, never a name: "Your receipt R-2027-000123" ([06 §14](06-donations-and-trail.md) sets the number format).
- Emails sent to staff about an anonymous donation show "Anonymous", never the donor's name (REQ-DPR-009). A donor's own receipt greets them without their name if the donation is anonymous, because the provider keeps copies of email bodies for 30 days.
- No email ever contains a student's real name (REQ-SEC-008, REQ-CHS-001).
- Bounces and complaints come back through the provider's webhook and mark the address as undeliverable, so the reminder run skips it.

### 10.5 SMS

SMS is optional and low priority. It is not planned for any phase yet. If it is added later, it plugs into the same notification layer as a second channel, with its own opt-in and a per-month spending cap. The provider and cost are not researched here.

## 11. Payments integration

This section describes only the open questions, the constraints and the seam. **No gateway is chosen.** Business rules for online payments are in [06 §16](06-donations-and-trail.md). Payments are the last phase, P5 ([D-025](08-decision-log.md#d-025)).

### 11.1 Open questions

| ID | Question | Owner | Due |
| --- | --- | --- | --- |
| Q-01 | Which card gateway and which wallets (JazzCash, Easypaisa) to use | Sami | Before P5 |
| Q-02 | When registration completes, and what tax receipts must show | Moazam | Before P5 |
| (for P5-E1) | Can each candidate open a merchant account for a Pakistani non-profit, and what documents does it need? | Sami | P5-E1 |
| (for P5-E1) | Which candidates accept international cards and settle in PKR to the madrasa's bank? | Sami | P5-E1 |
| (for P5-E1) | Which candidates support automatic monthly and yearly card charges for a Pakistani merchant? | Sami | P5-E1 |
| (for P5-E1) | Fees, payout times, refund support and webhook reliability for each | Sami | P5-E1 |
| (for P5-E4) | Which exchange-rate source to use for display, and how often to refresh it | Sami | P5-E4 |

The three P5-E1 questions are sub-points of Q-01, not new questions.

### 11.2 Constraints the design must respect

| Constraint | Source | Effect on the code |
| --- | --- | --- |
| Registration is pending; gateways usually need it | [D-008](08-decision-log.md#d-008), R-01 | Manual bank-transfer recording is the only live path until P5. |
| Recurring giving is by **card only** | Brief B5, REQ-PAY-003 | The recurring option is shown only when a card provider is active. |
| JazzCash and Easypaisa are **one-off only** | Brief B5, REQ-PAY-004 | Wallet donors are offered the monthly reminder opt-in instead (REQ-PAY-007). |
| International donors | Brief B2 | Hosted checkout must accept foreign cards; amounts may arrive in another currency. |
| Multi-currency **display** | REQ-PAY-005 | Amounts are stored in PKR (and the charged currency when different). Other currencies are shown as estimates only. |
| Tax receipts only after registration | REQ-PAY-008 | Receipt template has a switch in institute settings; off until Q-02 is answered. |
| We never touch card numbers | Security | Use the gateway's hosted page or redirect. No card data passes through our Workers or database. |

### 11.3 The integration seam

The code leaves one interface, `PaymentProvider`, in `packages/core/payments`. Manual bank transfers are its first implementation (`bank_transfer`), so P1 already uses the seam and P5 only adds providers.

| Operation | Input | Output | Notes |
| --- | --- | --- | --- |
| `id` | – | e.g. `bank_transfer` | Stored on each donation as the provider. |
| `capabilities` | – | `{ oneOff, recurring, currencies[] }` | Drives which options the donate page offers. |
| `startPayment` | donation intent (institute, cause or all needs, type, amount, currency, frequency, donor) | redirect URL, or bank instructions for `bank_transfer` | Intent IDs only in URLs (REQ-SEC-005). |
| `verifyEvent` | raw webhook request | a verified `ProviderEvent` or a rejection | Checks the provider's signature. Not used by `bank_transfer`. |
| `refund` | provider reference, amount, reason | refund status | Optional per provider. |

`ProviderEvent` kinds: `payment_succeeded`, `payment_failed`, `refund_succeeded`, `subscription_renewed`, `subscription_cancelled`.

**One path into the trail.** Every event, manual or online, goes through one function in `packages/core`, `applyPaymentEvent(event)`:

```
payment_succeeded    → insert donations row + trail_events 'received'   (REQ-PAY-006)
refund_succeeded     → insert reversing trail event pointing to the original (REQ-TRL-003, 06 §15)
subscription_renewed → new donations row + 'received' for that month
payment_failed       → no trail event; recorded for reconciliation (06 §15)
```

- Idempotency key: `(institute_id, provider, provider_reference)`, unique in the database. A repeated webhook does nothing the second time.
- Webhooks arrive at `/api/payments/{provider}/webhook`. The handler verifies the signature, enqueues `payment.event` with the event id, and returns 200 quickly. The queue consumer runs `applyPaymentEvent`.
- For manual recording, the admin form ([06 §4](06-donations-and-trail.md)) builds a `payment_succeeded` event with provider `bank_transfer` and the bank reference as `provider_reference` (REQ-PAY-001).
- The institute's provider accounts and keys are institute settings ([04 §5](04-database.md)); keys are encrypted, never shown again after saving.

## 12. Security

| Threat | Control | Requirement |
| --- | --- | --- |
| One institute reads another's data | RLS on every table, transaction-local `app.institute_id`, `tazkiyah_app` without bypass, CI test with two institutes (§4.3, §4.4, §5.3) | REQ-SEC-001, REQ-SEC-002 |
| Wrong institute from the domain | Exact host match, no fallback institute, host-only cookies, cache keys include host (§4.5, §5.5, §6.1) | REQ-MIR-002 |
| Personal data in URLs | Opaque IDs and slugs only. Search and filter forms use POST. Emails, names and phone numbers never appear in paths or query strings. Media keys use IDs (§8.1). | REQ-SEC-005 |
| Guest trail token leaks | 32 random bytes, base64url; only a SHA-256 hash stored; admin can revoke ([04 §8](04-database.md)). The link `/{locale}/t/{token}` swaps the token for a short-lived `HttpOnly` cookie and redirects to a clean URL, so the token does not stay in history or `Referer`. `Referrer-Policy: no-referrer` on trail pages. Tokens are redacted from logs. | REQ-SEC-004 |
| Account takeover | Strong password hashing, rate limits, Turnstile, TOTP for admin and finance officer, short admin sessions (§6) | REQ-SEC-003 |
| Cross-site request forgery | Server Actions' built-in origin check; `SameSite=Lax` cookies; webhooks verified by signature | – |
| Cross-site scripting | React escaping; user posts stored as plain text or a safe Markdown subset, sanitised on render; strict content security policy | – |
| Clickjacking, sniffing | `frame-ancestors 'none'`, `X-Content-Type-Options: nosniff`, HSTS (1 year, include subdomains after preview is checked) | – |
| Malicious uploads | Presigned uploads with fixed size and type, file signature check, no SVG uploads, media served from a separate subdomain (§8) | REQ-PRF-003 |
| Student contact details or location leak | Contact-detail filter on posts ([07 §12](07-content-hub-student-teacher.md)); EXIF stripped from images (§8.4) | REQ-CHS-002, REQ-CHS-001 |
| Persona link exposed | Persona-to-student link readable only by the student's teachers and admins through RLS ([04 §7](04-database.md)); never in logs (§13) | REQ-SEC-007 |
| Secrets leaked | Wrangler and GitHub secrets only; secret scanning on the repo; payment keys encrypted in settings | – |
| Vulnerable dependencies | Dependabot weekly; lockfile committed; update the OpenNext adapter and Next.js together | – |
| Staff misuse | Every data-changing staff action written to `audit_log` ([05 §9](05-public-pages-roles-admin.md), [04 §12](04-database.md)) | REQ-ROL-008 |

**Content security policy (starting point)**

```
default-src 'self';
img-src 'self' https://media.azeem-lateef.com https://i.ytimg.com data:;
frame-src https://www.youtube-nocookie.com https://challenges.cloudflare.com;
script-src 'self' 'nonce-{per-request}' https://challenges.cloudflare.com;
connect-src 'self' https://*.r2.cloudflarestorage.com;
frame-ancestors 'none'; base-uri 'self'; form-action 'self';
```

For future institutes, `media.<their-domain>` is added from institute settings.

**Analytics.** Only Cloudflare Web Analytics, which sets no cookies. No third-party trackers or ad scripts, especially on student hub pages.

## 13. Backups, logging and monitoring

### 13.1 Backups

REQ-SEC-006.

| What | How | Kept |
| --- | --- | --- |
| Production database | Nightly GitHub Actions job at 02:30 Pakistan time (21:30 UTC): `pg_dump --format=custom` as `backup_reader`, encrypted with `age` to Sami's public key, uploaded to `tz-prod-backups` | 30 daily, 12 monthly (1st of each month) |
| Recent mistakes | Neon's instant restore (Free: 6 hours of history, up to 1 GB of changes) | 6 hours |
| Before risky migrations | Neon's 1 manual snapshot on Free, taken just before the migration | Until the next one |
| Media in R2 | Not copied on the free tier. R2 itself stores data redundantly. Risk accepted until the upgrade trigger in §14. | – |
| Code and translations | Git repository | Forever |

- The private key to decrypt backups is kept offline by Sami, with a printed copy stored at the madrasa in a sealed envelope (R-06).
- The job alerts Sami by email if it fails or if the dump is under 50% of the previous night's size.
- Expected size: tens of megabytes compressed. 42 dumps should stay under 2 GB of R2.

**Restore test once per phase.** At the end of every phase, before its phase test is signed off:

1. Create a Neon branch `restore-test-YYYYMMDD`.
2. Download last night's dump, decrypt, `pg_restore` into the branch.
3. Run the check queries: row counts per table per institute; sum of donations, allocations and spending per cause; count of trail events per type; last `audit_log` time.
4. Compare with production at dump time. Record date, dump file, duration and result in `docs/ops/restore-log.md`.
5. Delete the branch.

### 13.2 Logging

REQ-SEC-008: logs and error reports never contain anonymous donors' names or students' real names. To make that true by construction:

- All code logs through one logger in `packages/core`. Direct `console.log` is blocked by lint outside it.
- The logger accepts only an **allowlist** of fields:

| Allowed | Never allowed |
| --- | --- |
| `request_id`, `institute_id`, route **template** (`/[locale]/t/[token]`, not the real path), method, status, duration, `user_id`, role names, record IDs, error code, job type | names, display names, emails, phone numbers, addresses, request bodies, form values, query strings, cookies, auth headers, trail tokens, post text, file names from users |

- Unknown fields are dropped and counted, so a developer sees that something was dropped.
- Errors are logged as error class, message key and a stack trace. Error messages from the database are mapped to codes before logging, because Postgres errors can include row values.
- A test in CI runs a sample of flows (record anonymous donation, student posts, sign-in) with a capturing logger and fails if any seeded name or email appears in the output.
- Workers Logs is turned on for both Workers. Its free-plan volume and retention were not verified in this session; check in P0-E1-T11. An external error tracker (such as Sentry's free plan) is optional; if used, it receives the same allowlisted fields only, with request bodies and breadcrumbs off.
- Cloudflare's own request analytics show full URLs. This is another reason URLs never contain personal data (§12) and trail tokens are exchanged at once.

### 13.3 Monitoring

| Check | How | Who is told |
| --- | --- | --- |
| Site up | An external uptime check every 5 minutes on a cached public page that **does not query the database**, so it does not keep Neon awake | Sami (email) |
| Database reachable | `/api/health/db` checked at most once an hour | Sami |
| Errors | Count of 5xx per hour from Workers Logs | Sami |
| Free-tier usage | Monthly review checklist (§14) and the providers' own usage emails | Sami |
| Backups | Nightly job result | Sami |
| Dead-letter queue | Count shown in admin; email if over 0 for a day | Sami, admin |

The uptime service is not chosen. It must have a free plan and must not need a script on our pages.

## 14. Free-tier limits and upgrade triggers

REQ-PRF-005. Limits change. These were read on **2026-11-07** from the pages listed under Sources. Each row says how we expect to use it.

### 14.1 Limits

| Service | Free limit (as of 2026-11-07) | Our expected use | Risk |
| --- | --- | --- | --- |
| Workers requests | 100,000 a day, reset at 00:00 UTC. Over the limit, Cloudflare returns error 1027 (or skips the Worker if the route "fails open"). | A page view can cause several Worker requests (page, data prefetches, server actions). Roughly 10,000 to 20,000 page views a day fit. | Low at launch. |
| Workers CPU time | **10 ms per request**, also for cron runs | Server rendering a React page can take more than 10 ms of CPU. | **High. Most likely limit to hit.** Measured in P0-E1-T02. |
| Worker size | 64 MiB uncompressed per Cloudflare's limits page (updated 2026-10-29), which also says there is no compressed limit. **OpenNext's docs still say 3 MiB compressed on Free.** The sources disagree. | A Next.js app on OpenNext is often several MiB. | Medium. Measured in P0-E1-T02. |
| Worker start-up | Global scope must run within 1 second | – | Low. |
| Subrequests | 50 per request | Queue batches of 10 | Low. |
| Cron Triggers | 5 per account | 4 (§9.2) | Low; no room for more schedules. |
| Static assets | 20,000 files per Worker version, 25 MiB per file | – | Low. Whether static asset requests count toward the 100,000 a day was not verified. |
| Queues | 10,000 operations a day; messages kept 24 hours | About 3 operations per message, so about 3,000 messages a day | Low. |
| Hyperdrive | 100,000 database queries a day | Each request runs `BEGIN`, 3 `set_config`, its queries and `COMMIT`. About 6 to 10 queries per dynamic request, so 10,000 to 16,000 dynamic requests a day. | Medium. Cached public pages reduce it. |
| Workers KV | 100,000 reads, 1,000 writes a day, 1 GB | Rate-limit counters, email daily counter | Low. |
| R2 | 10 GB-month storage, 1 million Class A and 10 million Class B operations a month, no egress fees | Media up to 7 GB (§8.8), backups under 2 GB | Medium after year 1. |
| Cloudflare Images transformations | 5,000 unique a month (not used by design) | 0 | None. |
| Neon storage | 1 GB per project (20 GB across free projects). Over it, writes that add data fail. | Text data for one madrasa: well under 1 GB for years. Media is in R2. | Low. |
| Neon compute | **100 CU-hours per project per month**; scales to zero after 5 minutes idle (fixed on Free), wakes in a few hundred milliseconds. Over the limit, compute is **suspended until next month** and the site cannot reach its data. | At the smallest size (0.25 CU), 100 CU-hours is 400 hours awake a month, about 13 hours a day. Activity spread across the day could exceed it. | **High.** Set the compute to a fixed 0.25 CU. Cache public pages. Batch jobs. Whether Hyperdrive's pooled idle connections stop Neon from scaling to zero was not verified: P0-E1-T05 checks it. |
| Neon egress | 5 GB per project per month. Over it, compute is suspended like above. | Small text responses; backups add one dump a night | Low to medium. |
| Neon branches and history | 10 branches; 6 hours of restore history (1 GB); 1 manual snapshot | 3 long-lived + CI | Low. |
| Resend (proposed) | 3,000 emails a month, 100 a day | Receipts, links, reminders | **Medium.** The 100 a day cap is hit first (§10.3). |
| GitHub Actions | Not verified in this session (pricing for private repositories changed in 2026). | About 2 minutes per backup night, a few minutes per CI run | Check in P0-E1-T07. |
| Turnstile, Cloudflare Access, Workers Logs | Not verified in this session. | – | Check when each is set up. |

### 14.2 Upgrade triggers

Running costs are sponsored for now. Future tech costs can be raised as a cause with its own trail ([05 §10](05-public-pages-roles-admin.md), REQ-DON-013). Sami decides each upgrade and logs it in [08](08-decision-log.md).

| Trigger | Signal | Action |
| --- | --- | --- |
| T-1 CPU | P0 measurement shows typical dynamic pages over 10 ms CPU, or any "exceeded CPU" errors in a day | Move to **Workers Paid: $5 a month**, which includes 10 million requests and 30 million CPU-ms a month, unlimited Hyperdrive queries and 1 million queue operations a month. |
| T-2 Requests | Over 60,000 Worker requests a day on 3 days in a week, or any error 1027 | Workers Paid (same as T-1). |
| T-3 Hyperdrive | Over 60,000 queries a day on 3 days in a week | Workers Paid (unlimited queries). |
| T-4 Neon compute | Over 60 CU-hours used by the 15th of a month, or any suspension | First: more caching and fewer wake-ups. If still over: upgrade Neon to its smallest paid plan (price not verified here; check Neon's pricing page at the time). |
| T-5 Neon storage | Database over 700 MB | Check retention ([04 §13](04-database.md)); then upgrade Neon. |
| T-6 Email | Emails deferred because of the daily cap on 3 days in a month, or over 2,500 sent in a month | Move to the provider's first paid plan, or to Cloudflare Email Service if already on Workers Paid. |
| T-7 R2 storage | Media over 5 GB (admin warning) | Review caps and old media with Moazam; then accept R2's paid storage (priced per GB-month; check at the time) and raise the quota in settings. |
| T-8 Media backup | First time a lost media file would have mattered, or on moving to paid R2 | Add a weekly copy of the public bucket to a second store. |
| T-9 Cron | Need for a sixth schedule | Combine schedules in the daily handler first; otherwise Workers Paid. |
| T-10 Second institute | A second institute is about to go live | Review every row of §14.1, since all limits are shared across institutes. |

**Monthly review (first working day of each month, about 15 minutes):** read Cloudflare's Workers, Queues, Hyperdrive and R2 usage, Neon's CU-hours, storage and egress, and the email count. Compare with the triggers above and note the numbers in `docs/ops/usage-log.md`.

### 14.3 Sources (read 2026-11-07)

- Cloudflare Workers limits (page updated 2026-10-29): https://developers.cloudflare.com/workers/platform/limits/
- Cloudflare Workers pricing, incl. Queues, Hyperdrive, KV (page updated 2026-10-02): https://developers.cloudflare.com/workers/platform/pricing/
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/
- Cloudflare Images pricing (page updated 2026-10-19): https://developers.cloudflare.com/images/pricing/
- Cloudflare Email Service pricing (page updated 2026-06-09): https://developers.cloudflare.com/email-service/platform/pricing/
- Cloudflare OpenNext guide (page updated 2026-10-12): https://developers.cloudflare.com/workers/framework-guides/web-apps/opennext/
- Cloudflare Next.js guide, vinext beta status (page updated 2026-11-05): https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/
- OpenNext for Cloudflare (versions, 3 MiB note, Edge runtime): https://opennext.js.org/cloudflare
- Hyperdrive with Neon (page updated 2026-04-21): https://developers.cloudflare.com/hyperdrive/examples/neon
- Hyperdrive supported features (page updated 2026-11-03): https://developers.cloudflare.com/hyperdrive/reference/supported-databases-and-features
- Neon plans (page updated 2026-11-04): https://neon.com/docs/introduction/plans
- Neon free plan limits and what happens when hit (page updated 2026-10-01): https://neon.com/faqs/free-plan-limits-and-quotas
- Neon scale to zero (page updated 2026-11-04): https://neon.com/docs/introduction/scale-to-zero
- Resend pricing: https://resend.com/pricing
- Better Auth two-factor plugin: https://www.better-auth.com/docs/plugins/2fa

## Requirements covered

**Lines that point to 03**

| Requirement | Where |
| --- | --- |
| REQ-DPR-004 Donor account with email sign-in | §6.2; P0-E5-T02 |
| REQ-PAY-002 Gateway chosen with Sami before P5 | §11.1; P5-E1-T01, P5-E1-T02 |
| REQ-SEC-003 Two-factor for admin and finance officer | §6.4; P0-E5-T06 |
| REQ-SEC-005 No personal data in URLs | §8.1, §12; P0-E1-T10, P1-E3-T32 |
| REQ-SEC-006 Daily backups, restore test per phase | §13.1; P0-E1-T12, P0-E1-T13 |
| REQ-SEC-008 No anonymous donor or student names in logs | §13.2; P0-E1-T11 |
| REQ-PRF-002 Compressed, sized images | §8.4; P2-E1-T31, P3-E4-T02 |
| REQ-PRF-003 Upload caps per media type | §8.3; P2-E1-T30, P3-E4-T01, P3-E4-T05 to T07, P3-E4-T09 |
| REQ-PRF-005 Free tiers with upgrade triggers | §14; P0-E1-T02, P0-E1-T15 |
| REQ-LNG-002 No hard-coded interface text | §7.3; P0-E3-T03 |
| REQ-LNG-004 Remember language choice | §7.2; P0-E3-T02, P0-E3-T07 |
| REQ-LNG-005 Browser language, else English | §7.2; P0-E3-T02 |
| REQ-LNG-008 `/ur` and `/en` prefixes | §7.1; P0-E3-T01, P0-E3-T08 |
| REQ-LNG-009 Bilingual admin content with fallback notice | §7.4; P0-E3-T06 |
| REQ-LNG-011 Emails in the recipient's language | §7.6, §10.4; P1-E3-T30, P2-E7-T04 |
| REQ-MIR-002 Request domain selects the institute | §4.5; P0-E1-T09, P0-E2-T31 |

**Other requirements this document supports**

REQ-SEC-001, REQ-SEC-002 (§4.3, §4.4, §5.3) · REQ-SEC-004 (§12) · REQ-SEC-007 (§12, §13.2) · REQ-STU-001 (§6.2) · REQ-ROL-001, REQ-ROL-002 (§6.3) · REQ-ROL-003 (§6.2) · REQ-ROL-004 (§6.2) · REQ-ROL-008 (§6.4, §12) · REQ-LNG-001, REQ-LNG-003, REQ-LNG-006, REQ-LNG-010, REQ-LNG-012 (§7) · REQ-PRF-001 (§5.5, §8.4) · REQ-PRF-004 (§8.7) · REQ-MOD-006 (§5.5, §8.6) · REQ-CHS-001, REQ-CHS-004 (§8) · REQ-DON-011, REQ-DPR-002, REQ-DPR-009 (§9, §10) · REQ-PAY-001, REQ-PAY-003 to REQ-PAY-008 (§9.4, §11) · REQ-PUB-007 (P0-E3-T09) · REQ-MIR-001 (§4.5, §5.2) · REQ-DON-013 (§14.2).

## Tasks

Status for every task is `todo`. "04 …" in Depends on means the named task in [04](04-database.md), whose ID is set there.

### P0-E1 Repo, environments and deployment to `azeem-lateef.com`

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P0-E1-T01 | Create the monorepo (`apps/web`, `apps/jobs`, `packages/core`, `packages/i18n`, `packages/email`) with strict TypeScript, ESLint, Prettier, Vitest and a bilingual local smoke page for the deployment spike | done | – | – |
| P0-E1-T02 | Spike: deploy a Next.js page through OpenNext to `workers.dev`; record bundle size (compressed and not), start-up time and CPU ms for one dynamic and one cached page; decide on trigger T-1 | in progress | P0-E1-T01 | REQ-PRF-005 |
| P0-E1-T03 | Move `azeem-lateef.com` DNS to Cloudflare after copying every record; confirm the existing mailbox still sends and receives | todo | – | – |
| P0-E1-T04 | Set up the Neon project and `main`, `preview`, `dev` branches. Check `neon_superuser` privileges for P0-E2-T01 and confirm the backup credential options for P0-E1-T12 | done | – | REQ-SEC-001 |
| P0-E1-T05 | Spike: Hyperdrive to Neon; prove transaction-local `set_config` is seen by an RLS policy and does not leak to the next request; check Neon still scales to zero; confirm AR-02 or switch to the fallback | todo | P0-E1-T02, P0-E1-T04 | REQ-SEC-001, REQ-PRF-005 |
| P0-E1-T06 | Wrangler config for web and jobs Workers in preview and production: bindings (Hyperdrive, R2, Queues, KV), secrets, typed env check at start-up; protect preview; verify Better Auth sign-in on the hosted preview through `AUTH_HYPERDRIVE` | todo | P0-E1-T05 | REQ-PRF-005 |
| P0-E1-T07 | CI in GitHub Actions: lint, typecheck, unit tests, missing-translation check, migrations and RLS tests on a short-lived Neon branch | todo | P0-E1-T04, P0-E1-T06, P0-E2-T14 | REQ-SEC-002 |
| P0-E1-T08 | CD: deploy preview on merge to `main`, production on a version tag, migrations before deploy, rollback steps in README | todo | P0-E1-T07 | – |
| P0-E1-T09 | Middleware: host to institute through `resolve_institute`, `www` stripping, alias hosts per environment, "no institute here" 404 | todo | P0-E1-T06, P0-E2-T31 | REQ-MIR-002 |
| P0-E1-T10 | Go live on `azeem-lateef.com`: custom domain, `www` redirect, HTTPS only, HSTS, CSP and other security headers | todo | P0-E1-T03, P0-E1-T08, P0-E1-T09 | REQ-SEC-005 |
| P0-E1-T11 | Logger with field allowlist and redaction; Workers Logs on; CI test that seeded names and emails never reach log output; check Workers Logs free limits | todo | P0-E1-T06 | REQ-SEC-008 |
| P0-E1-T12 | Nightly backup job: `pg_dump` as `backup_reader`, `age` encryption, upload to `tz-prod-backups`, 30 daily and 12 monthly kept, failure email | todo | P0-E1-T04, P0-E1-T08 | REQ-SEC-006 |
| P0-E1-T13 | Restore runbook and first restore test into a Neon branch with check queries; start `docs/ops/restore-log.md` | todo | P0-E1-T12 | REQ-SEC-006 |
| P0-E1-T14 | Caching: confirm cache keys include host and locale; cache rules for static assets and public pages; `no-store` for signed-in, admin and trail pages | todo | P0-E1-T09, P0-E3-T01 | REQ-MIR-002, REQ-PRF-001 |
| P0-E1-T15 | Monitoring: uptime check on a cached page, hourly DB health check, provider usage alerts, monthly usage review checklist and `docs/ops/usage-log.md` | todo | P0-E1-T10 | REQ-PRF-005 |

The first checkpoint uses npm workspaces, Next.js 16, next-intl and a local institute fixture. Lint, type checking and the translation-key test pass. The local OpenNext Worker serves both routes and remembers the visitor's language choice. The Wrangler dry run measured about 5,192 KiB uncompressed and 1,093 KiB gzipped. OpenNext flags Next.js Proxy support as experimental. The `workers.dev` run still needs to measure startup and CPU before P0-E1-T02 can close.

The giving and staff build passed the local Worker checks for bilingual pages, Better Auth two-factor verification, cause editing and archival, opt-in bank publication, redacted audit activity, and manual transfer receipts and public totals. All six SQL suites passed locally and on the disposable Neon validation branch, where all 13 Drizzle entries matched the repository. The final Wrangler dry run measured 15,706.86 KiB uncompressed. The local startup profile sampled 25.1 ms of active CPU time. The protected hosted preview still needs its own startup and request CPU measurements. See the [hosted launch runbook](../docs/hosted-launch.md).

2026-11-08 · The [Tazkiyah project](https://console.neon.tech/app/projects/calm-paper-68484751) is on Neon Free in Singapore with PostgreSQL 18. The isolation suite passed on `dev` and `preview`. The baseline on `main` has zero institute rows. `neon_superuser` has `BYPASSRLS` and `tazkiyah_app` does not. A rollback-only probe confirmed that the administrator can create a dedicated backup role with `BYPASSRLS`. Its dump and restore test is tracked in P0-E1-T12. The hosted Workers spike needs a Wrangler login.

### P0-E2 Database foundation (owned by 04; architecture tasks)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P0-E2-T30 | `withInstituteTx` wrapper with transaction-local institute, user and request IDs and job actor kind. Limit DB clients to the core database module | todo | P0-E1-T05, P0-E2-T07 | REQ-SEC-001 |
| P0-E2-T31 | Add `app.list_active_institutes()` and wire it and `app.resolve_institute(host)` through the pre-context lookup path. Cache host results for 5 minutes | todo | P0-E2-T30, P0-E2-T06 | REQ-MIR-002 |
| P0-E2-T32 | Seed a "Test Institute" with its own host alias in preview and CI, and run 04's cross-institute tests as `tazkiyah_app` through the real wrapper | todo | P0-E2-T31, P0-E1-T07 | REQ-SEC-002 |

### P0-E3 Localization plumbing

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P0-E3-T01 | Add next-intl with `app/[locale]` routing for `ur` and `en`; redirect paths without a prefix | todo | P0-E1-T02 | REQ-LNG-008 |
| P0-E3-T02 | Language choice order: URL, `users.preferred_language`, cookie, `Accept-Language`, English; one-year `NEXT_LOCALE` cookie | todo | P0-E3-T01 | REQ-LNG-004, REQ-LNG-005 |
| P0-E3-T03 | Translation files by namespace in both languages, typed keys, CI check for keys missing in one language, lint rule against literal interface text | todo | P0-E3-T01, P0-E1-T07 | REQ-LNG-001, REQ-LNG-002 |
| P0-E3-T04 | Set `lang` and `dir` on `<html>` from the locale; expose direction to the design system; lint for physical CSS properties (with 02 §8) | todo | P0-E3-T01 | REQ-LNG-006 |
| P0-E3-T05 | Formatting module for rupee amounts, numbers and dates per locale; check Urdu `Intl` data on Workers; fixed-pattern fallback if missing | todo | P0-E3-T01 | REQ-LNG-012 |
| P0-E3-T06 | `pickLocalized` helper with `isFallback` flag and a notice component hook; per-block `lang` and `dir` for fallback text and posts | todo | P0-E3-T01, P0-E2-T03 | REQ-LNG-009, REQ-LNG-010 |
| P0-E3-T07 | Language switch plumbing: same path in the other locale, sets the cookie, saves `users.preferred_language` when signed in | todo | P0-E3-T02, P0-E5-T01 | REQ-LNG-003, REQ-LNG-004 |
| P0-E3-T08 | `hreflang` alternates and a per-host `sitemap.xml` listing both languages | todo | P0-E3-T01, P0-E1-T09 | REQ-LNG-008 |
| P0-E3-T09 | Bilingual skeleton page for the P0 test: logo and name from institute settings, Urdu page right to left | todo | P0-E3-T04, P0-E1-T09, P0-E4-T09 | REQ-PUB-007, REQ-LNG-006 |

### P0-E5 Authentication, roles and permission checks

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P0-E5-T01 | Host Better Auth in Next.js with Drizzle, a tenant-scoped auth transaction, the existing `users` table and host-only cookies | done | P0-E2-T08 | REQ-DPR-004 |
| P0-E5-T02 | Email and password sign-in and sign-up for donors; email verification and password reset through the `EmailSender` interface (console adapter until P1-E3-T30) | todo | P0-E5-T01 | REQ-DPR-004 |
| P0-E5-T03 | Username sign-in for students; block student and staff self-signup; server action for staff to create a student with a one-time password and forced change | todo | P0-E5-T01, P0-E5-T04 | REQ-STU-001 |
| P0-E5-T04 | Roles from `user_roles`; `can(user, action, resource)` generated from the 05 §7 matrix, deny by default; tests per role | done | P0-E5-T01 | REQ-ROL-001, REQ-ROL-002 |
| P0-E5-T05 | Pass the authenticated user ID into each transaction. Guard `/[locale]/admin/**` and check that every server action calls `can()` | in progress | P0-E5-T04, P0-E2-T30 | REQ-SEC-001 |
| P0-E5-T06 | TOTP two-factor for admin and finance officer: forced enrolment, 10 backup codes, no trusted devices, 5-try lockout | done | P0-E5-T04 | REQ-SEC-003 |
| P0-E5-T07 | Rate limits on sign-in, reset and two-factor; Turnstile after 3 failures and on sign-up and reset; neutral error messages in both languages | todo | P0-E5-T02 | REQ-SEC-010 (proposed) |
| P0-E5-T08 | Bootstrap script for Moazam's first admin account; admin creates teacher, editor and finance officer accounts | done | P0-E5-T04, P0-E5-T06 | REQ-ROL-004 |
| P0-E5-T09 | Session rules per role (§6.5); sign out of all devices; end sessions on role change and password reset | done | P0-E5-T04 | REQ-SEC-003 |
| P0-E5-T10 | Write sign-in, failed two-factor, role change and account creation events to `audit_log` with IDs only | todo | P0-E5-T04, P0-E2-T11 | REQ-ROL-008 |

The local Worker serves bilingual sign-in and staff pages. The server checks the user's role in the current institute. Admins and finance officers also need proof of two-factor verification for that session and are signed out after 30 minutes of inactivity. The first-admin command assigns the principal and writes an audit event. Admins can issue single-use setup links for teachers, editors, and finance officers, which they share privately while email delivery is pending. Changes to a user's roles, status, or two-factor setting revoke their sessions. Hosted verification needs the auth migrations, the `AUTH_HYPERDRIVE` binding, and the Better Auth secret on the preview Worker.

2026-11-09 · P0-E5-T01 is done locally. [`auth_isolation.sql`](../db/test/auth_isolation.sql) now runs in `npm test`. It shows that the same email and username in two institutes stay separate, that credentials and sessions are hidden without the host's institute context, that no session can be made for another institute's user, and that `tazkiyah_app` has no access to the `identity` schema. The hosted sign-in check needs Cloudflare, so it moved to P0-E1-T06 ([D-116](08-decision-log.md#d-116)). P0-E5-T04: [`packages/core/src/permissions.ts`](../packages/core/src/permissions.ts) holds the 05 §7 matrix and `can(actor, action, facts)`. Everyone holds the visitor role, a user gets the union of their roles, and anything not granted is denied. Its test parses the 05 §7 tables and fails if any row or cell differs from the code. The staff workspace gate now reads the user's roles from `user_roles` and asks `can()`.

2026-11-09 · P0-E5-T06: [`auth.test.ts`](../apps/web/src/server/auth.test.ts) runs the real Better Auth handler against the migrated schema in PGlite, connected as `tazkiyah_auth` through a local Postgres socket. It shows that an admin who has not enrolled can open nothing but enrolment, and that an editor is not asked for two-factor. Enrolment issues 10 backup codes and sets no trusted-device cookie, even when one is requested. Every later sign-in asks for a code, and 5 wrong codes lock the account for 15 minutes. Better Auth also allows only 3 two-factor requests per 10 seconds per IP. Writing two-factor failures to `audit_log` belongs to P0-E5-T10.

2026-11-09 · P0-E5-T09: [`0016_session_rules.sql`](../db/drizzle/0016_session_rules.sql) adds `identity.session_limits()` for the §6.5 role groups, where the strictest group a user holds wins. A trigger caps each new session's lifetime by role. `identity.touch_session()` ends a session that is past its lifetime or idle too long, and otherwise records the activity. The auth handler runs it on every session lookup, including `/get-session`. `/revoke-sessions` signs a user out of all devices. Role changes already ended sessions through `revoke_sessions_on_role_change`. Better Auth's `revokeSessionsOnPasswordReset` is on, and it gets its end-to-end test with the reset flow in P0-E5-T02. The tests are in `auth.test.ts`.

### P1-E3 Manual donation recording and guest donors (owned by 06; architecture tasks)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P1-E3-T30 | `EmailSender` adapter for the service chosen in Q-06; sending subdomain with SPF, DKIM, DMARC; bilingual layout; guest trail-link email through the queue | todo | P0-E1-T06, P0-E3-T03 | REQ-DPR-002, REQ-LNG-011 |
| P1-E3-T31 | `PaymentProvider` interface and `applyPaymentEvent`; `bank_transfer` provider used by the admin recording form; idempotency key on provider reference | todo | P0-E2-T30, P1-E3-T41, P1-E3-T42 | REQ-PAY-001, REQ-PAY-006 |
| P1-E3-T32 | Guest trail tokens: 32 random bytes, hash stored, token-for-cookie exchange with clean redirect, `no-referrer`, log redaction | todo | P0-E1-T11, P1-E3-T40 | REQ-SEC-004, REQ-SEC-005 |

### P2-E1 Spending entries with receipts (owned by 06; architecture tasks)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P2-E1-T30 | R2 buckets per environment, `media.azeem-lateef.com`, presigned upload flow with `media_assets` rows, signature check and pending clean-up, first used for receipt photos | todo | P0-E1-T06, P0-E2-T09 | REQ-PRF-003, REQ-TRL-011 |
| P2-E1-T31 | Browser image compression to `w480` and `w1280` WebP with EXIF removed; server check of size and missing EXIF | todo | P2-E1-T30 | REQ-PRF-002, REQ-CHS-007 (proposed) |

### P2-E7 Email receipts and notifications

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P2-E7-T01 | Jobs Worker with `queue` handler, `jobs-<env>` queue, batch of 10, 3 retries, dead-letter queue and admin count | todo | P0-E1-T06, P1-E3-T30 | REQ-DON-011 |
| P2-E7-T02 | Receipt email message: enqueue after a donation is recorded; idempotent send with the "receipt sent" marker | todo | P2-E7-T01, P1-E3-T03 | REQ-DON-010, REQ-DON-011 |
| P2-E7-T03 | `scheduled` handler with the two cron schedules; 15-minute sweeper re-enqueues unsent receipts and deferred emails | todo | P2-E7-T01 | REQ-DON-011 |
| P2-E7-T04 | Receipt and notification templates in Urdu and English with plain-text parts; "Anonymous" in staff emails; no names in subjects | todo | P2-E7-T02 | REQ-LNG-011, REQ-DPR-009 |
| P2-E7-T05 | Daily email counter (stop at 90) with the priority order in §10.3; bounce and complaint webhook marks addresses undeliverable | todo | P2-E7-T03 | REQ-DON-011, REQ-PRF-005 |

### P3-E4 Media upload, caps and YouTube embeds

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P3-E4-T01 | Extend the upload flow to every media kind with the caps table (§8.3) and per-role limits from 07 §11 | todo | P2-E1-T30 | REQ-PRF-003 |
| P3-E4-T02 | Responsive image serving: `srcset`, `sizes`, lazy loading, fixed dimensions, one-year immutable caching | todo | P2-E1-T31 | REQ-PRF-002 |
| P3-E4-T03 | Private media route: `can()` and RLS check, 5-minute signed URL, `no-store` | todo | P2-E1-T30, P0-E5-T04 | REQ-CHS-001 |
| P3-E4-T04 | Copy media to the public bucket on approval. Delete and purge the public copy on takedown via `media.purge` | todo | P3-E4-T03, P2-E7-T01, P3-E5-T06, P3-E5-T08 | REQ-CHS-004, REQ-MOD-006 |
| P3-E4-T05 | Audio upload: accepted formats, 10 MB cap, basic player with download fallback | todo | P3-E4-T01 | REQ-PRF-003 |
| P3-E4-T06 | Slides as PDF: 10 MB and 60-page cap, open in the browser's viewer | todo | P3-E4-T01 | REQ-PRF-003 |
| P3-E4-T07 | Short video upload: MP4, 25 MB and 90-second cap, with a prompt to use YouTube for longer videos | todo | P3-E4-T01 | REQ-PRF-003, REQ-PRF-004 |
| P3-E4-T08 | YouTube link parsing, video id validation, lite embed with `youtube-nocookie.com`, CSP frame rule | todo | P0-E1-T10 | REQ-PRF-004 |
| P3-E4-T09 | Storage quota per institute: running total, admin display, warning at 5 GB, block at 7 GB | todo | P3-E4-T01 | REQ-PRF-003, REQ-PRF-005 |

### P3-E5 Sharing scopes, moderation and reports (owned by 07; architecture task)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P3-E5-T30 | Takedown invalidation: revalidate page tags and purge paths so a taken-down post leaves public pages within 60 seconds; automated timing test | todo | P0-E1-T14 | REQ-MOD-006, REQ-CHS-004 |

### P4-E5 Monthly reminders and newsletter

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P4-E5-T01 | Opt-in and unsubscribe plumbing: opaque unsubscribe token, one-click page, `List-Unsubscribe` header | todo | P2-E7-T04, P4-E5-T60 | REQ-PAY-007, REQ-DON-018 (proposed) |
| P4-E5-T02 | Monthly run on the 1st: per-institute recipient list, a run record to prevent double sends, enqueue within the daily allowance and spread the rest | todo | P4-E5-T01, P2-E7-T05 | REQ-PAY-007 |
| P4-E5-T03 | Render the admin's bilingual newsletter (from 05 §8) into each donor's language, with new projects from 05 §10 | todo | P4-E5-T02, P4-E4 | REQ-PAY-007, REQ-LNG-011 |
| P4-E5-T04 | Reminder run report for the admin (sent, deferred, bounced) and a check against upgrade trigger T-6 | todo | P4-E5-T02 | REQ-PRF-005 |

### P5-E1 Gateway selection with Sami (to be detailed later)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P5-E1-T01 | Research candidate card gateways and wallets against §11.1 and §11.2; write a comparison (to be detailed later) | todo | Q-02 answered | REQ-PAY-002 |
| P5-E1-T02 | Decision session with Sami; log the choice in 08; split P5-E2 and P5-E3 into detailed tasks (to be detailed later) | todo | P5-E1-T01 | REQ-PAY-002 |

### P5-E2 Card one-off and recurring donations (to be detailed later)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P5-E2-T01 | Card provider adapter behind `PaymentProvider`: hosted checkout, signed webhook, one-off donations (to be detailed later) | todo | P5-E1-T02, P1-E3-T31 | REQ-PAY-003, REQ-PAY-006 |
| P5-E2-T02 | Recurring monthly and yearly card donations through the gateway's subscriptions; renewal and cancel events (to be detailed later) | todo | P5-E2-T01 | REQ-PAY-003, REQ-DON-003 |

### P5-E3 JazzCash and Easypaisa one-off donations (to be detailed later)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P5-E3-T01 | Wallet provider adapters behind `PaymentProvider` for one-off gifts (to be detailed later) | todo | P5-E1-T02, P1-E3-T31 | REQ-PAY-004, REQ-PAY-006 |
| P5-E3-T02 | Offer the monthly reminder opt-in after a wallet gift (to be detailed later) | todo | P5-E3-T01, P4-E5-T01 | REQ-PAY-007 |

### P5-E4 and P5-E5 (owned by 06; architecture tasks, to be detailed later)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P5-E4-T30 | Daily exchange-rate fetch inside the daily cron, stored with date, used for display only (to be detailed later) | todo | P5-E1-T02, P2-E7-T03 | REQ-PAY-005 |
| P5-E5-T30 | Webhook endpoint hardening: signature check, replay window, queue hand-off, idempotency test (to be detailed later) | todo | P5-E2-T01 | REQ-PAY-006 |

## Acceptance criteria

1. `https://azeem-lateef.com/ur` and `/en` load from the production Worker over HTTPS. `www` redirects to the apex. The existing mailbox still sends and receives after the DNS move.
2. A request with an unknown `Host` gets the "no institute here" 404 and no institute data.
3. The CI suite runs as `tazkiyah_app` through `withInstituteTx`. It verifies that the Test Institute cannot read or change any Markaz Al Azeem row, and that a request with no institute setting sees no rows.
4. A test sends two requests for different institutes over the same pooled connection and shows the second never sees the first's `app.institute_id`.
5. A CI query verifies that `tazkiyah_app` lacks `BYPASSRLS` and owns no table.
6. A visitor whose browser sends `Accept-Language: ur` lands on `/ur`; with no header, on `/en`. After switching to Urdu, a new visit opens in Urdu. A signed-in user's choice follows them to another device.
7. CI fails when a translation key exists in only one language, or when a JSX file contains literal interface text.
8. A cause with only English text, viewed at `/ur/...`, shows the English text with a notice, and that block has `lang="en" dir="ltr"`.
9. The admin and finance officer cannot open any admin page until TOTP is set up, and every later sign-in asks for a code. A student cannot sign up from the public site.
10. `can()` denies an action missing from the permission matrix, and every server action has a test that calls it as a role without permission and gets a refusal.
11. A 12 MB phone photo uploads as two WebP files under 600 KB each, with no EXIF block. A 30 MB MP4 and an SVG file are both refused.
12. A YouTube link loads only a thumbnail until tapped, and then plays from `youtube-nocookie.com`.
13. A taken-down public post and its image are gone from the public page and the media URL within 60 seconds.
14. Recording a donation sends one receipt email in the donor's language. Stopping the jobs Worker for an hour and restarting it still sends the receipt exactly once.
15. With the daily counter at 90, a receipt is deferred to the next day and a password reset is still sent.
16. The log capture test finds no seeded donor name, student real name, email or trail token in any log line.
17. Last night's backup exists in `tz-prod-backups`, is encrypted, and the restore test for the current phase is recorded in `docs/ops/restore-log.md` with matching check-query results.
18. The P0 spike results (bundle size, CPU ms per page) and the decision on trigger T-1 are written in the decision log.
19. Recording a bank transfer goes through `PaymentProvider` (`bank_transfer`) and `applyPaymentEvent`, and recording the same bank reference twice creates only one donation.
20. The monthly usage review for the current month is filled in `docs/ops/usage-log.md`.

## Proposed requirements

These are not approved. Do not build on them until they are added to [01](01-requirements-checklist.md) with an open question in [00 §6](00-MASTER-PLAN.md#open-questions).

- [ ] REQ-CHS-007 (proposed) Uploaded images have location and device metadata (EXIF) removed before they are stored. MUST → 03 §8
- [ ] REQ-SEC-010 (proposed) Sign-in, password reset and two-factor attempts are rate-limited, and repeated failures lock the account for a short time. SHOULD → 03 §6
- [ ] REQ-DON-018 (proposed) Every monthly reminder or newsletter email has a one-click unsubscribe link that works without signing in. MUST → 03 §9
