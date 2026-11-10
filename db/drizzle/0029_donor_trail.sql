SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE POLICY "donations_own_read" ON "app"."donations" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (donor_id in (select app.my_donor_ids()));--> statement-breakpoint
CREATE POLICY "trail_events_own_read" ON "app"."trail_events" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (exists (select 1 from app.donations d where d.institute_id = trail_events.institute_id and d.id = trail_events.donation_id and d.donor_id in (select app.my_donor_ids())));
--> statement-breakpoint
-- Donor-facing columns only: no staff note, bank details, idempotency key or
-- staff ids (04 §8.4). The policies above limit rows to the donor's own.
grant select (id, institute_id, public_ref, donor_id, cause_id, pledge_id, donation_type, currency,
  amount_minor, amount_paisa, credited_on, frequency, method, receipt_number, receipt_locale,
  is_anonymous, trail_public, status, recorded_at) on app.donations to tazkiyah_app;
--> statement-breakpoint
grant select (id, institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
  allocation_id, spending_entry_id, spending_report_id, reverses_event_id, reason, details, recorded_at)
  on app.trail_events to tazkiyah_app;
--> statement-breakpoint
-- Each donor's own trail (04 §9.6, REQ-TRL-007, REQ-DPR-010): one row per
-- event of each of their donations, for account donors (app.user_id) and
-- token donors (app.use_trail_token). security_invoker, so the donor's own
-- RLS applies; the donor filter is repeated so a staff policy added later
-- cannot widen it. share_paisa is the donor's part of a spend. Spending
-- descriptions and entry totals join here once spending_entries exists
-- (P2-E1-T40). Cause titles come from the public cause view.
create view app.donor_trail with (security_invoker = true) as
select d.id as donation_id, d.public_ref, d.receipt_number, d.receipt_locale, d.credited_on,
  d.amount_paisa as donation_amount_paisa, d.donation_type, d.status as donation_status,
  d.cause_id as given_to_cause_id, d.pledge_id, d.is_anonymous, d.trail_public, d.recorded_at,
  e.id as event_id, e.event_type, e.occurred_on, e.amount_paisa, e.cause_id, c.title as cause_title,
  e.spending_entry_id, e.spending_report_id,
  case when e.event_type = 'spent' then e.amount_paisa end as share_paisa,
  e.reverses_event_id, e.reason,
  exists (select from app.trail_events r
    where r.institute_id = e.institute_id and r.reverses_event_id = e.id) as is_reversed
from app.donations d
join app.trail_events e on e.institute_id = d.institute_id and e.donation_id = d.id
left join public_api.causes c on c.id = e.cause_id
where d.institute_id = app.current_institute_id()
  and d.donor_id in (select app.my_donor_ids());
--> statement-breakpoint
grant select on app.donor_trail to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
