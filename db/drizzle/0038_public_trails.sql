SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Public spending per cause (04 §6.5, 05 §5.6 block 7, P2-E6-T40). Only
-- entries in a published report are public (06 §9.2, §9.4, D-124); a reversed
-- one stays listed with its status, so the page can mark it corrected. The
-- receipt shows only when the entry's receipt is public and the upload is a
-- ready public receipt. Never who recorded it, and no donor shares
-- (REQ-TRL-010): matched and uncovered are totals over all donors.
create view public_api.cause_spending with (security_barrier = true) as
select e.id, e.cause_id, e.spent_on, e.amount_paisa, e.description, e.status,
  r.id as report_id, r.period_kind as report_period_kind, r.period_start as report_period_start,
  r.period_end as report_period_end, r.title as report_title, r.published_at as report_published_at,
  m.id as receipt_media_id, m.storage_key as receipt_storage_key, m.variants as receipt_variants,
  m.alt_text as receipt_alt_text,
  matched.total as matched_paisa,
  case when e.status = 'recorded' then e.amount_paisa - matched.total else 0 end::bigint as uncovered_paisa
from app.spending_entries e
join public_api.causes c on c.id = e.cause_id
join app.spending_reports r on r.institute_id = e.institute_id and r.id = e.report_id and r.status = 'published'
left join app.media_assets m on m.institute_id = e.institute_id and m.id = e.receipt_media_id
  and e.receipt_public and m.purpose = 'receipt' and m.kind = 'image' and m.status = 'ready'
  and m.visibility = 'public'
cross join lateral (
  select coalesce(sum(case when a.is_reversal then -a.amount_paisa else a.amount_paisa end), 0)::bigint as total
  from app.allocations a
  where a.institute_id = e.institute_id and a.spending_entry_id = e.id and a.kind = 'to_spending'
) matched
where e.institute_id = app.current_institute_id() and e.status in ('recorded', 'reversed');
--> statement-breakpoint
-- The public trail of one donation (04 §6.5, 05 §5.10, 06 §10, REQ-TRL-009):
-- only donations whose donor made the trail public, addressed by public_ref,
-- never by the guest token. One row per event. The donor label follows the
-- donor wall (04 §8.5): an anonymous donation cannot even join its donor. The
-- donation type is never shown (06-P06), nor the donor id, receipt number,
-- bank fields or staff ids. A spent event names its entry, with its
-- description and amount for the share, and its receipt only when public.
create view public_api.public_trails with (security_barrier = true) as
select d.public_ref, d.amount_paisa as donation_amount_paisa, d.currency, d.amount_minor,
  d.credited_on as given_on, d.cause_id as donation_cause_id, d.status as donation_status,
  case when d.is_anonymous then null when dn.profile_public then dn.display_name end as donor_label,
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
grant select on public_api.cause_spending, public_api.public_trails to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
