SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
create function app.valid_home_facts(document jsonb) returns boolean
language sql immutable
set search_path = pg_catalog, pg_temp
return case when jsonb_typeof(document) = 'object' then
  document ?& array['education', 'meals', 'clinic']
  and (document - array['education', 'meals', 'clinic']) = '{}'::jsonb
  and not exists (
    select from jsonb_each(document) as entry(key, card)
    where not case
      when jsonb_typeof(card) = 'object' and jsonb_typeof(card -> 'label') = 'object' then coalesce(
      (card - array['value', 'label']) = '{}'::jsonb
      and case when jsonb_typeof(card -> 'value') = 'number' then
        (card ->> 'value')::numeric between 0 and 999999
        and mod((card ->> 'value')::numeric, 1) = 0
      else false end
      and app.valid_localized_text(card -> 'label')
      and (card -> 'label') ?& array['en', 'ur']
      and ((card -> 'label') - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(card -> 'label' ->> 'en'), length(card -> 'label' ->> 'ur')) <= 120,
      false)
      else false
    end
  )
else false end;
--> statement-breakpoint
ALTER TABLE "app"."site_page_drafts" ADD COLUMN "facts" jsonb;--> statement-breakpoint
ALTER TABLE "app"."site_pages" ADD COLUMN "facts" jsonb;--> statement-breakpoint
ALTER TABLE "app"."site_page_drafts" ADD CONSTRAINT "site_page_drafts_facts_check" CHECK (facts is null or (slug = 'home' and app.valid_home_facts(facts)));--> statement-breakpoint
ALTER TABLE "app"."site_pages" ADD CONSTRAINT "site_pages_facts_check" CHECK (facts is null or (slug = 'home' and app.valid_home_facts(facts)));
--> statement-breakpoint
create or replace view public_api.site_pages with (security_barrier = true) as
select p.institute_id, p.slug, p.title, p.body, p.published_at,
  m.storage_key as cover_storage_key, m.variants as cover_variants, m.alt_text as cover_alt_text, p.facts
from app.site_pages p
join public_api.institute_public i on i.institute_id = p.institute_id
left join app.media_assets m on (m.institute_id, m.id) = (p.institute_id, p.cover_media_id)
  and m.purpose = 'cover' and m.kind = 'image' and m.status = 'ready'
  and m.visibility = 'public' and not m.shows_face
where p.status = 'published' and p.published_at <= now();

--> statement-breakpoint
drop function identity.read_site_pages(uuid);
--> statement-breakpoint
create function identity.read_site_pages(session_id uuid)
returns table (slug text, title jsonb, body jsonb, revision uuid, pending boolean, published boolean, facts jsonb)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select slots.slug, coalesce(d.title, p.title)::jsonb, coalesce(d.body, p.body)::jsonb, d.revision,
    coalesce(d.pending, p.status = 'draft', false),
    coalesce(p.status = 'published' and p.published_at <= now(), false), coalesce(d.facts, p.facts)
  from (values ('home'), ('about'), ('facilities'), ('daily-life')) as slots(slug)
  left join app.site_page_drafts d on d.institute_id = app.current_institute_id() and d.slug = slots.slug
  left join app.site_pages p on p.institute_id = app.current_institute_id() and p.slug = slots.slug
  where identity.can_edit_site_pages(session_id)
$function$;
--> statement-breakpoint
create function identity.save_home_page(
  session_id uuid, expected_revision uuid, page_title jsonb, page_body jsonb, page_facts jsonb
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  outcome text;
begin
  if not app.valid_home_facts(page_facts) then return 'invalid'; end if;

  outcome := identity.save_site_page(session_id, 'home', expected_revision, page_title, page_body);
  if outcome = 'saved' then
    update app.site_page_drafts set facts = page_facts
    where institute_id = app.current_institute_id() and slug = 'home';
  end if;
  return outcome;
end
$function$;
--> statement-breakpoint
create or replace function identity.publish_site_page(session_id uuid, page_slug text, expected_revision uuid)
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

  insert into app.site_pages (institute_id, slug, title, body, status, published_at, facts)
  values (tenant, page_slug, draft.title, draft.body, 'published', now(), draft.facts)
  on conflict (institute_id, slug) do update
    set title = excluded.title, body = excluded.body, status = 'published', published_at = excluded.published_at,
      facts = coalesce(excluded.facts, site_pages.facts);
  update app.site_page_drafts set pending = false, revision = gen_random_uuid() where id = draft.id;
  return 'published';
end
$function$;
--> statement-breakpoint
revoke all on function app.valid_home_facts(jsonb) from public;
grant execute on function app.valid_home_facts(jsonb) to tazkiyah_app;
revoke all on function identity.read_site_pages(uuid) from public;
revoke all on function identity.save_home_page(uuid, uuid, jsonb, jsonb, jsonb) from public;
grant execute on function identity.read_site_pages(uuid) to tazkiyah_auth;
grant execute on function identity.save_home_page(uuid, uuid, jsonb, jsonb, jsonb) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
