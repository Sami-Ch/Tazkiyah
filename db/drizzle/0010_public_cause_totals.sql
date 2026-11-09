SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE INDEX "allocations_institute_id_cause_id_donation_id_index" ON "app"."allocations" USING btree ("institute_id","cause_id","donation_id");
--> statement-breakpoint
create or replace view public_api.causes with (security_barrier = true) as
select c.id, c.slug, c.cause_type, c.title, c.summary, c.body, c.target_paisa,
  c.target_period, c.stock_year_start_month, c.starts_on, c.ends_on,
  c.accepts_zakat, c.zakat_approved_by,
  case when c.ends_on < clock.today then 'closed' else c.status end as status,
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
where c.status in ('active', 'closed') and (c.starts_on is null or c.starts_on <= clock.today);
--> statement-breakpoint
RESET ROLE;
