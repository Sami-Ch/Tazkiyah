SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Staff edit the institute row (REQ-MIR-001, REQ-PUB-006). Daily or weekly
-- spending batches are the principal's choice (D-013).
ALTER TABLE "app"."institute_settings" ADD COLUMN "spending_batch_mode" text DEFAULT 'weekly' NOT NULL;
--> statement-breakpoint
ALTER TABLE "app"."institute_settings" ADD CONSTRAINT "institute_settings_spending_batch_mode_check" CHECK (spending_batch_mode in ('daily', 'weekly'));
--> statement-breakpoint
-- Visiting times travel inside the public contact object. The column list of
-- public_api.institute_public stays the same, so the existing grants still apply.
create or replace view public_api.institute_public with (security_barrier = true) as
select s.institute_id, s.name, s.short_name, s.parent_body, s.theme, s.address,
  jsonb_strip_nulls(jsonb_build_object(
    'phone', s.contact -> 'phone',
    'whatsapp', s.contact -> 'whatsapp',
    'email', s.contact -> 'email',
    'map_url', s.contact -> 'map_url',
    'visiting', s.contact -> 'visiting'
  )) as contact,
  s.languages, s.default_language, s.timezone, s.base_currency, s.founded_year, s.enabled_modules,
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
    where a.institute_id = s.institute_id and a.is_active and a.show_on_donate
  ), '[]'::jsonb) as bank_accounts
from app.institute_settings s
join app.institutes i on i.id = s.institute_id
where s.institute_id = app.current_institute_id()
  and i.status = 'active' and i.kind = 'institute';
--> statement-breakpoint
-- The two directions already checked in packages/core/src/theme.ts. Staff pick
-- a direction; they do not type hex colours.
create function app.theme_for_direction(direction text) returns jsonb
language sql immutable strict
set search_path = pg_catalog, pg_temp
as $function$
  select case direction
    when 'night-and-paper' then '{
      "version": 1, "direction": "night-and-paper",
      "color": {
        "bg": "#FAF8F3", "surface": "#FFFFFF", "sunken": "#F1EDE4",
        "text": "#1B2333", "text-muted": "#4F5868", "text-disabled": "#8A909B",
        "primary": "#0D254D", "primary-hover": "#1A3A6E", "on-primary": "#FFFFFF",
        "on-primary-muted": "#C9D6E8", "primary-soft": "#E6ECF5",
        "accent": "#A9CCE8", "link": "#1F5A96", "border": "#D9D4C7",
        "border-strong": "#7A808C", "focus": "#C8691C",
        "success": "#1E6B47", "success-soft": "#E4F1E9",
        "warning": "#8A5300", "warning-soft": "#FBF0DC",
        "danger": "#A8322D", "danger-soft": "#F9E5E3",
        "info": "#1F5A96", "info-soft": "#E6EEF7",
        "zakat": "#1E6B47", "zakat-soft": "#E4F1E9",
        "verified": "#7A5A12", "verified-soft": "#F6EED9", "verified-on-primary": "#D9B25C"
      },
      "font": {"latin-heading":"source-serif-4","urdu-heading":"noto-nastaliq-urdu","urdu-body":"noto-naskh-arabic"},
      "radius": {"sm": 4, "md": 8, "lg": 12}
    }'::jsonb
    when 'garden-and-clay' then '{
      "version": 1, "direction": "garden-and-clay",
      "color": {
        "bg": "#F7F5EE", "surface": "#FFFFFF", "sunken": "#EEEADD",
        "text": "#1F2421", "text-muted": "#545B55", "text-disabled": "#8A909B",
        "primary": "#1F4D3A", "primary-hover": "#2B6650", "on-primary": "#FFFFFF",
        "on-primary-muted": "#C9D6E8", "primary-soft": "#E5EFEA",
        "accent": "#9C4A2F", "link": "#1F6B52", "border": "#D9D4C7",
        "border-strong": "#7C8279", "focus": "#0D254D",
        "success": "#1E6B47", "success-soft": "#E4F1E9",
        "warning": "#8A5300", "warning-soft": "#FBF0DC",
        "danger": "#A8322D", "danger-soft": "#F9E5E3",
        "info": "#1F5A96", "info-soft": "#E6EEF7",
        "zakat": "#245A87", "zakat-soft": "#E5EDF5",
        "verified": "#7A5A12", "verified-soft": "#F6EED9", "verified-on-primary": "#D9B25C"
      },
      "font": {"latin-heading":"source-serif-4","urdu-heading":"noto-nastaliq-urdu","urdu-body":"noto-naskh-arabic"},
      "radius": {"sm": 4, "md": 8, "lg": 12}
    }'::jsonb
  end
