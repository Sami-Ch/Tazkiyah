SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The wall links a chosen name to a public profile, and a public trail, only
-- when the donor asked for each (REQ-DPR-005, REQ-TRL-009). An anonymous gift
-- still cannot join its donor.
create or replace view public_api.donor_wall with (security_barrier = true) as
select d.public_ref, d.amount_minor, d.currency, d.amount_paisa, d.credited_on as given_on,
  d.cause_id,
  case when d.is_anonymous then null else dn.display_name end as donor_label,
  d.trail_public,
  case when d.is_anonymous or not coalesce(dn.profile_public, false) then null else dn.public_ref end as profile_ref
from app.donations d
left join app.donors dn on dn.institute_id = d.institute_id and dn.id = d.donor_id and not d.is_anonymous
  and dn.erased_at is null
where d.institute_id = app.current_institute_id() and d.status = 'recorded'
  and (d.cause_id is null or exists (select from public_api.causes c where c.id = d.cause_id));
--> statement-breakpoint
-- A donor's public face (REQ-DPR-005). The photo file stays off this view
-- until public media addresses exist. Anonymous gifts are not listed here.
create view public_api.donor_profiles with (security_barrier = true) as
select d.public_ref, d.display_name, d.profile_links
from app.donors d
where d.institute_id = app.current_institute_id() and d.profile_public and d.erased_at is null
  and d.display_name is not null;
--> statement-breakpoint
create view public_api.donor_profile_gifts with (security_barrier = true) as
select dn.public_ref as profile_ref, g.public_ref, g.amount_paisa, g.credited_on as given_on,
  g.cause_id, g.trail_public
from app.donors dn
join app.donations g on g.institute_id = dn.institute_id and g.donor_id = dn.id
  and not g.is_anonymous and g.status = 'recorded'
where dn.institute_id = app.current_institute_id() and dn.profile_public and dn.erased_at is null
  and dn.display_name is not null
  and (g.cause_id is null or exists (select from public_api.causes c where c.id = g.cause_id));
--> statement-breakpoint
-- Report title rides on a reported event so the public trail can name the report.
create or replace view public_api.public_trails with (security_barrier = true) as
select d.public_ref, d.amount_paisa as donation_amount_paisa, d.currency, d.amount_minor,
  d.credited_on as given_on, d.cause_id as donation_cause_id, d.status as donation_status,
  case when d.is_anonymous then null else dn.display_name end as donor_label,
  t.id as event_id, t.event_type, t.occurred_on, t.amount_paisa, t.cause_id,
  t.spending_entry_id, e.description as spending_description, e.amount_paisa as spending_amount_paisa,
  e.spent_on, m.id as receipt_media_id, m.storage_key as receipt_storage_key, m.variants as receipt_variants,
  t.spending_report_id, t.reverses_event_id,
  case when t.reason in ('recorded_twice', 'wrong_details', 'wrong_type', 'wrong_donor', 'transfer_returned',
    'refund_to_donor', 'moved_to_another_cause', 'other') then t.reason end as reversal_category,
  case when d.is_anonymous or not coalesce(dn.profile_public, false) then null else dn.public_ref end as profile_ref,
  sr.title as report_title
from app.donations d
left join app.donors dn on dn.institute_id = d.institute_id and dn.id = d.donor_id and not d.is_anonymous
join app.trail_events t on t.institute_id = d.institute_id and t.donation_id = d.id
left join app.spending_entries e on e.institute_id = t.institute_id and e.id = t.spending_entry_id
left join app.media_assets m on m.institute_id = e.institute_id and m.id = e.receipt_media_id
  and e.receipt_public and m.purpose = 'receipt' and m.kind = 'image' and m.status = 'ready'
  and m.visibility = 'public'
left join app.spending_reports sr on sr.institute_id = t.institute_id and sr.id = t.spending_report_id
  and sr.status = 'published'
where d.institute_id = app.current_institute_id() and d.trail_public;
--> statement-breakpoint
grant select on public_api.donor_profiles, public_api.donor_profile_gifts to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
