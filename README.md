# Tazkiyah

Tazkiyah (تزکیہ) is a donation and community platform for Pakistani madrasas and non-profit student institutes. The first institute is **Markaz Al Azeem**, Jama Masjid Al-Azeem, Sahiwal (`azeem-lateef.com`).

The planned platform has three parts.

1. Takes donations with a full, first-in-first-out donation trail.
2. Gives students a safe community hub to post, ask and share.
3. Gives teachers a hub to publish verified knowledge.

## Run the bilingual preview

Use Node.js 24 LTS and npm from the repository root.

```sh
npm ci
npm run dev
```

Open the local URL printed by Next.js and add `/en` for English or `/ur` for Urdu. The root URL uses your saved language choice or your browser's preference, with English as the fallback.

The preview reads the institute identity and colours from a local fixture. Its logo is [Markaz Al Azeem Emblem](<assets/logo/Markaz Al Azeem Emblem.png>). The web app serves the smaller WebP exports in `apps/web/public/branding/`.

```sh
npm run lint
npm run typecheck
npm test
npm run build:worker
npm run preview:worker
```

The last two commands build and serve the Cloudflare Worker locally. For a protected preview or production deployment, follow the [hosted launch runbook](docs/hosted-launch.md).

For the current Vercel handoff, see [Run Tazkiyah on Vercel](docs/vercel.md).

## Run database migrations

`npm test` applies every migration and runs every `db/test/*.sql` suite, including the generated cross-institute [isolation harness](db/test/isolation_harness.sql), in PGlite, an in-process Postgres. It needs no database server or credentials. A new table must get fixture rows in both harness institutes, or the harness fails.

