SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "app"."causes" ADD COLUMN "revision" uuid DEFAULT gen_random_uuid() NOT NULL;
--> statement-breakpoint
create function identity.cause_has_recorded_allocations(p_cause_id uuid) returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return exists (
  select from app.allocations a
  join app.donations d on (d.institute_id, d.id) = (a.institute_id, a.donation_id)
  where a.institute_id = app.current_institute_id() and a.cause_id = p_cause_id
    and a.kind = 'to_cause' and d.status = 'recorded'
);
--> statement-breakpoint
drop function identity.read_causes(uuid);
--> statement-breakpoint
create function identity.read_causes(session_id uuid)
returns table (
  id uuid, slug text, cause_type text, title jsonb, summary jsonb, body jsonb, status text,
  starts_on date, ends_on date, target_paisa bigint, target_period text, stock_year_start_month smallint,
  accepts_zakat boolean, revision uuid, has_recorded_allocations boolean
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select c.id, c.slug, c.cause_type, c.title::jsonb, c.summary::jsonb, c.body::jsonb,
    case when c.status = 'active' and c.ends_on < (now() at time zone 'Asia/Karachi')::date
      then 'closed' else c.status end,
    c.starts_on, c.ends_on, c.target_paisa, c.target_period, c.stock_year_start_month,
    c.accepts_zakat, c.revision, identity.cause_has_recorded_allocations(c.id)
  from app.causes c
  where c.institute_id = app.current_institute_id() and identity.is_staff_admin_session(session_id)
  order by c.created_at desc, c.id
$function$;
--> statement-breakpoint
create function identity.edit_cause(
  session_id uuid, cause_id uuid, expected_revision uuid, kind text,
  cause_title jsonb, cause_summary jsonb, cause_body jsonb, target bigint,
  period text, stock_month smallint, first_day date, last_day date, zakat boolean
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  previous app.causes%rowtype;
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

  if row(cause_title, cause_summary, cause_body, target, first_day, last_day, period, stock_month, zakat)
    is not distinct from row(previous.title::jsonb, previous.summary::jsonb, previous.body::jsonb,
      previous.target_paisa, previous.starts_on, previous.ends_on, previous.target_period,
      previous.stock_year_start_month, previous.accepts_zakat)
  then return 'updated'; end if;

  update app.causes set title = cause_title, summary = cause_summary, body = cause_body,
    target_paisa = target, target_period = period, stock_year_start_month = stock_month,
    starts_on = first_day, ends_on = last_day, accepts_zakat = zakat,
    zakat_approved_by = case when zakat then previous.zakat_approved_by else null end,
    revision = gen_random_uuid()
  where institute_id = tenant and id = cause_id;
  return 'updated';
exception when check_violation or not_null_violation then
  return 'invalid';
end
$function$;
--> statement-breakpoint
drop function identity.transition_cause(uuid, uuid, text);
--> statement-breakpoint
create function identity.transition_cause(
  session_id uuid, cause_id uuid, expected_revision uuid, next_status text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  previous app.causes%rowtype;
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  if next_status is null or next_status not in ('active', 'closed', 'archived') then return 'invalid'; end if;
  if current_setting('transaction_isolation') not in ('read committed', 'read uncommitted')
  then return 'stale'; end if;

  select c.* into previous from app.causes c
  where c.institute_id = tenant and c.id = cause_id
  for update;
  if not found or previous.revision is distinct from expected_revision
  then return 'stale'; end if;

  if next_status = 'archived' then
    if not coalesce(previous.status = 'closed' or (previous.status = 'active' and previous.ends_on < today), false)
    then return 'stale'; end if;
    -- Spending does not exist yet, so every retained allocation is still unspent.
    if identity.cause_has_recorded_allocations(cause_id) then return 'archive_blocked'; end if;
  elsif next_status = 'active' then
    if previous.status <> 'draft' or previous.ends_on < today then return 'stale'; end if;
  elsif previous.status <> 'active' then return 'stale'; end if;

  update app.causes set status = next_status, revision = gen_random_uuid()
  where institute_id = tenant and id = cause_id;
  return 'updated';
end
$function$;
--> statement-breakpoint
revoke all on function identity.read_causes(uuid), identity.cause_has_recorded_allocations(uuid),
  identity.edit_cause(uuid, uuid, uuid, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean),
  identity.transition_cause(uuid, uuid, uuid, text) from public;
grant execute on function identity.read_causes(uuid),
  identity.edit_cause(uuid, uuid, uuid, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean),
  identity.transition_cause(uuid, uuid, uuid, text) to tazkiyah_auth;
--> statement-breakpoint
create or replace view public_api.causes with (security_barrier = true) as
select c.id, c.slug, c.cause_type, c.title, c.summary, c.body, c.target_paisa,
  c.target_period, c.stock_year_start_month, c.starts_on, c.ends_on,
  c.accepts_zakat, c.zakat_approved_by,
  case when c.status = 'active' and c.ends_on < clock.today then 'closed' else c.status end as status,
  c.display_order, c.created_at,
  totals.raised_paisa, totals.lifetime_raised_paisa
from app.causes c
join public_api.institute_public i on i.institute_id = c.institute_id
cross join lateral (select (now() at time zone 'Asia/Karachi')::date as today) clock
cross join lateral (
  select case
    when c.cause_type = 'ongoing' and c.target_period = 'monthly'
      then date_trunc('month', clock.today::timestamp)::date
    when c.cause_type = 'ongoing' and c.target_period = 'yearly'
      then date_trunc('year', clock.today::timestamp)::date
    when c.cause_type = 'yearly_stock'
      then (date_trunc('year', clock.today - months.shift) + months.shift)::date
    else '-infinity'::date
  end as first_day
  from (select make_interval(months => c.stock_year_start_month - 1) as shift) months
) period
cross join lateral (
  select
    coalesce(sum(a.amount_paisa) filter (where d.credited_on >= period.first_day), 0) as raised_paisa,
    coalesce(sum(a.amount_paisa), 0) as lifetime_raised_paisa
  from app.allocations a
  join app.donations d on (d.institute_id, d.id) = (a.institute_id, a.donation_id)
  where a.institute_id = c.institute_id and a.cause_id = c.id
    and a.kind = 'to_cause' and d.status = 'recorded'
) totals
where c.status in ('active', 'closed', 'archived')
  and (c.starts_on is null or c.starts_on <= clock.today);
--> statement-breakpoint
RESET ROLE;
