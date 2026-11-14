SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- A donor's private trail includes the share of each purchase and each
-- published report (REQ-TRL-007, P2-E2-T05). A receipt photo is included only
-- when the spending entry marks it public and the file itself is a ready
-- public image with no face. Draft and reversed entries never appear: a spent
-- event exists only after matching, and a reversed event is omitted with its
-- reversal.
create or replace function identity.donation_trail_page(
  p_donor uuid, p_before_recorded_at timestamptz, p_before_donation_id uuid, p_public_ref text
) returns setof identity.donation_trail_row
language sql stable
set search_path = pg_catalog, pg_temp
as $function$
  with page as materialized (
    select d.institute_id, d.id, d.receipt_number, d.receipt_locale, d.credited_on,
      d.amount_paisa, d.donation_type, d.status, d.recorded_at, d.cause_id, d.public_ref,
      d.bank_reference, d.is_anonymous, d.donor_id, d.replaces_donation_id
    from app.donations d
    where d.institute_id = app.current_institute_id() and d.donor_id = p_donor
      and (p_public_ref is null or d.public_ref = p_public_ref)
      and ((p_before_recorded_at is null and p_before_donation_id is null) or
        (isfinite(p_before_recorded_at) and p_before_donation_id is not null
          and (d.recorded_at, d.id) < (p_before_recorded_at, p_before_donation_id)))
    order by d.recorded_at desc nulls last, d.id desc nulls last
    limit 21
  )
  select d.id, d.receipt_number, d.receipt_locale, to_char(d.credited_on, 'YYYY-MM-DD'),
    d.amount_paisa::text, d.donation_type, d.status,
    to_char(d.recorded_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    coalesce(trail.events, '[]'::jsonb),
    (select r.reason from app.trail_events r
      join app.trail_events o on o.institute_id = r.institute_id and o.id = r.reverses_event_id
      where r.institute_id = d.institute_id and r.donation_id = d.id and o.event_type = 'received'),
    original_cause.title::jsonb, d.public_ref, right(d.bank_reference, 4),
    case when not d.is_anonymous then coalesce(donor.display_name, account.full_name) end,
    settings.name::jsonb, settings.address::jsonb, i.slug, logo.storage_key,
    d.replaces_donation_id is not null, replaced.receipt_number
  from page d
  join app.institutes i on i.id = d.institute_id
  left join app.institute_settings settings on settings.institute_id = i.id
  left join public_api.institute_logo logo on logo.institute_id = i.id
  join app.donors donor on (donor.institute_id, donor.id) = (d.institute_id, d.donor_id)
  left join app.users account on (account.institute_id, account.id) = (donor.institute_id, donor.user_id)
  left join app.donations replaced on (replaced.institute_id, replaced.id, replaced.donor_id)
    = (d.institute_id, d.replaces_donation_id, d.donor_id)
  left join app.causes original_cause on (original_cause.institute_id, original_cause.id) = (d.institute_id, d.cause_id)
  cross join lateral (
    select jsonb_agg(jsonb_build_object(
      'event_type', e.event_type,
      'occurred_on', to_char(e.occurred_on, 'YYYY-MM-DD'),
      'amount_paisa', e.amount_paisa::text,
      'cause_title', c.title
    ) || case
      when e.event_type in ('spent', 'reported') then jsonb_strip_nulls(jsonb_build_object(
        'description', case
          when e.event_type = 'spent' then se.description
          when e.event_type = 'reported' then sr.title
        end,
        'receipt_key', case
          when e.event_type = 'spent' and se.receipt_public
            and m.visibility = 'public' and m.status = 'ready' and not m.shows_face
          then m.storage_key
        end
      ))
      else '{}'::jsonb
    end order by e.id) as events
    from app.trail_events e
    left join app.causes c on (c.institute_id, c.id) = (e.institute_id, e.cause_id)
    left join app.spending_entries se on e.event_type = 'spent'
      and (se.institute_id, se.id) = (e.institute_id, e.spending_entry_id)
      and se.status = 'recorded'
    left join app.media_assets m on se.receipt_media_id is not null
      and (m.institute_id, m.id) = (se.institute_id, se.receipt_media_id)
    left join app.spending_reports sr on e.event_type = 'reported'
      and (sr.institute_id, sr.id) = (e.institute_id, e.spending_report_id)
      and sr.status = 'published'
    where e.institute_id = d.institute_id and e.donation_id = d.id
      and e.event_type in ('received', 'allocated', 'spent', 'reported')
      and (e.event_type <> 'spent' or se.id is not null)
      and (e.event_type <> 'reported' or sr.id is not null)
      and not exists (select from app.trail_events r
        where r.institute_id = e.institute_id and r.reverses_event_id = e.id)
  ) trail
  order by d.recorded_at desc, d.id desc
$function$;
--> statement-breakpoint
RESET ROLE;
