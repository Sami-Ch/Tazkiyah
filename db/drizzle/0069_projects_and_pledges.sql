SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- A new project is a cause with these fields (05 §10, REQ-DON-013).
ALTER TABLE "app"."causes" ADD COLUMN "planned_start" date;
--> statement-breakpoint
ALTER TABLE "app"."causes" ADD COLUMN "why_it_matters" "app"."localized_text";
--> statement-breakpoint
ALTER TABLE "app"."causes" ADD COLUMN "cost_lines" "app"."localized_text";
--> statement-breakpoint
ALTER TABLE "app"."causes" ADD CONSTRAINT "causes_project_category_check" CHECK (
  category is null
  or category in ('facilities', 'education', 'community', 'technology')
  or (
    not listed_as_project
    and length(category) between 1 and 40
    and category ~ '^[a-z][a-z0-9-]*$'
  )
);
--> statement-breakpoint
ALTER TABLE "app"."causes" ADD CONSTRAINT "causes_project_listed_check" CHECK (
  not listed_as_project or category in ('facilities', 'education', 'community', 'technology')
);
--> statement-breakpoint
ALTER TABLE "app"."causes" ADD CONSTRAINT "causes_planned_start_check" CHECK (
  planned_start is null or (extract(day from planned_start) = 1 and planned_start >= date '2000-01-01' and planned_start < date '2100-01-01')
);
--> statement-breakpoint
drop function identity.read_causes(uuid);
--> statement-breakpoint
create function identity.read_causes(session_id uuid)
returns table (
  id uuid, slug text, cause_type text, title jsonb, summary jsonb, body jsonb, status text,
  starts_on date, ends_on date, target_paisa bigint, target_period text, stock_year_start_month smallint,
  accepts_zakat boolean, revision uuid, has_recorded_allocations boolean,
  zakat_approved_by jsonb, receipt_public_by_default boolean,
  listed_as_project boolean, category text, planned_start date, why_it_matters jsonb, cost_lines jsonb
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select c.id, c.slug, c.cause_type, c.title::jsonb, c.summary::jsonb, c.body::jsonb,
    case when c.status = 'active' and c.ends_on < (now() at time zone 'Asia/Karachi')::date
      then 'closed' else c.status end,
    c.starts_on, c.ends_on, c.target_paisa, c.target_period, c.stock_year_start_month,
    c.accepts_zakat, c.revision, identity.cause_has_recorded_allocations(c.id),
    c.zakat_approved_by::jsonb, c.receipt_public_by_default,
    c.listed_as_project, c.category, c.planned_start, c.why_it_matters::jsonb, c.cost_lines::jsonb
  from app.causes c
  where c.institute_id = app.current_institute_id() and identity.is_staff_admin_session(session_id)
  order by c.created_at desc, c.id
$function$;
--> statement-breakpoint
create function identity.set_cause_project(
  session_id uuid, cause_id uuid, expected_revision uuid, show_on_projects boolean,
  project_category text, first_of_month date, why jsonb, costs jsonb
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  previous app.causes%rowtype;
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  select c.* into previous from app.causes c
  where c.institute_id = tenant and c.id = cause_id
  for update;
  if not found or previous.revision is distinct from expected_revision then return 'stale'; end if;
  if show_on_projects is null
    or (show_on_projects and (
      project_category is null
      or project_category not in ('facilities', 'education', 'community', 'technology')
    ))
    or (project_category is not null and project_category not in ('facilities', 'education', 'community', 'technology'))
    or (first_of_month is not null and (extract(day from first_of_month) <> 1
      or first_of_month < date '2000-01-01' or first_of_month >= date '2100-01-01'))
    or not identity.localized_pair(why, 600)
    or not identity.localized_pair(costs, 800)
  then return 'invalid'; end if;

  if row(show_on_projects, project_category, first_of_month, why, costs)
    is not distinct from row(previous.listed_as_project, previous.category, previous.planned_start,
      previous.why_it_matters::jsonb, previous.cost_lines::jsonb)
  then return 'updated'; end if;

  update app.causes set listed_as_project = show_on_projects, category = project_category,
    planned_start = first_of_month, why_it_matters = why, cost_lines = costs,
    revision = gen_random_uuid()
  where institute_id = tenant and id = cause_id;
  return 'updated';
exception when check_violation then
  return 'invalid';
end
$function$;
--> statement-breakpoint
revoke all on function identity.read_causes(uuid),
  identity.set_cause_project(uuid, uuid, uuid, boolean, text, date, jsonb, jsonb) from public;
--> statement-breakpoint
grant execute on function identity.read_causes(uuid),
  identity.set_cause_project(uuid, uuid, uuid, boolean, text, date, jsonb, jsonb) to tazkiyah_auth;
--> statement-breakpoint
-- Public projects. Hidden while the module is off, and drafts stay off the page.
-- Money figures are allocation sums, so no donor column can appear.
create view public_api.projects with (security_barrier = true) as
select c.id, c.slug, c.cause_type, c.title, c.summary, c.category, c.planned_start,
  c.why_it_matters, c.cost_lines, c.accepts_zakat, c.target_paisa,
  case when c.status = 'active' and c.ends_on < clock.today then 'closed' else c.status end as status,
  money.raised_paisa, money.spent_paisa
from app.causes c
join public_api.institute_public i on i.institute_id = c.institute_id
cross join lateral (select (now() at time zone 'Asia/Karachi')::date as today) clock
cross join lateral (
  select
    coalesce(sum(signed.amount) filter (where a.kind = 'to_cause'), 0) as raised_paisa,
    coalesce(sum(signed.amount) filter (where a.kind = 'to_spending'), 0) as spent_paisa
  from app.allocations a
  cross join lateral (
    select case when a.is_reversal then -a.amount_paisa else a.amount_paisa end as amount
  ) signed
  where a.institute_id = c.institute_id and a.cause_id = c.id
) money
where c.listed_as_project
  and c.category in ('facilities', 'education', 'community', 'technology')
  and c.status in ('active', 'closed', 'archived')
  and (c.starts_on is null or c.starts_on <= clock.today)
  and 'new_projects' = any (i.enabled_modules);
--> statement-breakpoint
grant select on public_api.projects to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
-- The period that contains today in Asia/Karachi (06 §13.1).
create function app.pledge_period(starts_on date, frequency text, today date)
returns table (period_start date, period_end date)
language plpgsql immutable
set search_path = pg_catalog, pg_temp
as $function$
declare
  years integer;
  start_day date;
begin
  if frequency = 'monthly' then
    period_start := date_trunc('month', today)::date;
    period_end := (period_start + interval '1 month' - interval '1 day')::date;
    return next;
    return;
  end if;
  if starts_on > today then
    period_start := date_trunc('month', starts_on)::date;
    period_end := (period_start + interval '1 year' - interval '1 day')::date;
    return next;
    return;
  end if;
  years := extract(year from age(today, starts_on))::int;
  start_day := (starts_on + make_interval(years => years))::date;
  if start_day > today then
    start_day := (starts_on + make_interval(years => greatest(years - 1, 0)))::date;
  end if;
  period_start := start_day;
  period_end := (start_day + interval '1 year' - interval '1 day')::date;
  return next;
end
$function$;
--> statement-breakpoint
-- Staff list of pledges still waiting for this period's transfer. Opening the
-- list also lapses a pledge after three missed periods, because no scheduled
-- job credential is configured (06 §13.1, REQ-DON-003).
create function identity.refresh_expected_pledges(session_id uuid)
returns table (
  id uuid, frequency text, amount_paisa bigint, donation_type text,
  cause_title jsonb, period_start date, period_end date, starts_on date,
  is_anonymous boolean, donor_label text, missed_periods smallint
)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  today date := (now() at time zone 'Asia/Karachi')::date;
  pledge app.recurring_pledges%rowtype;
  current_period record;
  cursor_start date;
  missed smallint;
  step interval;
  paid boolean;
begin
  if not identity.is_finance_session(session_id) then return; end if;

  for pledge in
    select p.* from app.recurring_pledges p
    where p.institute_id = app.current_institute_id() and p.status = 'active'
    order by p.id
    for update
  loop
    select * into current_period from app.pledge_period(pledge.starts_on, pledge.frequency, today);
    step := case when pledge.frequency = 'monthly' then interval '1 month' else interval '1 year' end;
    missed := 0;
    if pledge.starts_on <= today then
      for i in 1..12 loop
        cursor_start := case when pledge.frequency = 'monthly'
          then (current_period.period_start - make_interval(months => i))::date
          else (current_period.period_start - make_interval(years => i))::date
        end;
        exit when (cursor_start + step - interval '1 day')::date < pledge.starts_on;
        select exists (
          select from app.donations d
          where d.institute_id = pledge.institute_id and d.pledge_id = pledge.id
            and d.status = 'recorded'
            and d.credited_on between cursor_start and (cursor_start + step - interval '1 day')::date
        ) into paid;
        exit when paid;
        missed := missed + 1;
      end loop;
    end if;

    if missed >= 3 then
      update app.recurring_pledges as target
      set missed_periods = least(missed, 32767), status = 'lapsed'
      where target.institute_id = pledge.institute_id and target.id = pledge.id;
    elsif missed is distinct from pledge.missed_periods then
      update app.recurring_pledges as target set missed_periods = missed
      where target.institute_id = pledge.institute_id and target.id = pledge.id;
    end if;
  end loop;

  return query
  select p.id, p.frequency, p.amount_paisa, p.donation_type, c.title::jsonb,
    period.period_start, period.period_end, p.starts_on, p.is_anonymous,
    coalesce(nullif(btrim(d.legal_name), ''), d.email), p.missed_periods
  from app.recurring_pledges p
  join app.donors d on (d.institute_id, d.id) = (p.institute_id, p.donor_id)
  left join app.causes c on (c.institute_id, c.id) = (p.institute_id, p.cause_id)
  cross join lateral app.pledge_period(p.starts_on, p.frequency, today) period
  where p.institute_id = app.current_institute_id()
    and p.status = 'active'
    and p.starts_on <= today
    and not exists (
      select from app.donations gift
      where gift.institute_id = p.institute_id and gift.pledge_id = p.id
        and gift.status = 'recorded'
        and gift.credited_on between period.period_start and period.period_end
    )
  order by period.period_start, p.id;
end
$function$;
--> statement-breakpoint
revoke all on function app.pledge_period(date, text, date),
  identity.refresh_expected_pledges(uuid) from public;
--> statement-breakpoint
grant execute on function identity.refresh_expected_pledges(uuid) to tazkiyah_auth;
--> statement-breakpoint
-- Sample draft only. It stays unpublished until the principal decides to raise
-- platform costs. Zakat stays off, as for every new cause (P05-15).
insert into app.causes (
  institute_id, slug, cause_type, title, summary, body, target_period, status,
  listed_as_project, category, why_it_matters, cost_lines, accepts_zakat, display_order
)
select i.id, 'platform-running-costs', 'ongoing',
  '{"en":"Platform running costs","ur":"پلیٹ فارم کے جاری اخراجات"}'::jsonb,
  '{"en":"Sample draft. Replace this text before publishing. Running costs are sponsored until the institute decides to raise them here.","ur":"نمونہ مسودہ۔ شائع کرنے سے پہلے یہ متن بدل دیں۔ جب تک ادارہ خود فیصلہ نہ کرے، جاری اخراجات کفالت میں ہیں۔"}'::jsonb,
  '{"en":"Sample draft for servers, the database and keeping this site online. It is not a published appeal.","ur":"سرورز، ڈیٹابیس اور اس سائٹ کو چلانے کے لیے نمونہ مسودہ۔ یہ شائع شدہ اپیل نہیں۔"}'::jsonb,
  'monthly', 'draft', true, 'technology',
  '{"en":"Sample reason. Say why these costs matter before publishing.","ur":"نمونہ وجہ۔ شائع کرنے سے پہلے لکھیں کہ یہ اخراجات کیوں اہم ہیں۔"}'::jsonb,
  '{"en":"Sample cost lines only. Replace them before publishing.","ur":"صرف نمونہ اخراجات۔ شائع کرنے سے پہلے بدل دیں۔"}'::jsonb,
  false, 90
from app.institutes i
where i.slug = 'markaz-al-azeem'
on conflict (institute_id, slug) do nothing;
--> statement-breakpoint
RESET ROLE;
