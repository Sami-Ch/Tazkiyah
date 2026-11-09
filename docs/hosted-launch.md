# Hosted launch

Use the [architecture plan](../plan/03-architecture.md) for the deployment design and the [README](../README.md) for local development. Use separate Cloudflare Workers, Hyperdrive configurations, secrets, and Neon branches for preview and production.

| Setting | Protected preview | Public production |
| --- | --- | --- |
| Worker | `tazkiyah-web-preview` | `tazkiyah-web-production` |
| Host | `preview.azeem-lateef.com` | `azeem-lateef.com` |
| Neon branch | `preview` | `main` |
| `AUTH_HYPERDRIVE` | Preview's `tazkiyah_auth` connection | Main's `tazkiyah_auth` connection |
| `BETTER_AUTH_SECRET` | Unique Worker secret | Unique Worker secret |
| `PUBLIC_SITE_ORIGINS` | Unset | `https://azeem-lateef.com` when ready to index |

## Rehearse the database change

1. Build and test from the repository root. The dry run bundles the Worker and its static assets locally.

   ```sh
   npm ci
   npm run lint
   npm run typecheck
   npm test
   npm run build:worker
   (
     cd apps/web
     stage=$(mktemp -d)
     WRANGLER_LOG_PATH="$stage/wrangler.log" node ../../node_modules/wrangler/bin/wrangler.js deploy --dry-run --outdir "$stage/bundle"
   )
   ```

2. Use an approved disposable Neon branch. To rehearse the full adoption, use a short-lived child of `dev` and give it an expiry. The existing `drizzle-validation` branch can exercise migrations after the baseline while it is available. For branches containing sensitive data, choose a schema-only branch and seed synthetic data.
3. Set `MIGRATION_DATABASE_URL` through a secure local environment to the branch's direct administrator connection. Run the Drizzle migrator and the isolation suites on the disposable branch.

   ```sh
   npm run db:migrate
   psql "$MIGRATION_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
     -f db/test/schema_policy_catalog.sql \
     -f db/test/institute_isolation.sql \
     -f db/test/staff_and_public_content.sql \
     -f db/test/auth_isolation.sql \
     -f db/test/causes.sql \
     -f db/test/manual_donations.sql \
     -f db/test/guest_trail.sql
   ```

4. Confirm the Drizzle journal matches the checked-in migration order. Re-run `npm run db:migrate` to verify it has no pending work. If a branch has the six-entry legacy journal, `db/migrate.mjs` validates its checksums, records the equivalent Drizzle baseline, and drops the legacy metadata. Rehearse that transition before using it on a shared branch.
5. Obtain explicit approval for the target shared branch and for replacing its migration metadata. Record the restore point and retain a protected export of the legacy journal. Confirm the exact branch and direct connection before migrating. Apply in `dev`, then `preview`, then `main` after the preview passes. Take a restore point for each target and use production smoke checks instead of inserting test fixtures into `main`.

