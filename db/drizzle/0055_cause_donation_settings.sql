SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "app"."spending_entries" ALTER COLUMN "receipt_public" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "app"."causes" ADD COLUMN "receipt_public_by_default" boolean DEFAULT false NOT NULL;
--> statement-breakpoint
-- A null settings object is accepted from the previous version of the app.
-- Supplying an explicit null scholar in the object clears the name.
create function identity.valid_cause_donation_settings(settings jsonb, zakat boolean) returns boolean
language sql immutable
set search_path = pg_catalog, pg_temp
return case
  when settings is null then true
  when jsonb_typeof(settings) <> 'object' then false
  when not (settings ?& array['scholar', 'receiptPublicByDefault'])
    or (settings - array['scholar', 'receiptPublicByDefault']) <> '{}'::jsonb
    or jsonb_typeof(settings -> 'receiptPublicByDefault') <> 'boolean' then false
  when settings -> 'scholar' = 'null'::jsonb then true
  when zakat is not true or jsonb_typeof(settings -> 'scholar') <> 'object' then false
  else app.valid_localized_text(settings -> 'scholar')
    and (settings -> 'scholar') - array['en', 'ur'] = '{}'::jsonb
    and greatest(length(settings -> 'scholar' ->> 'en'), length(settings -> 'scholar' ->> 'ur')) <= 120
    and coalesce(settings -> 'scholar' ->> 'en', '') !~ '[[:cntrl:]]'
    and coalesce(settings -> 'scholar' ->> 'ur', '') !~ '[[:cntrl:]]'
end;
--> statement-breakpoint
drop function identity.create_cause(uuid, text, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean);
--> statement-breakpoint
drop function identity.edit_cause(uuid, uuid, uuid, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean);
--> statement-breakpoint
drop function identity.read_causes(uuid);
--> statement-breakpoint
create function identity.create_cause(
  session_id uuid, cause_slug text, kind text, cause_title jsonb, cause_summary jsonb,
  cause_body jsonb, target bigint, period text, stock_month smallint,
  first_day date, last_day date, zakat boolean, settings jsonb default null
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  if not identity.valid_cause_donation_settings(settings, zakat) then return 'invalid'; end if;
  if cause_slug is null or length(cause_slug) > 80 or cause_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    or not coalesce(app.valid_localized_text(cause_title) and cause_title ?& array['en', 'ur']
      and (cause_title - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_title ->> 'en'), length(cause_title ->> 'ur')) <= 120, false)
    or not coalesce(app.valid_localized_text(cause_summary) and cause_summary ?& array['en', 'ur']
      and (cause_summary - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_summary ->> 'en'), length(cause_summary ->> 'ur')) <= 360, false)
    or (cause_body is not null and not coalesce(app.valid_localized_text(cause_body)
      and cause_body ?& array['en', 'ur'] and (cause_body - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_body ->> 'en'), length(cause_body ->> 'ur')) <= 12000, false))
  then return 'invalid'; end if;

  insert into app.causes (
    institute_id, slug, cause_type, title, summary, body, target_paisa, target_period,
    stock_year_start_month, starts_on, ends_on, accepts_zakat, zakat_approved_by, receipt_public_by_default
  ) values (
    app.current_institute_id(), cause_slug, kind, cause_title, cause_summary, cause_body, target, period,
    stock_month, first_day, last_day, coalesce(zakat, false),
    nullif(settings -> 'scholar', 'null'::jsonb), coalesce((settings ->> 'receiptPublicByDefault')::boolean, false)
  ) on conflict (institute_id, slug) do nothing;
  if found then return 'created'; end if;
  return 'duplicate';
exception when check_violation or not_null_violation then
  return 'invalid';
