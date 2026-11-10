SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The donor wall (04 §8.5, 06 §10.2, P2-E5-T41): every recorded donation
-- with its amount, cause and date (REQ-DPR-007). The label is the donor's
-- public display name only when this donation is set to show it; the page
-- shows "Anonymous" for null (REQ-DPR-008). The name choice is per donation,
-- apart from the profile (REQ-DPR-006, D-128), and the legal name is never
-- used. An anonymous donation cannot even join its donor. Never the donor id,
-- email, receipt number or donation type (06-P06).
create view public_api.donor_wall with (security_barrier = true) as
select d.public_ref, d.amount_minor, d.currency, d.amount_paisa, d.credited_on as given_on,
  d.cause_id,
  case when d.is_anonymous then null else dn.display_name end as donor_label
from app.donations d
left join app.donors dn on dn.institute_id = d.institute_id and dn.id = d.donor_id and not d.is_anonymous
  and dn.erased_at is null
where d.institute_id = app.current_institute_id() and d.status = 'recorded'
  and (d.cause_id is null or exists (select from public_api.causes c where c.id = d.cause_id));
--> statement-breakpoint
grant select on public_api.donor_wall to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
-- The public trail labels its donor the same way (D-128).
create or replace view public_api.public_trails with (security_barrier = true) as
select d.public_ref, d.amount_paisa as donation_amount_paisa, d.currency, d.amount_minor,
  d.credited_on as given_on, d.cause_id as donation_cause_id, d.status as donation_status,
  case when d.is_anonymous then null else dn.display_name end as donor_label,
  t.id as event_id, t.event_type, t.occurred_on, t.amount_paisa, t.cause_id,
  t.spending_entry_id, e.description as spending_description, e.amount_paisa as spending_amount_paisa,
  e.spent_on, m.id as receipt_media_id, m.storage_key as receipt_storage_key, m.variants as receipt_variants,
  t.spending_report_id, t.reverses_event_id,
  -- Only a fixed 06 §15.2 category is shown, never free text, which could hold a name.
  case when t.reason in ('recorded_twice', 'wrong_details', 'wrong_type', 'wrong_donor', 'transfer_returned',
    'refund_to_donor', 'moved_to_another_cause', 'other') then t.reason end as reversal_category
from app.donations d
left join app.donors dn on dn.institute_id = d.institute_id and dn.id = d.donor_id and not d.is_anonymous
join app.trail_events t on t.institute_id = d.institute_id and t.donation_id = d.id
left join app.spending_entries e on e.institute_id = t.institute_id and e.id = t.spending_entry_id
left join app.media_assets m on m.institute_id = e.institute_id and m.id = e.receipt_media_id
  and e.receipt_public and m.purpose = 'receipt' and m.kind = 'image' and m.status = 'ready'
  and m.visibility = 'public'
where d.institute_id = app.current_institute_id() and d.trail_public;
--> statement-breakpoint
RESET ROLE;