[Neon branching](https://neon.com/docs/introduction/branching)

## Connect the protected preview

1. In the Cloudflare account that will host the institute, authenticate Wrangler from `apps/web` and verify the selected account.

   ```sh
   node ../../node_modules/wrangler/bin/wrangler.js login
   node ../../node_modules/wrangler/bin/wrangler.js whoami
   ```

2. In the approved preview database, apply the migrations and run `db/seed/markaz_al_azeem.sql` if needed. Add `preview.azeem-lateef.com` as a secondary hostname for the same institute. The transaction below fails if the canonical domain is missing or the preview hostname belongs to a different institute.

   ```sql
   begin;
   set local role tazkiyah_schema_owner;

   insert into app.institute_domains (institute_id, domain, is_primary)
   select institute_id, 'preview.azeem-lateef.com', false
   from app.institute_domains
   where domain = 'azeem-lateef.com'
   on conflict (domain) do nothing;

   do $$
   begin
     if not exists (
       select 1
       from app.institute_domains as canonical
       join app.institute_domains as preview using (institute_id)
       where canonical.domain = 'azeem-lateef.com'
         and preview.domain = 'preview.azeem-lateef.com'
     ) then
       raise exception 'Preview and canonical hostnames must resolve to the same institute';
     end if;
   end;
   $$;

   commit;
   ```

3. As the preview database administrator, set a unique password with `\password tazkiyah_auth` in `psql`, then enable the role with `ALTER ROLE tazkiyah_auth LOGIN`. Create preview Hyperdrive with the role's direct Neon connection and disable query caching to preserve read-after-write behavior for auth and publishing. The migration administrator connection belongs only in the migration environment. Use `npm run db:bootstrap-admin` with the canonical institute domain and the approved preview admin identity if no preview admin exists.
4. Prepare `apps/web/wrangler.preview.jsonc` alongside `wrangler.jsonc` so relative paths resolve. Preserve the current entry point, asset binding, and compatibility settings. Use the preview Worker name, set `hyperdrive` to `[{ "binding": "AUTH_HYPERDRIVE", "id": "PREVIEW_HYPERDRIVE_ID" }]` with the actual ID, and keep `workers_dev` and `preview_urls` disabled. Leave `PUBLIC_SITE_ORIGINS` unset. For a new Worker, deploy without routes first and set a random secret of at least 32 characters at the Wrangler prompt. Run these commands from `apps/web`.

   ```sh
   node ../../node_modules/wrangler/bin/wrangler.js deploy --config wrangler.preview.jsonc
   node ../../node_modules/wrangler/bin/wrangler.js secret put BETTER_AUTH_SECRET --config wrangler.preview.jsonc
   ```

5. Make the DNS zone available to Cloudflare and configure an Access application and explicit reviewer allowlist for the preview hostname before attaching the Worker custom domain. When changing authoritative DNS, copy existing records and verify mail delivery. Add `routes` with `[{ "pattern": "preview.azeem-lateef.com", "custom_domain": true }]` and deploy the reviewed preview configuration again. Verify that an unauthenticated browser sees the Access challenge. In an authenticated browser, confirm `/en`, `/ur`, mobile layout, gallery and video playback, admin sign-in and sign-out, and draft/publish behavior. Verify preview responses request `noindex`, `/robots.txt` disallows crawling, and `/sitemap.xml` contains no URLs. Record Worker bundle size, startup time, and CPU for a dynamic request and a repeat request in Workers observability.

[Hyperdrive setup](https://developers.cloudflare.com/hyperdrive/get-started/) · [Workers custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/) · [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)

## Release production

1. Confirm the preview checks, reviewed content and media, the approved first administrator, and the production restore point. Adopt and apply the Drizzle history to `main` after approval, seed the institute, and verify the canonical hostname resolves to it. Use `npm run db:bootstrap-admin -- azeem-lateef.com admin@example.test "Admin Name"` with the production migration connection, replacing the example identity with the approved admin's. Keep the preview alias on the preview branch. Have the institute verify its receiving accounts. Enter the accounts in the administrator's **Bank accounts** workspace and confirm publication for each account the institute approved for public display.
2. Provision the restricted production database login, cache-disabled Hyperdrive, and unique Worker secret. Use `apps/web/wrangler.production.jsonc` with the production Worker name and Hyperdrive ID. For a new Worker, follow the preview sequence to set the secret before attaching the apex custom domain. Set `PUBLIC_SITE_ORIGINS` in Wrangler `vars` to the exact HTTPS origin when the public version is approved for indexing. The variable also accepts a comma-separated list for future canonical institute origins.
3. Check HTTPS, redirects, both public locales, canonical URLs, language alternates, `robots.txt`, `sitemap.xml`, and the admin sign-in route on the real domain. Verify that public routes and media load, a valid admin can sign in and out, and an unauthenticated visitor cannot reach admin pages. Check Worker errors and latency. Retain the previous Worker deployment and database restore point for rollback.
