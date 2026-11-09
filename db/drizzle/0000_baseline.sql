-- Provision database roles and application schemas.
do $bootstrap$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'tazkiyah_schema_owner') then
    create role tazkiyah_schema_owner nologin;
  end if;

  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'tazkiyah_app') then
    create role tazkiyah_app nologin;
  end if;

  if exists (
    select 1 from pg_catalog.pg_roles r
    where r.rolname in ('tazkiyah_schema_owner', 'tazkiyah_app')
      and (r.rolsuper or r.rolbypassrls or r.rolcreaterole or r.rolcreatedb
        or r.rolreplication or (r.rolname = 'tazkiyah_schema_owner' and r.rolcanlogin)
        or exists (select 1 from pg_catalog.pg_auth_members m where m.member = r.oid))
  ) then
    raise exception 'Tazkiyah roles have unexpected privileges or memberships';
  end if;

  execute format('grant tazkiyah_schema_owner to %I', current_user);
  execute format('grant connect on database %I to tazkiyah_app', current_database());
end
$bootstrap$;

create schema if not exists app authorization tazkiyah_schema_owner;
create schema if not exists public_api authorization tazkiyah_schema_owner;

do $bootstrap$
begin
  if exists (
    select 1 from pg_catalog.pg_namespace
    where nspname in ('app', 'public_api')
      and nspowner <> 'tazkiyah_schema_owner'::regrole
  ) then
    raise exception 'Tazkiyah schemas must be owned by tazkiyah_schema_owner';
  end if;
end
$bootstrap$;

set local role tazkiyah_schema_owner;
revoke all on schema app, public_api from public;
grant usage on schema app, public_api to tazkiyah_app;
alter default privileges revoke execute on functions from public;
--> statement-breakpoint

-- Common types and helpers.
create function app.valid_localized_text(document jsonb) returns boolean
language sql immutable strict
set search_path = pg_catalog, pg_temp
return case
  when jsonb_typeof(document) <> 'object' or document = '{}'::jsonb then false
  else not exists (
    select 1 from jsonb_each(document) as translation(language, body)
    where language !~ '^[a-z]{2,3}$' or jsonb_typeof(body) <> 'string'
      or body #>> '{}' !~ '[^[:space:]]'
  )
end;

create domain app.localized_text as jsonb check (app.valid_localized_text(value));

create function app.localize(
  document app.localized_text,
  requested_language text,
  fallback_languages text[] default array['ur', 'en']
) returns table (text_value text, is_fallback boolean)
language sql immutable strict
set search_path = pg_catalog, pg_temp
as $function$
  select document ->> language, language <> requested_language
  from unnest(array[requested_language] || fallback_languages)
    with ordinality as choices(language, position)
  where document ? language
  order by position
  limit 1
$function$;

create function app.current_institute_id() returns uuid
language sql stable
set search_path = pg_catalog, pg_temp
return nullif(current_setting('app.institute_id', true), '')::uuid;

create function app.current_user_id() returns uuid
language sql stable
set search_path = pg_catalog, pg_temp
return nullif(current_setting('app.user_id', true), '')::uuid;

create function app.current_trail_donor_id() returns uuid
language sql stable
set search_path = pg_catalog, pg_temp
return nullif(current_setting('app.trail_donor_id', true), '')::uuid;

create function app.touch_updated_at() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  new.updated_at := statement_timestamp();
  return new;
end
$function$;

create function app.forbid_change() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  raise exception 'Append-only table %.% does not allow %', tg_table_schema, tg_table_name, tg_op
    using errcode = '55000';
end
$function$;

grant execute on function app.current_institute_id(), app.current_user_id(), app.current_trail_donor_id(),
  app.valid_localized_text(jsonb), app.localize(app.localized_text, text, text[]) to tazkiyah_app;
--> statement-breakpoint

-- Institutes.
create table app.institutes (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  kind text not null default 'institute' check (kind in ('institute', 'platform_fund')),
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now()
);