The [Tazkiyah Neon project](https://console.neon.tech/app/projects/calm-paper-68484751) uses PostgreSQL 18. Rehearse migrations on a disposable database before applying them to a shared branch. Point both `psql` and `MIGRATION_DATABASE_URL` at the test database's direct connection as its administrator. Keep the connection credentials in your local environment.

```sh
npm run db:migrate
psql "$MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f db/test/schema_policy_catalog.sql \
  -f db/test/institute_isolation.sql -f db/test/staff_and_public_content.sql \
  -f db/test/auth_isolation.sql -f db/test/causes.sql -f db/test/manual_donations.sql \
  -f db/test/guest_trail.sql -f db/test/isolation_harness.sql
```

Drizzle uses one migration history in [db/drizzle](db/drizzle). On a fresh database the baseline provisions roles and creates the schema. For an existing database, the command verifies the six original migration checksums before replacing their journal with the equivalent Drizzle baseline entry. The integration tests roll back their fixture rows and temporary grants.

Edit the [Drizzle schema](packages/core/src/db/schema.ts) and run `npm run db:generate -- --name describe_change`. Review the generated SQL before applying it. Use `npm run db:generate -- --custom --name describe_change` for PostgreSQL-specific changes such as grants, triggers, functions and security-barrier views. Put custom SQL between the generated role statements. Apply either kind with `npm run db:migrate` and keep applied migrations immutable.

After applying the migrations, run `psql "$MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f db/seed/markaz_al_azeem.sql` to seed Markaz Al Azeem's bilingual settings and seven draft causes. Rerunning the seed adds missing drafts and preserves existing settings and causes.

## Configure Better Auth

The Next.js app hosts Better Auth under `/api/auth`. Drizzle manages the identity tables in the same PostgreSQL database as the application. The auth handler resolves the institute from the request host before it reads credentials or creates a session.

- Apply the migrations first. They create the restricted `tazkiyah_auth` role. As the database administrator, set its password using `\password tazkiyah_auth` in psql and enable login with `ALTER ROLE tazkiyah_auth LOGIN`.
- Set a random `BETTER_AUTH_SECRET` of at least 32 characters. For local development set `AUTH_DATABASE_URL` to the connection for `tazkiyah_auth` in `apps/web/.env.local`. For the Worker, configure an `AUTH_HYPERDRIVE` binding with that role's connection and set the secret in Cloudflare.
- For local HTTP, set `BETTER_AUTH_LOCAL_ORIGIN` to the exact loopback origin, such as `http://127.0.0.1:3000`, and `BETTER_AUTH_LOCAL_INSTITUTE_DOMAIN` to the institute domain seeded on that branch, such as `azeem-lateef.com`.

To create the first admin and principal, seed the institute and run the command below with its direct administrative `MIGRATION_DATABASE_URL`. Use an email address confirmed with the intended admin and have them enter their password at the hidden prompt.

```sh
npm run db:bootstrap-admin -- azeem-lateef.com admin@example.test "Admin Name"
```

The command stops if the institute already has an admin or principal or the email belongs to an existing account. Sign in at `/en/sign-in` or `/ur/sign-in`, open **Admin workspace**, and follow the authenticator setup. Save the recovery codes when shown. Admin and finance officer sessions require two-factor verification and lock after 30 minutes of inactivity.

Use **Invite a staff member** in the admin workspace to create a teacher, editor, or finance officer setup link. Share it privately so the recipient can choose their password. Links expire after 24 hours and can be redeemed once. Submit the same email and role again to replace a pending link. Donors can register at `/en/signup` or `/ur/signup`, and the sign-in page links to password recovery. Hosted account email uses Resend.

Open **Staff directory** from the admin workspace to check invitation status, search by name or email, and filter by role or account status. Admins can edit roles or suspend and restore access for other staff. These changes revoke the affected sessions. The principal and the signed-in admin are protected from changes through the directory.

Editors and admins can open **Site pages** to update the home introduction, About, Facilities, and Daily Life. Enter the title and text in both languages, save a draft, and preview it before publishing. The public site serves the last published version, and it links to Facilities and Daily Life when those pages are published.

In **Home introduction**, update the figures and English and Urdu labels for the Education, Meals, and Clinic cards. The introduction and figures publish together.

## Manage causes and bank transfers

Administrators can create, publish, and close bilingual giving causes in **Manage giving causes**. Published causes appear in the public directory with their current-period totals.

Administrators and finance officers can open **Record a bank transfer** after completing two-factor verification. Use a confirmed bank statement credit. The workspace records the transfer, assigns a receipt number and adds its received and, when applicable, allocated events. Transfers start anonymous and any supplied donor email remains private. The admin-only **Audit log** shows redacted activity.

Open **Bank accounts** as an administrator to enter verified institute accounts for finance staff. Review each account separately and confirm publication before it appears on the Give page. Hiding an account takes it off the Give page while keeping it available to staff for recording.

The seed supplies the institute's address and directions. An authorized database operator can enter verified phone and email details before launch.

## Share a guest donor trail

Record the transfer with the donor's verified email. As a two-factor verified administrator, open **Private donor links** and enter the receipt number and matching email. Choose the link language, confirm, then copy and share the link privately. The recipient can open it without an account to see their recorded gifts and print bilingual donation receipts. The original link is needed to reopen the trail after a refresh.

Generate a replacement link or revoke access from the same workspace. Replacing a link disables the old one across all gifts from that guest donor. The database stores the link's hash. When a receipt recipient's email is confirmed during recording, the app queues an email for the [receipt job](docs/vercel.md#receipt-email).

## Add campus photos and video

Place approved WebP photos and the film poster in `apps/web/public/campus/`. Replace the sample entries in [campus-media.ts](apps/web/src/institutes/campus-media.ts) with their dimensions, Urdu and English descriptions and captions. Put the wide lead photo first. Additional photos appear in the gallery. Supply smaller WebP variants for mobile where available. Set `sample: false` after replacing all sample entries.

For a film, add an official YouTube video ID or an MP4 path and available WebVTT caption files. The player uses a local poster, and the video starts on demand. The emblem fills the lead frame until the first photo is ready.

## Where things are

| Path | What it holds |
| --- | --- |
| `plan/00-MASTER-PLAN.md` | The source of truth. Read it first. |
| `plan/01-requirements-checklist.md` | Every requirement as one testable line. |
| `plan/02` to `plan/07` | Specialist plans: design, architecture, database, pages and roles, donations, content hub. |
| `plan/08-decision-log.md` | Every decision with its reason. |
| `plan/09-consistency-check.md` | The latest consistency check: coverage, fixes and open items. |
| `docs/agent-prompt.md` | The brief the plan was written from. |
| `assets/logo/` | The source emblem and logo alternatives. |

## Stack

Next.js on Cloudflare, Drizzle with Postgres on Neon, Urdu and English throughout.
