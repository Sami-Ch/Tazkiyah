SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."site_page_drafts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"slug" text NOT NULL,
	"title" "app"."localized_text" NOT NULL,
	"body" "app"."localized_text" NOT NULL,
	"revision" uuid DEFAULT gen_random_uuid() NOT NULL,
	"pending" boolean DEFAULT true NOT NULL,
	CONSTRAINT "site_page_drafts_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "site_page_drafts_institute_id_slug_unique" UNIQUE("institute_id","slug"),
	CONSTRAINT "site_page_drafts_slug_check" CHECK (slug in ('home', 'about', 'facilities', 'daily-life'))
);
--> statement-breakpoint
ALTER TABLE "app"."site_page_drafts" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."site_page_drafts" ADD CONSTRAINT "site_page_drafts_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE POLICY "iso" ON "app"."site_page_drafts" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));
--> statement-breakpoint
grant usage on schema public_api to tazkiyah_auth;
grant select on public_api.site_pages to tazkiyah_auth;
--> statement-breakpoint
create function identity.can_edit_site_pages(session_id uuid) returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return (app.has_role('admin') or app.has_role('editor')) and exists (
  select 1 from identity.sessions s
  join app.users u on (u.institute_id, u.id) = (s.institute_id, s.user_id)
  where s.id = session_id and s.institute_id = app.current_institute_id()
    and s.user_id = app.current_user_id() and s.expires_at > now()
    and u.status = 'active' and not u.must_change_password
    and (
      not (app.has_role('admin') or app.has_role('finance_officer'))
      or (s.updated_at > now() - interval '30 minutes'
        and s.two_factor_verified_at is not null and u.two_factor_enabled
        and exists (
          select from identity.two_factor f
          where (f.institute_id, f.user_id) = (s.institute_id, s.user_id) and f.verified
        ))
    )
);
--> statement-breakpoint
create function identity.read_site_pages(session_id uuid)
returns table (slug text, title jsonb, body jsonb, revision uuid, pending boolean, published boolean)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select slots.slug, coalesce(d.title, p.title)::jsonb, coalesce(d.body, p.body)::jsonb, d.revision,
    coalesce(d.pending, p.status = 'draft', false),
    coalesce(p.status = 'published' and p.published_at <= now(), false)
  from (values ('home'), ('about'), ('facilities'), ('daily-life')) as slots(slug)
  left join app.site_page_drafts d on d.institute_id = app.current_institute_id() and d.slug = slots.slug
  left join app.site_pages p on p.institute_id = app.current_institute_id() and p.slug = slots.slug
  where identity.can_edit_site_pages(session_id)
$function$;
--> statement-breakpoint
create function identity.save_site_page(
  session_id uuid, page_slug text, expected_revision uuid, page_title jsonb, page_body jsonb
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  current_revision uuid;
begin
  if not identity.can_edit_site_pages(session_id) then return 'denied'; end if;
  if page_slug is null or page_slug not in ('home', 'about', 'facilities', 'daily-life')
    or not coalesce(app.valid_localized_text(page_title) and page_title ?& array['en', 'ur'], false)
    or not coalesce(app.valid_localized_text(page_body) and page_body ?& array['en', 'ur'], false)
    or greatest(length(page_title ->> 'en'), length(page_title ->> 'ur')) > 120
    or greatest(length(page_body ->> 'en'), length(page_body ->> 'ur')) > 12000
  then return 'invalid'; end if;

  perform pg_advisory_xact_lock(hashtextextended(tenant::text || ':site-page:' || page_slug, 0));
  select revision into current_revision from app.site_page_drafts where institute_id = tenant and slug = page_slug;
  if expected_revision is distinct from current_revision then return 'stale'; end if;

  insert into app.site_page_drafts (institute_id, slug, title, body)
  values (tenant, page_slug, page_title, page_body)
  on conflict (institute_id, slug) do update
    set title = excluded.title, body = excluded.body, revision = gen_random_uuid(), pending = true;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles, action, entity_table, entity_id)
  values (tenant, actor, 'user', array[case when app.has_role('admin') then 'admin' else 'editor' end],
    'site_page.draft_saved', 'site_pages', page_slug);
  return 'saved';
end
$function$;
--> statement-breakpoint
create function identity.publish_site_page(session_id uuid, page_slug text, expected_revision uuid)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  draft app.site_page_drafts%rowtype;
begin
  if not identity.can_edit_site_pages(session_id) then return 'denied'; end if;
  if page_slug is null or page_slug not in ('home', 'about', 'facilities', 'daily-life') then return 'invalid'; end if;

  perform pg_advisory_xact_lock(hashtextextended(tenant::text || ':site-page:' || page_slug, 0));
  select * into draft from app.site_page_drafts where institute_id = tenant and slug = page_slug;
  if not found or not draft.pending or expected_revision is distinct from draft.revision then return 'stale'; end if;

  insert into app.site_pages (institute_id, slug, title, body, status, published_at)
  values (tenant, page_slug, draft.title, draft.body, 'published', now())
  on conflict (institute_id, slug) do update
    set title = excluded.title, body = excluded.body, status = 'published', published_at = excluded.published_at;
  update app.site_page_drafts set pending = false, revision = gen_random_uuid() where id = draft.id;
  return 'published';
end
$function$;
--> statement-breakpoint
revoke all on function identity.can_edit_site_pages(uuid) from public;
revoke all on function identity.read_site_pages(uuid) from public;
revoke all on function identity.save_site_page(uuid, text, uuid, jsonb, jsonb) from public;
revoke all on function identity.publish_site_page(uuid, text, uuid) from public;
grant execute on function identity.read_site_pages(uuid) to tazkiyah_auth;
grant execute on function identity.save_site_page(uuid, text, uuid, jsonb, jsonb) to tazkiyah_auth;
grant execute on function identity.publish_site_page(uuid, text, uuid) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