create table app.institute_settings (
  institute_id uuid primary key references app.institutes (id),
  name app.localized_text not null,
  short_name app.localized_text,
  parent_body app.localized_text,
  theme jsonb not null check (jsonb_typeof(theme) = 'object'),
  languages text[] not null default array['ur', 'en']
    check (array_position(languages, null) is null),
  default_language text not null default 'en' check (default_language = any (languages)),
  timezone text not null default 'Asia/Karachi',
  base_currency char(3) not null default 'PKR' check (base_currency ~ '^[A-Z]{3}$'),
  address app.localized_text not null,
  contact jsonb not null default '{}' check (jsonb_typeof(contact) = 'object'),
  founded_year smallint,
  enabled_modules text[] not null default '{}'
    check (array_position(enabled_modules, null) is null
      and enabled_modules <@ array['student_hub', 'teacher_hub', 'new_projects']),
  receipt_prefix text not null check (receipt_prefix ~ '^[A-Z0-9]+$'),
  community_enabled boolean not null default false check (not community_enabled),
  updated_at timestamptz not null default now()
);

create trigger touch_updated_at
before update on app.institute_settings
for each row execute function app.touch_updated_at();

create table app.institute_domains (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references app.institutes (id),
  domain text not null unique check (length(domain) <= 253 and domain not like 'www.%'
    and domain ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?([.][a-z0-9]([a-z0-9-]*[a-z0-9])?)*$'),
  is_primary boolean not null default false,
  unique (institute_id, id)
);

create unique index institute_domains_one_primary
on app.institute_domains (institute_id) where is_primary;

create table app.institute_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references app.institutes (id),
  label app.localized_text not null,
  bank_name text not null,
  account_title text not null,
  account_number text,
  iban text,
  branch text,
  for_donation_types text[] not null default array['zakat', 'sadaqah', 'general']
    check (cardinality(for_donation_types) > 0
      and array_position(for_donation_types, null) is null
      and for_donation_types <@ array['zakat', 'sadaqah', 'general']),
  is_active boolean not null default true,
  display_order integer not null default 0,
  check (nullif(btrim(account_number), '') is not null or nullif(btrim(iban), '') is not null),
  unique (institute_id, id)
);

alter table app.institutes enable row level security;
create policy iso on app.institutes as restrictive for all to tazkiyah_app
using (id = app.current_institute_id())
with check (id = app.current_institute_id());

alter table app.institute_settings enable row level security;
create policy iso on app.institute_settings as restrictive for all to tazkiyah_app
using (institute_id = app.current_institute_id())
with check (institute_id = app.current_institute_id());

alter table app.institute_domains enable row level security;
create policy iso on app.institute_domains as restrictive for all to tazkiyah_app
using (institute_id = app.current_institute_id())
with check (institute_id = app.current_institute_id());

alter table app.institute_bank_accounts enable row level security;
create policy iso on app.institute_bank_accounts as restrictive for all to tazkiyah_app
using (institute_id = app.current_institute_id())
with check (institute_id = app.current_institute_id());
--> statement-breakpoint

-- Public institute access.
create function app.resolve_institute(host text) returns uuid
language sql stable strict security definer
set search_path = pg_catalog, pg_temp
return (
  select i.id
  from app.institute_domains d
  join app.institutes i on i.id = d.institute_id
  where d.domain = regexp_replace(regexp_replace(lower(btrim(host)), ':[0-9]+$', ''), '^www[.]', '')
    and i.status = 'active' and i.kind = 'institute'
);

create function app.list_active_institutes() returns setof uuid
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select id from app.institutes where status = 'active' and kind = 'institute' order by id
$function$;

