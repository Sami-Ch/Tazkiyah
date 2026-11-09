SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The theme shape of 02 §5 (packages/core/src/theme.ts). The database allows
-- only listed names and well-formed values. The app checks completeness and
-- contrast before saving. An empty object means the platform default.
create function app.valid_theme(theme jsonb) returns boolean
language sql immutable
set search_path = pg_catalog, pg_temp
as $function$
  select jsonb_typeof(theme) = 'object'
    and not exists (select from jsonb_object_keys(theme) k
      where k not in ('version', 'direction', 'color', 'font', 'radius'))
    and (not theme ? 'version' or theme -> 'version' = '1')
    and (not theme ? 'direction'
      or theme ->> 'direction' in ('night-and-paper', 'garden-and-clay'))
    and (not theme ? 'color' or (jsonb_typeof(theme -> 'color') = 'object'
      and not exists (select from jsonb_each(theme -> 'color') c
        where c.key not in ('bg', 'surface', 'sunken', 'text', 'text-muted', 'text-disabled',
          'primary', 'primary-hover', 'on-primary', 'on-primary-muted', 'primary-soft', 'accent',
          'link', 'border', 'border-strong', 'focus', 'success', 'success-soft', 'warning',
          'warning-soft', 'danger', 'danger-soft', 'info', 'info-soft', 'zakat', 'zakat-soft',
          'verified', 'verified-soft', 'verified-on-primary')
          or jsonb_typeof(c.value) <> 'string' or c.value #>> '{}' !~ '^#[0-9a-fA-F]{6}$')))
    and (not theme ? 'font' or (jsonb_typeof(theme -> 'font') = 'object'
      and not exists (select from jsonb_each(theme -> 'font') f
        where f.key not in ('latin-heading', 'urdu-heading', 'urdu-body')
          or jsonb_typeof(f.value) <> 'string'
          or f.value #>> '{}' not in ('source-serif-4', 'noto-nastaliq-urdu', 'noto-naskh-arabic'))))
    and (not theme ? 'radius' or (jsonb_typeof(theme -> 'radius') = 'object'
      and not exists (select from jsonb_each(theme -> 'radius') r
        where r.key not in ('sm', 'md', 'lg') or jsonb_typeof(r.value) <> 'number'
          or (r.value #>> '{}')::numeric < 0 or (r.value #>> '{}')::numeric % 1 <> 0)))
$function$;
--> statement-breakpoint
alter table app.institute_settings drop constraint institute_settings_theme_check;
--> statement-breakpoint
alter table app.institute_settings add constraint institute_settings_theme_check
  check (app.valid_theme(theme));
--> statement-breakpoint
RESET ROLE;
