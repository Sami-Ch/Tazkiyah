# Run Tazkiyah on Vercel

Import the [Tazkiyah repository](https://github.com/Sami-Ch/Tazkiyah). Use **Next.js**, set **Root Directory** to `apps/web`, and enable **Include source files outside of the Root Directory** for the shared workspace packages. Use Node.js 24 and the default build command. Select the Git branch you intend to deploy.

The app's `vercel.json` runs `npm ci --include=dev` so TypeScript and the type packages are present during the build. Clear any older Install Command override in Vercel or set it to the same command. [Vercel build configuration](https://vercel.com/docs/builds/configure-a-build#install-command)

## Web app environment

Set these variables in the Vercel environment for the database and domain you intend to use.

| Variable | Value |
| --- | --- |
| `AUTH_DATABASE_URL` | The Neon connection for the restricted `tazkiyah_auth` login on that environment's branch |
| `BETTER_AUTH_SECRET` | A unique random secret of at least 32 characters |
| `PUBLIC_SITE_ORIGINS` | `https://azeem-lateef.com` when the public domain is ready to index. Leave unset for preview. |
| `RESEND_API_KEY` | A Resend sending key for the verified sending domain |
| `AUTH_EMAIL_FROM` | A verified Resend sender such as `accounts@notify.azeem-lateef.com` |
| `AUTH_EMAIL_REPLY_TO` | Optional. The madrasa's reply address. |

Use the database setup and administrator bootstrap in the [README](../README.md#run-database-migrations). Migrations use the direct administrative connection outside Vercel. Configure the restricted runtime connection after migrating. To test database-backed pages on a stable `*.vercel.app` hostname, add that exact hostname as a secondary domain in `app.institute_domains` on the preview database. Keep production and preview credentials separate. Vercel supplies the HTTPS and client IP headers when system environment variables are enabled. [Vercel monorepo setup](https://vercel.com/docs/monorepos) · [Vercel request headers](https://vercel.com/docs/headers/request-headers)

## Receipt email

The app queues a receipt when staff confirm the recipient email while recording a transfer. The receipt job sends it through Resend. Set the following variables before scheduling it.

| Variable | Value |
| --- | --- |
| `RECEIPT_JOBS_DATABASE_URL` | The connection for the restricted `tazkiyah_mail` login on the same Neon branch. Set its password after migrating and enable login. |
| `RECEIPT_EMAIL_FROM` | A verified Resend sender such as `receipts@notify.azeem-lateef.com` |
| `RECEIPT_EMAIL_REPLY_TO` | Optional. The madrasa's reply address. |
| `RECEIPT_EMAIL_LINK_KEY` | A stable random 32-byte secret encoded as 64 hexadecimal characters |
| `CRON_SECRET` | A separate random secret used to authorize job requests |

Schedule `GET /api/jobs/receipt-email` with `Authorization: Bearer <CRON_SECRET>`. A successful invocation returns `204`. Vercel Cron sends that header automatically when `CRON_SECRET` is configured. The plan calls for a 15-minute sweep. Vercel Hobby Cron runs at most once daily, so the repository leaves scheduling configurable. A separate scheduler can call the same endpoint. Receipt links use the institute's primary domain. [Vercel Cron authorization](https://vercel.com/docs/cron-jobs/manage-cron-jobs#securing-cron-jobs) · [Vercel Cron limits](https://vercel.com/docs/cron-jobs/usage-and-pricing)