create view public_api.institute_public with (security_barrier = true) as
select
  s.institute_id,
  s.name,
  s.short_name,
  s.parent_body,
  s.theme,
  s.address,
  jsonb_strip_nulls(jsonb_build_object(
    'phone', s.contact -> 'phone',
    'whatsapp', s.contact -> 'whatsapp',
    'email', s.contact -> 'email',
    'map_url', s.contact -> 'map_url'
  )) as contact,
  s.languages,
  s.default_language,
  s.timezone,
  s.base_currency,
  s.founded_year,
  s.enabled_modules,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id,
      'label', a.label,
      'bank_name', a.bank_name,
      'account_title', a.account_title,
      'account_number', a.account_number,
      'iban', a.iban,
      'branch', a.branch,
      'for_donation_types', a.for_donation_types
    ) order by a.display_order, a.id)
    from app.institute_bank_accounts a
    where a.institute_id = s.institute_id and a.is_active
  ), '[]'::jsonb) as bank_accounts
from app.institute_settings s
join app.institutes i on i.id = s.institute_id
where s.institute_id = app.current_institute_id()
  and i.status = 'active' and i.kind = 'institute';

create function app.module_enabled(module_name text) returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return exists (
  select 1 from public_api.institute_public where module_name = any (enabled_modules)
);

grant execute on function app.resolve_institute(text), app.list_active_institutes(),
  app.module_enabled(text) to tazkiyah_app;
grant select on public_api.institute_public to tazkiyah_app;
--> statement-breakpoint

-- Users and roles.
create table app.users (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references app.institutes (id),
  email text check (email = btrim(email) and email <> ''),
  username text check (username = btrim(username) and username <> ''),
  full_name text not null check (full_name ~ '[^[:space:]]'),
  public_name text,
  public_bio app.localized_text,
  date_of_birth date,
  is_orphan boolean not null default false,
  preferred_language text not null default 'en' check (preferred_language in ('en', 'ur')),
  status text not null default 'invited' check (status in ('invited', 'active', 'left', 'suspended')),
  left_at date,
  must_change_password boolean not null default true,
  onboarded_at timestamptz,
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  check (email is not null or username is not null),
  unique (institute_id, id)
);

create unique index users_institute_email on app.users (institute_id, lower(email));
create unique index users_institute_username on app.users (institute_id, lower(username));

create table app.user_roles (
  institute_id uuid not null,
  user_id uuid not null,
  role text not null check (role in ('donor', 'student', 'teacher', 'editor', 'finance_officer', 'admin')),
  can_widen_scope boolean not null default false check (not can_widen_scope or role = 'teacher'),
  granted_by uuid,
  created_at timestamptz not null default now(),
  primary key (institute_id, user_id, role),
  foreign key (institute_id, user_id) references app.users (institute_id, id),
  foreign key (institute_id, granted_by) references app.users (institute_id, id)
);

create index user_roles_granted_by on app.user_roles (institute_id, granted_by);

alter table app.institute_settings
  add column principal_user_id uuid,
  add column updated_by uuid,
  add foreign key (institute_id, principal_user_id) references app.users (institute_id, id),
  add foreign key (institute_id, updated_by) references app.users (institute_id, id);

create function app.check_student_role() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.role = 'donor' then
    return new;
  end if;

  -- Serialize role assignments even when two transactions add different roles.
  update app.users set id = id where institute_id = new.institute_id and id = new.user_id;

  if exists (
    select 1 from app.user_roles r
    where r.institute_id = new.institute_id and r.user_id = new.user_id
      and r.role <> 'donor' and (r.role = 'student') <> (new.role = 'student')
      and (tg_op = 'INSERT' or (r.institute_id, r.user_id, r.role)
        is distinct from (old.institute_id, old.user_id, old.role))
  ) then
    raise exception 'Student and staff roles cannot belong to the same user'
      using errcode = '23514';
  end if;
  return new;
end
$function$;

create trigger check_student_role
before insert or update of institute_id, user_id, role on app.user_roles
for each row execute function app.check_student_role();

create function app.has_role(requested_role text) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
return exists (
  select 1
  from app.user_roles r
  join app.users u on (u.institute_id, u.id) = (r.institute_id, r.user_id)
  join app.institutes i on i.id = r.institute_id
  where r.institute_id = app.current_institute_id()
    and r.user_id = app.current_user_id() and r.role = requested_role
    and u.status in ('active', 'left') and i.status = 'active' and i.kind = 'institute'
);

