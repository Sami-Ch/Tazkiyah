SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Finance staff can inspect any manual transfer by its receipt number. The
-- response omits the donor, bank reference and staff-only reversal note.
create function identity.read_transfer_for_reversal(p_session_id uuid, p_receipt text)
returns table (
  receipt_number text, credited_on text, amount_paisa text, donation_type text,
  cause_title jsonb, status text, has_spending boolean, reversed_on text, reversal_reason text
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select d.receipt_number, to_char(d.credited_on, 'YYYY-MM-DD'), d.amount_paisa::text,
    d.donation_type, c.title::jsonb, d.status,
    exists (select from app.allocations_effective a
      where a.institute_id = d.institute_id and a.donation_id = d.id and a.kind = 'to_spending'),
    to_char(r.occurred_on, 'YYYY-MM-DD'), r.reason
  from app.donations d
  left join app.causes c on (c.institute_id, c.id) = (d.institute_id, d.cause_id)
  left join app.trail_events received on (received.institute_id, received.donation_id) = (d.institute_id, d.id)
    and received.event_type = 'received'
  left join app.trail_events r on (r.institute_id, r.reverses_event_id) = (received.institute_id, received.id)
  where d.institute_id = app.current_institute_id() and d.receipt_number = p_receipt
    and d.method = 'bank_transfer' and identity.is_finance_session(p_session_id)
$function$;
--> statement-breakpoint
create function identity.reverse_manual_donation(p_session_id uuid, p_receipt text, p_category text, p_note text)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  gift app.donations%rowtype;
begin
  if not identity.is_finance_session(p_session_id) then return 'denied'; end if;
  -- Recheck under the same donation lock the allocation trigger takes. In
  -- READ COMMITTED, the spending query sees any allocation that just won it.
  if current_setting('transaction_isolation') not in ('read committed', 'read uncommitted') then
    raise exception 'manual reversal requires read committed' using errcode = 'invalid_transaction_state';
  end if;
  select d.* into gift from app.donations d
  where d.institute_id = tenant and d.receipt_number = p_receipt and d.method = 'bank_transfer'
  for update;
  if not found then return 'no_match'; end if;
  if gift.status = 'reversed' then return 'already_reversed'; end if;
  if exists (select from app.allocations_effective a
    where a.institute_id = tenant and a.donation_id = gift.id and a.kind = 'to_spending')
  then return 'has_spending'; end if;

  perform app.reverse_donation(gift.id, p_category, p_note);
  return 'reversed';
exception when invalid_parameter_value then
  return 'invalid';
end
$function$;
--> statement-breakpoint
revoke all on function identity.read_transfer_for_reversal(uuid, text),
  identity.reverse_manual_donation(uuid, text, text, text) from public;
grant execute on function identity.read_transfer_for_reversal(uuid, text),
  identity.reverse_manual_donation(uuid, text, text, text) to tazkiyah_auth;
--> statement-breakpoint
-- Keep the cause on a cancelled receipt after its allocation events have
-- been reversed. The original cause is also distinct from later pool splits.
drop function identity.read_guest_trail(text, timestamptz, uuid);
--> statement-breakpoint
create function identity.read_guest_trail(
  p_token_hash text, p_before_recorded_at timestamptz, p_before_donation_id uuid
) returns table (
  id uuid, receipt_number text, receipt_locale text, credited_on text, amount_paisa text,
  donation_type text, status text, recorded_at text, events jsonb, reversal_reason text, cause_title jsonb
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  with page as materialized (
    select d.institute_id, d.id, d.receipt_number, d.receipt_locale, d.credited_on,
      d.amount_paisa, d.donation_type, d.status, d.recorded_at, d.cause_id
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
      where r.institute_id = d.institute_id and r.donation_id = d.id and o.event_type = 'received'),
    original_cause.title::jsonb
  from page d
  left join app.causes original_cause on (original_cause.institute_id, original_cause.id) = (d.institute_id, d.cause_id)
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
-- Recheck donation status after acquiring the ledger lock. A concurrent
-- split or match may have selected a donation before it was reversed.
create or replace function app.allocations_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
declare
  gift app.donations%rowtype;
  source app.allocations%rowtype;
  original app.allocations%rowtype;
begin
  select d.* into gift from app.donations d
  where d.institute_id = new.institute_id and d.id = new.donation_id
  for no key update;
  if not found then
    raise exception 'allocation needs a donation of its institute' using errcode = 'foreign_key_violation';
  end if;
  if not new.is_reversal and gift.status <> 'recorded' then
    raise exception 'new allocations need a recorded donation' using errcode = 'check_violation';
  end if;
  if new.donation_type <> gift.donation_type then
    raise exception 'allocation type % must equal the donation type %', new.donation_type, gift.donation_type
      using errcode = 'check_violation';
  end if;

  -- Zakat goes only into, and is spent only from, causes that accept it at
  -- that moment (04 §9.4 rule 2, REQ-TRL-006). A reversal only takes money back.
  if new.donation_type = 'zakat' and new.kind in ('to_cause', 'to_spending') and not new.is_reversal
    and not exists (select from app.causes c
      where c.institute_id = new.institute_id and c.id = new.cause_id and c.accepts_zakat)
  then
    raise exception 'Zakat money can only go to a cause that accepts Zakat' using errcode = 'check_violation';
  end if;

  if new.is_reversal then
    select a.* into original from app.allocations a
    where a.institute_id = new.institute_id and a.id = new.reverses_allocation_id;
    if original.is_reversal or original.donation_id <> new.donation_id or original.kind <> new.kind
      or original.amount_paisa <> new.amount_paisa or original.donation_type <> new.donation_type
      or original.cause_id is distinct from new.cause_id
      or original.from_allocation_id is distinct from new.from_allocation_id
      or original.spending_entry_id is distinct from new.spending_entry_id
      or original.target_institute_id is distinct from new.target_institute_id
    then
      raise exception 'a reversal must mirror the allocation it reverses, which must not be a reversal'
        using errcode = 'check_violation';
    end if;
  elsif new.kind = 'to_spending' then
    select a.* into source from app.allocations a
    where a.institute_id = new.institute_id and a.id = new.from_allocation_id
    for no key update;
    if source.kind <> 'to_cause' or source.is_reversal or source.donation_id <> new.donation_id
      or source.cause_id <> new.cause_id
    then
      raise exception 'spending must draw on a cause allocation of the same donation and cause'
        using errcode = 'check_violation';
    end if;
    -- The entry is locked too, so its per-entry cap is checked on a stable ledger.
    if not exists (
      select from app.spending_entries e
      where e.institute_id = new.institute_id and e.id = new.spending_entry_id
        and e.cause_id = new.cause_id and e.status = 'recorded'
      for no key update
    ) then
      raise exception 'spending must match a recorded spending entry of the same cause'
        using errcode = 'check_violation';
    end if;
  elsif new.kind = 'to_institute' then
    -- REQ-TRL-014: the shape exists, but only a platform fund may use it (§9.5).
    if not exists (select from app.institutes i where i.id = new.institute_id and i.kind = 'platform_fund') then
      raise exception 'transfers to an institute are only possible from a platform fund'
        using errcode = 'check_violation';
    end if;
    if new.target_institute_id = new.institute_id or not exists (
      select from app.institutes i where i.id = new.target_institute_id and i.kind = 'institute'
    ) then
      raise exception 'a transfer must go to another institute' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end
$function$;
--> statement-breakpoint
RESET ROLE;