end
$function$;
--> statement-breakpoint
create function identity.read_causes(session_id uuid)
returns table (
  id uuid, slug text, cause_type text, title jsonb, summary jsonb, body jsonb, status text,
  starts_on date, ends_on date, target_paisa bigint, target_period text, stock_year_start_month smallint,
  accepts_zakat boolean, revision uuid, has_recorded_allocations boolean,
  zakat_approved_by jsonb, receipt_public_by_default boolean
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select c.id, c.slug, c.cause_type, c.title::jsonb, c.summary::jsonb, c.body::jsonb,
    case when c.status = 'active' and c.ends_on < (now() at time zone 'Asia/Karachi')::date
      then 'closed' else c.status end,
    c.starts_on, c.ends_on, c.target_paisa, c.target_period, c.stock_year_start_month,
    c.accepts_zakat, c.revision, identity.cause_has_recorded_allocations(c.id),
    c.zakat_approved_by::jsonb, c.receipt_public_by_default
  from app.causes c
  where c.institute_id = app.current_institute_id() and identity.is_staff_admin_session(session_id)
  order by c.created_at desc, c.id
$function$;
--> statement-breakpoint
create function identity.edit_cause(
  session_id uuid, cause_id uuid, expected_revision uuid, kind text,
  cause_title jsonb, cause_summary jsonb, cause_body jsonb, target bigint,
  period text, stock_month smallint, first_day date, last_day date, zakat boolean, settings jsonb default null
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  previous app.causes%rowtype;
  scholar jsonb;
  receipt_default boolean;
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  -- The ledger read must see allocations committed while this operation waited for the cause lock.
  if current_setting('transaction_isolation') not in ('read committed', 'read uncommitted')
  then return 'stale'; end if;

  select c.* into previous from app.causes c
  where c.institute_id = tenant and c.id = cause_id
  for update;
  if not found or previous.revision is distinct from expected_revision or previous.status = 'archived'
  then return 'stale'; end if;

  if not identity.valid_cause_donation_settings(settings, zakat) then return 'invalid'; end if;
  if kind is distinct from previous.cause_type or zakat is null
    or not coalesce(app.valid_localized_text(cause_title) and cause_title ?& array['en', 'ur']
      and (cause_title - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_title ->> 'en'), length(cause_title ->> 'ur')) <= 120, false)
    or not coalesce(app.valid_localized_text(cause_summary) and cause_summary ?& array['en', 'ur']
      and (cause_summary - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_summary ->> 'en'), length(cause_summary ->> 'ur')) <= 360, false)
    or (cause_body is not null and not coalesce(app.valid_localized_text(cause_body)
      and cause_body ?& array['en', 'ur'] and (cause_body - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_body ->> 'en'), length(cause_body ->> 'ur')) <= 12000, false))
  then return 'invalid'; end if;

  if row(first_day, last_day, period, stock_month, zakat) is distinct from
    row(previous.starts_on, previous.ends_on, previous.target_period, previous.stock_year_start_month, previous.accepts_zakat)
    and (previous.status = 'closed'
      or (previous.status = 'active' and previous.ends_on < today)
      or identity.cause_has_recorded_allocations(cause_id))
  then return 'settings_locked'; end if;

  scholar := case
    when not zakat then null
    when settings is null then previous.zakat_approved_by::jsonb
    else nullif(settings -> 'scholar', 'null'::jsonb)
  end;
  receipt_default := coalesce((settings ->> 'receiptPublicByDefault')::boolean, previous.receipt_public_by_default);

  if row(cause_title, cause_summary, cause_body, target, first_day, last_day, period, stock_month, zakat,
    scholar, receipt_default)
    is not distinct from row(previous.title::jsonb, previous.summary::jsonb, previous.body::jsonb,
      previous.target_paisa, previous.starts_on, previous.ends_on, previous.target_period,
      previous.stock_year_start_month, previous.accepts_zakat,
      previous.zakat_approved_by::jsonb, previous.receipt_public_by_default)
  then return 'updated'; end if;

  update app.causes set title = cause_title, summary = cause_summary, body = cause_body,
    target_paisa = target, target_period = period, stock_year_start_month = stock_month,
    starts_on = first_day, ends_on = last_day, accepts_zakat = zakat,
    zakat_approved_by = scholar, receipt_public_by_default = receipt_default,
    revision = gen_random_uuid()
  where institute_id = tenant and id = cause_id;
  return 'updated';
exception when check_violation or not_null_violation then
  return 'invalid';
end
$function$;
--> statement-breakpoint
revoke all on function identity.valid_cause_donation_settings(jsonb, boolean),
  identity.read_causes(uuid),
  identity.create_cause(uuid, text, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean, jsonb),
  identity.edit_cause(uuid, uuid, uuid, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean, jsonb)
from public;
grant execute on function identity.read_causes(uuid),
  identity.create_cause(uuid, text, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean, jsonb),
  identity.edit_cause(uuid, uuid, uuid, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean, jsonb)
to tazkiyah_auth;
--> statement-breakpoint
-- Copy the cause's current default on insert only. Explicit choices and
-- entries recorded before this migration keep their existing visibility.
create function app.set_spending_receipt_visibility() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.receipt_public is null then
    new.receipt_public := coalesce((
      select c.receipt_public_by_default from app.causes c
      where c.institute_id = new.institute_id and c.id = new.cause_id
    ), false);
  end if;
  return new;
end
$function$;
--> statement-breakpoint
revoke all on function app.set_spending_receipt_visibility() from public;
--> statement-breakpoint
create trigger set_spending_receipt_visibility before insert on app.spending_entries
for each row execute function app.set_spending_receipt_visibility();
--> statement-breakpoint
RESET ROLE;