create function app.is_staff() returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return app.has_role('admin') or app.has_role('teacher')
  or app.has_role('editor') or app.has_role('finance_officer');

create function app.is_member() returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return app.is_staff() or app.has_role('student');

alter table app.users enable row level security;
create policy iso on app.users as restrictive for all to tazkiyah_app
using (institute_id = (select app.current_institute_id()))
with check (institute_id = (select app.current_institute_id()));

create policy user_read on app.users for select to tazkiyah_app
using ((id = (select app.current_user_id()) and status in ('active', 'left'))
  or (select app.has_role('admin')));

create policy own_language on app.users for update to tazkiyah_app
using (id = (select app.current_user_id()) and status in ('active', 'left'))
with check (id = (select app.current_user_id()) and status in ('active', 'left'));

alter table app.user_roles enable row level security;
create policy iso on app.user_roles as restrictive for all to tazkiyah_app
using (institute_id = (select app.current_institute_id()))
with check (institute_id = (select app.current_institute_id()));

create policy role_read on app.user_roles for select to tazkiyah_app
using ((user_id = (select app.current_user_id()) and app.has_role(role))
  or (select app.has_role('admin')));

create policy settings_admin_read on app.institute_settings for select to tazkiyah_app
using ((select app.has_role('admin')));

create policy bank_accounts_admin_read on app.institute_bank_accounts for select to tazkiyah_app
using ((select app.has_role('admin')));

grant execute on function app.has_role(text), app.is_staff(), app.is_member() to tazkiyah_app;
grant select on app.users, app.user_roles, app.institute_settings, app.institute_bank_accounts to tazkiyah_app;
grant update (preferred_language) on app.users to tazkiyah_app;
--> statement-breakpoint