$function$;
--> statement-breakpoint
create function identity.localized_pair(document jsonb, max_length integer) returns boolean
language sql immutable
set search_path = pg_catalog, pg_temp
return document is null or (
  app.valid_localized_text(document)
  and document ?& array['en', 'ur']
  and (document - array['en', 'ur']) = '{}'::jsonb
  and greatest(length(document ->> 'en'), length(document ->> 'ur')) <= max_length
  and (document ->> 'en') !~ '[[:cntrl:]]'
  and (document ->> 'ur') !~ '[[:cntrl:]]'
);
--> statement-breakpoint
create function identity.read_institute_settings(session_id uuid)
returns table (
  name jsonb, short_name jsonb, parent_body jsonb, address jsonb, contact jsonb,
  theme_direction text, founded_year smallint, spending_batch_mode text,
  principal_user_id uuid, primary_domain text, logo_saved boolean, admins jsonb
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select s.name::jsonb, s.short_name::jsonb, s.parent_body::jsonb, s.address::jsonb, s.contact,
    s.theme ->> 'direction', s.founded_year, s.spending_batch_mode, s.principal_user_id,
    (select d.domain from app.institute_domains d
      where d.institute_id = s.institute_id order by d.is_primary desc, d.domain limit 1),
    s.logo_media_id is not null,
    coalesce((
      select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.full_name) order by lower(u.full_name), u.id)
      from app.users u
      join app.user_roles r on (r.institute_id, r.user_id) = (u.institute_id, u.id) and r.role = 'admin'
      where u.institute_id = s.institute_id and u.status = 'active'
    ), '[]'::jsonb)
  from app.institute_settings s
  where s.institute_id = app.current_institute_id()
    and identity.is_staff_admin_session(session_id)
