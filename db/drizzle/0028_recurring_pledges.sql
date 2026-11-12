SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."recurring_pledges" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"donor_id" uuid NOT NULL,
	"cause_id" uuid,
	"donation_type" text NOT NULL,
	"frequency" text NOT NULL,
	"amount_paisa" bigint NOT NULL,
	"is_anonymous" boolean DEFAULT true NOT NULL,
	"starts_on" date NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"missed_periods" smallint DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"cancelled_at" timestamp with time zone,
	CONSTRAINT "recurring_pledges_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "recurring_pledges_type_check" CHECK (donation_type in ('zakat', 'sadaqah', 'general') and frequency in ('monthly', 'yearly')),
	CONSTRAINT "recurring_pledges_amount_check" CHECK (amount_paisa between 100 and 99999999999900 and amount_paisa % 100 = 0),
	CONSTRAINT "recurring_pledges_status_check" CHECK (status in ('active', 'lapsed', 'cancelled') and (status = 'cancelled') = (cancelled_at is not null) and missed_periods >= 0)
);
--> statement-breakpoint
ALTER TABLE "app"."recurring_pledges" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "pledge_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."recurring_pledges" ADD CONSTRAINT "recurring_pledges_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."recurring_pledges" ADD CONSTRAINT "recurring_pledges_institute_id_donor_id_donors_institute_id_id_fk" FOREIGN KEY ("institute_id","donor_id") REFERENCES "app"."donors"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."recurring_pledges" ADD CONSTRAINT "recurring_pledges_institute_id_cause_id_causes_institute_id_id_fk" FOREIGN KEY ("institute_id","cause_id") REFERENCES "app"."causes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "recurring_pledges_donor" ON "app"."recurring_pledges" USING btree ("institute_id","donor_id");--> statement-breakpoint
CREATE INDEX "recurring_pledges_cause" ON "app"."recurring_pledges" USING btree ("institute_id","cause_id") WHERE cause_id is not null;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_pledge_id_recurring_pledges_institute_id_id_fk" FOREIGN KEY ("institute_id","pledge_id") REFERENCES "app"."recurring_pledges"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "donations_pledge" ON "app"."donations" USING btree ("institute_id","pledge_id") WHERE pledge_id is not null;--> statement-breakpoint
CREATE POLICY "iso" ON "app"."recurring_pledges" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));
--> statement-breakpoint
-- Pledges are read and changed only through definer functions (§8.8): the
-- expected-payments list, the donor's own trail page and the monthly job.
revoke all on app.recurring_pledges from public, tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.recurring_pledges
for each row execute function app.audit_row_change();
--> statement-breakpoint
-- A Zakat pledge to a cause needs a Zakat-eligible cause, as for donations
-- (§9.4 rule 1). Status, missed periods and cancellation may change; the
-- promise itself does not. A different promise is a new pledge.
create function app.recurring_pledges_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op = 'UPDATE' and to_jsonb(new) - array['status', 'missed_periods', 'cancelled_at']
    is distinct from to_jsonb(old) - array['status', 'missed_periods', 'cancelled_at']
  then
    raise exception 'pledge % is fixed: only its status may change', old.id
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if tg_op = 'UPDATE' and old.status = 'cancelled' and new.status <> 'cancelled' then
    raise exception 'a cancelled pledge stays cancelled' using errcode = 'object_not_in_prerequisite_state';
  end if;
  if tg_op = 'INSERT' and new.donation_type = 'zakat' and new.cause_id is not null and not exists (
    select from app.causes c
    where c.institute_id = new.institute_id and c.id = new.cause_id and c.accepts_zakat
  ) then
    raise exception 'this cause does not accept Zakat' using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger recurring_pledges_rules before insert or update on app.recurring_pledges
for each row execute function app.recurring_pledges_rules();
--> statement-breakpoint
-- A payment linked to a pledge comes from the pledge's donor.
create function app.donations_pledge_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.pledge_id is not null and not exists (
    select from app.recurring_pledges p
    where p.institute_id = new.institute_id and p.id = new.pledge_id and p.donor_id = new.donor_id
  ) then
    raise exception 'a pledge payment must come from the pledge''s donor' using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger donations_pledge_rules before insert on app.donations
for each row execute function app.donations_pledge_rules();
--> statement-breakpoint
-- Public cause totals read only that cause's allocations, and each one's
-- donation date by key, instead of joining every donation of the institute
-- (the P0-E2-T19 note). A reversed donation needs no status filter: all its
-- allocations are mirrored, so they add up to zero.
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
    coalesce(sum(signed.amount) filter (where (
      select d.credited_on from app.donations d
      where d.institute_id = a.institute_id and d.id = a.donation_id
    ) >= period.first_day), 0) as raised_paisa,
    coalesce(sum(signed.amount), 0) as lifetime_raised_paisa
  from app.allocations a
  cross join lateral (select case when a.is_reversal then -a.amount_paisa else a.amount_paisa end as amount) signed
  where a.institute_id = c.institute_id and a.cause_id = c.id and a.kind = 'to_cause'
) totals
where c.status in ('active', 'closed', 'archived')
  and (c.starts_on is null or c.starts_on <= clock.today);
--> statement-breakpoint
RESET ROLE;