-- Media and pages.
create function app.valid_media_variants(tenant uuid, variants jsonb) returns boolean
language sql immutable strict
set search_path = pg_catalog, pg_temp
return case
  when jsonb_typeof(variants) <> 'object' then false
  else not exists (
    select 1 from jsonb_each(variants) as item(variant, object_key)
    where jsonb_typeof(object_key) <> 'string'
      or not starts_with(object_key #>> '{}', tenant::text || '/')
  )
end;

create table app.media_assets (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references app.institutes (id),
  kind text not null check (kind in ('image', 'audio', 'video', 'slides', 'document', 'youtube')),
  purpose text not null check (purpose in (
    'logo', 'cover', 'post', 'avatar', 'donor_photo', 'staff_photo', 'receipt', 'consent_form', 'sponsorship_update'
  )),
  visibility text not null default 'private' check (visibility in ('public', 'private')),
  storage_key text unique check (starts_with(storage_key, institute_id::text || '/')),
  youtube_id text check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  mime_type text,
  bytes integer check (bytes > 0 and bytes <= case
    when purpose = 'avatar' then 60000
    when kind = 'image' then 600000
    when kind in ('audio', 'slides') then 10000000
    when kind = 'document' then 5000000
    when kind = 'video' then 25000000
    else 0 end),
  width integer check (width > 0),
  height integer check (height > 0),
  duration_s integer check (duration_s > 0 and (kind <> 'video' or duration_s <= 90)),
  page_count integer check (page_count > 0 and (kind <> 'slides' or page_count <= 60)),
  variants jsonb not null default '{}' check (app.valid_media_variants(institute_id, variants)),
  alt_text app.localized_text,
  shows_face boolean not null default false,
  uploaded_by uuid,
  status text not null default 'pending' check (status in ('pending', 'ready', 'rejected', 'deleted')),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (institute_id, id),
  foreign key (institute_id, uploaded_by) references app.users (institute_id, id),
  check (
    (kind = 'youtube' and youtube_id is not null and storage_key is null and mime_type is null and bytes is null)
    or (kind <> 'youtube' and storage_key is not null and mime_type is not null and bytes is not null and youtube_id is null)
  ),
  check (kind <> 'video' or status <> 'ready' or duration_s is not null),
  check (kind <> 'slides' or status <> 'ready' or page_count is not null),
  check ((status = 'deleted') = (deleted_at is not null)),
  check (purpose <> 'consent_form' or visibility = 'private')
);

create index media_assets_uploaded_by on app.media_assets (institute_id, uploaded_by);

alter table app.institute_settings
  add column logo_media_id uuid,
  add foreign key (institute_id, logo_media_id) references app.media_assets (institute_id, id);

alter table app.users
  add column photo_media_id uuid,
  add foreign key (institute_id, photo_media_id) references app.media_assets (institute_id, id);

create index users_photo_media on app.users (institute_id, photo_media_id);

alter table app.media_assets enable row level security;
create policy iso on app.media_assets as restrictive for all to tazkiyah_app
using (institute_id = (select app.current_institute_id()))
with check (institute_id = (select app.current_institute_id()));

create policy media_read on app.media_assets for select to tazkiyah_app
using ((select app.has_role('admin')) or (
  uploaded_by = (select app.current_user_id())
  and (select app.is_member() or app.has_role('donor'))
));

create view public_api.institute_logo with (security_barrier = true) as
select s.institute_id, m.id, m.storage_key, m.variants, m.alt_text
from app.institute_settings s
join public_api.institute_public p on p.institute_id = s.institute_id
join app.media_assets m on (m.institute_id, m.id) = (s.institute_id, s.logo_media_id)
where m.purpose = 'logo' and m.kind = 'image' and m.status = 'ready'
  and m.visibility = 'public' and not m.shows_face;

create table app.site_pages (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references app.institutes (id),
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title app.localized_text not null,
  body app.localized_text not null,
  cover_media_id uuid,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  updated_at timestamptz not null default now(),
  check (status <> 'published' or published_at is not null),
  unique (institute_id, id),
  unique (institute_id, slug),
  foreign key (institute_id, cover_media_id) references app.media_assets (institute_id, id)
);

create index site_pages_cover_media on app.site_pages (institute_id, cover_media_id);

create trigger touch_updated_at
before update on app.site_pages
for each row execute function app.touch_updated_at();

alter table app.site_pages enable row level security;
create policy iso on app.site_pages as restrictive for all to tazkiyah_app
using (institute_id = (select app.current_institute_id()))
with check (institute_id = (select app.current_institute_id()));

create policy staff_page_read on app.site_pages for select to tazkiyah_app
using ((select app.has_role('admin') or app.has_role('editor')));

create view public_api.site_pages with (security_barrier = true) as
select p.institute_id, p.slug, p.title, p.body, p.published_at,
  m.storage_key as cover_storage_key, m.variants as cover_variants, m.alt_text as cover_alt_text
from app.site_pages p
join public_api.institute_public i on i.institute_id = p.institute_id
left join app.media_assets m on (m.institute_id, m.id) = (p.institute_id, p.cover_media_id)
  and m.purpose = 'cover' and m.kind = 'image' and m.status = 'ready'
  and m.visibility = 'public' and not m.shows_face
where p.status = 'published' and p.published_at <= now();

grant select on app.media_assets, app.site_pages, public_api.institute_logo, public_api.site_pages
  to tazkiyah_app;
--> statement-breakpoint

-- Staff and audit.
create table app.audit_log (
  id bigint generated always as identity primary key,
  institute_id uuid not null references app.institutes (id),
  occurred_at timestamptz not null default now(),
  actor_user_id uuid,
  actor_kind text not null check (actor_kind in ('user', 'job', 'guest_token', 'system')),
  actor_roles text[] not null default '{}',
  action text not null,
  entity_table text not null,
  entity_id text not null,
  changes jsonb not null default '{}' check (jsonb_typeof(changes) = 'object'),
  reason text,
  request_id text,
  unique (institute_id, id),
  foreign key (institute_id, actor_user_id) references app.users (institute_id, id)
);

create index audit_log_institute_time on app.audit_log (institute_id, occurred_at desc);
create index audit_log_actor on app.audit_log (institute_id, actor_user_id);

create trigger append_only_rows
before update or delete on app.audit_log
for each row execute function app.forbid_change();

create trigger append_only_truncate
before truncate on app.audit_log
for each statement execute function app.forbid_change();

alter table app.audit_log enable row level security;
create policy iso on app.audit_log as restrictive for all to tazkiyah_app
using (institute_id = (select app.current_institute_id()))
with check (institute_id = (select app.current_institute_id()));

create policy audit_admin_read on app.audit_log for select to tazkiyah_app
using ((select app.has_role('admin')));
grant select on app.audit_log to tazkiyah_app;

create function app.audit_row_change() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  row_before jsonb := case when tg_op = 'INSERT' then '{}'::jsonb else to_jsonb(old) end;
  row_after jsonb := case when tg_op = 'DELETE' then '{}'::jsonb else to_jsonb(new) end;
  target jsonb := case when tg_op = 'DELETE' then row_before else row_after end;
  tenant uuid := (target ->> 'institute_id')::uuid;
  actor uuid := app.current_user_id();
  actor_type text;
  roles text[] := '{}';
  diff jsonb;
begin
  if tenant is distinct from app.current_institute_id() then
    return null;
  end if;

  if actor is not null and app.is_staff() then
    actor_type := 'user';
    select coalesce(array_agg(r.role order by r.role), '{}') into roles
    from app.user_roles r
    where r.institute_id = tenant and r.user_id = actor;
  elsif actor is null and current_setting('app.actor_kind', true) = 'job' then
    actor_type := 'job';
  else
    return null;
  end if;

  select jsonb_object_agg(field, case
    when field in ('status', 'preferred_language', 'role', 'can_widen_scope', 'enabled_modules',
      'visibility', 'is_active', 'community_enabled', 'must_change_password')
      then jsonb_build_object('old', row_before -> field, 'new', row_after -> field)
    else to_jsonb('[redacted]'::text)
    end)
  into diff
  from jsonb_object_keys(row_before || row_after) as keys(field)
  where field not in ('id', 'institute_id', 'created_at', 'updated_at')
    and row_before -> field is distinct from row_after -> field;

  if diff is not null then
    insert into app.audit_log (
      institute_id, actor_user_id, actor_kind, actor_roles,
      action, entity_table, entity_id, changes, request_id
    ) values (
      tenant, actor, actor_type, roles, tg_table_name || '.' || lower(tg_op), tg_table_name,
      coalesce(target ->> 'id', (target ->> 'user_id') || '/' || (target ->> 'role'), tenant::text),
      diff, nullif(current_setting('app.request_id', true), '')
    );
  end if;
  return null;
end
$function$;

create trigger audit_row_change after insert or update on app.users
for each row execute function app.audit_row_change();
create trigger audit_row_change after insert or update or delete on app.user_roles
for each row execute function app.audit_row_change();
create trigger audit_row_change after update on app.institute_settings
for each row execute function app.audit_row_change();
create trigger audit_row_change after insert or update on app.institute_bank_accounts
for each row execute function app.audit_row_change();
create trigger audit_row_change after insert or update on app.media_assets
for each row execute function app.audit_row_change();
create trigger audit_row_change after insert or update on app.site_pages
for each row execute function app.audit_row_change();

create policy staff_page_insert on app.site_pages for insert to tazkiyah_app
with check ((select app.has_role('admin') or app.has_role('editor')));

create policy staff_page_update on app.site_pages for update to tazkiyah_app
using ((select app.has_role('admin') or app.has_role('editor')))
with check ((select app.has_role('admin') or app.has_role('editor')));

grant insert (institute_id, slug, title, body, cover_media_id, status, published_at),
  update (slug, title, body, cover_media_id, status, published_at)
  on app.site_pages to tazkiyah_app;

create policy settings_admin_update on app.institute_settings for update to tazkiyah_app
using ((select app.has_role('admin')))
with check ((select app.has_role('admin')));

grant update (name, short_name, parent_body, theme, languages, default_language,
  timezone, address, contact, founded_year, enabled_modules, logo_media_id)
  on app.institute_settings to tazkiyah_app;
--> statement-breakpoint

RESET ROLE;