$function$;
--> statement-breakpoint
create function identity.save_institute_settings(
  session_id uuid, institute_name jsonb, institute_short_name jsonb, institute_parent jsonb,
  institute_address jsonb, institute_contact jsonb, theme_direction text,
  founded smallint, batch_mode text, principal uuid
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  phone text := nullif(btrim(institute_contact ->> 'phone'), '');
  whatsapp text := nullif(btrim(institute_contact ->> 'whatsapp'), '');
  email text := nullif(btrim(institute_contact ->> 'email'), '');
  map_url text := nullif(btrim(institute_contact ->> 'map_url'), '');
  visiting jsonb := institute_contact -> 'visiting';
  digits text;
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  if institute_contact is null or jsonb_typeof(institute_contact) <> 'object'
    or exists (select from jsonb_object_keys(institute_contact) key
      where key not in ('phone', 'whatsapp', 'email', 'map_url', 'visiting'))
    or not identity.localized_pair(institute_name, 160)
    or not identity.localized_pair(institute_short_name, 80)
    or not identity.localized_pair(institute_parent, 160)
    or not identity.localized_pair(institute_address, 240)
    or institute_name is null or institute_address is null
    or theme_direction not in ('night-and-paper', 'garden-and-clay')
    or batch_mode not in ('daily', 'weekly')
    or (founded is not null and founded not between 1800 and 2100)
    or (visiting is not null and visiting <> 'null'::jsonb and not identity.localized_pair(visiting, 240))
  then return 'invalid'; end if;

  if phone is not null then
    digits := regexp_replace(phone, '[^0-9]', '', 'g');
    if phone !~ '^\+?[0-9][0-9 ()-]{5,22}[0-9]$' or length(digits) not between 7 and 15 then
      return 'invalid';
    end if;
  end if;
  if whatsapp is not null then
    digits := regexp_replace(whatsapp, '[^0-9]', '', 'g');
    if whatsapp !~ '^\+?[0-9][0-9 ()-]{5,22}[0-9]$' or length(digits) not between 8 and 15
      or left(digits, 1) = '0' then
      return 'invalid';
    end if;
  end if;
  if email is not null and (
    length(email) > 254 or email !~* '^[a-z0-9._+%-]+@[a-z0-9-]+(\.[a-z0-9-]+)+$'
  ) then return 'invalid'; end if;
  if map_url is not null and (
    length(map_url) > 300 or map_url !~ '^https://[^[:space:][:cntrl:]]+$'
  ) then return 'invalid'; end if;
  if principal is not null and not exists (
    select from app.users u
    join app.user_roles r on (r.institute_id, r.user_id) = (u.institute_id, u.id) and r.role = 'admin'
    where u.institute_id = tenant and u.id = principal and u.status = 'active'
  ) then return 'invalid'; end if;

  update app.institute_settings s set
    name = institute_name,
    short_name = institute_short_name,
    parent_body = institute_parent,
    address = institute_address,
    contact = jsonb_strip_nulls(
      (s.contact - array['phone', 'whatsapp', 'email', 'map_url', 'visiting'])
      || jsonb_build_object(
        'phone', phone, 'whatsapp', whatsapp, 'email', email, 'map_url', map_url,
        'visiting', case when visiting is null or visiting = 'null'::jsonb then null else visiting end
      )
    ),
    theme = app.theme_for_direction(theme_direction),
    founded_year = founded,
    spending_batch_mode = batch_mode,
    principal_user_id = principal,
    updated_by = app.current_user_id()
  where s.institute_id = tenant;
  if not found then return 'denied'; end if;
  return 'updated';
end
$function$;
--> statement-breakpoint
create function identity.read_module_switches(session_id uuid)
returns table (module_name text, enabled boolean)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select known.module_name, known.module_name = any (s.enabled_modules)
  from unnest(array['student_hub', 'teacher_hub', 'new_projects']) as known(module_name)
  join app.institute_settings s on s.institute_id = app.current_institute_id()
  where identity.is_staff_admin_session(session_id)
$function$;
--> statement-breakpoint
create function identity.set_enabled_modules(session_id uuid, modules text[], confirm boolean)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  current_modules text[];
  next_modules text[];
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  if modules is null or exists (
    select from unnest(modules) as candidate(module_name)
    where candidate.module_name not in ('student_hub', 'teacher_hub', 'new_projects')
  ) or (select count(*) from unnest(modules) as candidate(module_name))
    <> (select count(distinct candidate.module_name) from unnest(modules) as candidate(module_name))
  then return 'invalid'; end if;

  select s.enabled_modules into current_modules from app.institute_settings s where s.institute_id = tenant;
  select coalesce(array_agg(known.module_name order by known.ord), '{}') into next_modules
  from unnest(array['student_hub', 'teacher_hub', 'new_projects']) with ordinality as known(module_name, ord)
  where known.module_name = any (modules);

  if exists (
    select from unnest(current_modules) as current_name(module_name)
    where current_name.module_name <> all (next_modules)
  ) and confirm is not true
  then return 'confirm'; end if;

  update app.institute_settings set enabled_modules = next_modules, updated_by = app.current_user_id()
  where institute_id = tenant;
  return 'updated';
end
$function$;
--> statement-breakpoint
revoke all on function app.theme_for_direction(text), identity.localized_pair(jsonb, integer),
  identity.read_institute_settings(uuid),
  identity.save_institute_settings(uuid, jsonb, jsonb, jsonb, jsonb, jsonb, text, smallint, text, uuid),
  identity.read_module_switches(uuid), identity.set_enabled_modules(uuid, text[], boolean)
from public;
--> statement-breakpoint
grant execute on function identity.read_institute_settings(uuid),
  identity.save_institute_settings(uuid, jsonb, jsonb, jsonb, jsonb, jsonb, text, smallint, text, uuid),
  identity.read_module_switches(uuid), identity.set_enabled_modules(uuid, text[], boolean)
to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
