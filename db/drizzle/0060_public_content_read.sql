SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The public site reads published posts and teachers through the same
-- authentication role that already reads causes, the donor wall and spending.
-- The views stay limited to public, consented rows. Reading them calls
-- module_enabled, which only answers whether a public module is on, and the
-- definer function that checks a student's public-work consent.
grant select (theme, enabled_modules) on public_api.institute_public to tazkiyah_auth;
grant execute on function app.module_enabled(text) to tazkiyah_auth;
grant execute on function app.persona_work_may_show(uuid) to tazkiyah_auth;
grant select on public_api.public_posts, public_api.public_teachers to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
