SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The guest trail also returns a reversed donation's reason category (06
-- §15.2), so the donor sees why it was cancelled (P1-E4-T02). The category is
-- a fixed value; the staff note is never part of the trail.
drop function identity.read_guest_trail(text, timestamptz, uuid);
--> statement-breakpoint
create function identity.read_guest_trail(
  p_token_hash text, p_before_recorded_at timestamptz, p_before_donation_id uuid
) returns table (
  id uuid, receipt_number text, receipt_locale text, credited_on text, amount_paisa text,
  donation_type text, status text, recorded_at text, events jsonb, reversal_reason text
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  with page as materialized (
    select d.institute_id, d.id, d.receipt_number, d.receipt_locale, d.credited_on,
      d.amount_paisa, d.donation_type, d.status, d.recorded_at
    from app.trail_links link
    join app.institutes i on i.id = link.institute_id and i.status = 'active' and i.kind = 'institute'
    join app.donations d on (d.institute_id, d.donor_id) = (link.institute_id, link.donor_id)
    where link.institute_id = app.current_institute_id() and link.revoked_at is null
      and p_token_hash ~ '^[0-9a-f]{64}$' and link.token_hash = p_token_hash
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
      where r.institute_id = d.institute_id and r.donation_id = d.id and o.event_type = 'received')
  from page d
  cross join lateral (
    select jsonb_agg(jsonb_build_object(
      'event_type', e.event_type,
      'occurred_on', to_char(e.occurred_on, 'YYYY-MM-DD'),
      'amount_paisa', e.amount_paisa::text,
      'cause_title', c.title
    ) order by e.id) as events
    from app.trail_events e
    left join app.causes c on (c.institute_id, c.id) = (e.institute_id, e.cause_id)
    where e.institute_id = d.institute_id and e.donation_id = d.id
      and e.event_type in ('received', 'allocated')
      and not exists (select from app.trail_events r
        where r.institute_id = e.institute_id and r.reverses_event_id = e.id)
  ) trail
  order by d.recorded_at desc, d.id desc
$function$;
--> statement-breakpoint
revoke all on function identity.read_guest_trail(text, timestamptz, uuid) from public;
--> statement-breakpoint
grant execute on function identity.read_guest_trail(text, timestamptz, uuid) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
