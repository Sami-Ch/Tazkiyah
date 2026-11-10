SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Reverse a whole donation (04 §9.6, 06 §15.3, P1-E3-T45). Every effective
-- allocation gets a mirror reversal and every shown event a reversal event, so
-- nothing is edited or deleted (REQ-DON-012, REQ-TRL-003). A donation whose
-- money has been spent is refused for now; re-matching the spends it paid for
-- arrives with FIFO (P2-E2-T41). The reason category (06 §15.2) is what the
-- donor sees, on the trail events. The optional staff note goes only to the
-- audit log reason, which only admins read; the admin form must keep donor
-- names out of it, as for private_note (05 §8).
create function app.reverse_donation(p_donation_id uuid, p_category text, p_note text default null)
returns void
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  note text := nullif(btrim(p_note), '');
  gift app.donations%rowtype;
  placed record;
  reversal_id uuid;
begin
  if tenant is null or actor is null
    or not (app.has_role('admin') or app.has_role('finance_officer'))
  then
    raise exception 'reversing a donation needs an admin or finance officer'
      using errcode = 'insufficient_privilege';
  end if;
  if p_category is null or p_category not in ('recorded_twice', 'wrong_details', 'wrong_type',
      'wrong_donor', 'transfer_returned', 'refund_to_donor', 'moved_to_another_cause', 'other')
    or (note is not null and (length(note) > 500 or note ~ '[[:cntrl:]]'))
    or (p_category = 'other' and note is null)
  then
    raise exception 'a reversal needs a known reason category, and a note for "other"'
      using errcode = 'invalid_parameter_value';
  end if;

  select d.* into gift from app.donations d
  where d.institute_id = tenant and d.id = p_donation_id
  for update;
  if not found then
    raise exception 'donation not found' using errcode = 'no_data_found';
  end if;
  if gift.status <> 'recorded' then
    raise exception 'donation % is already reversed', gift.receipt_number
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if exists (
    select from app.allocations a
    where a.institute_id = tenant and a.donation_id = gift.id and a.kind = 'to_spending'
      and not a.is_reversal
      and not exists (select from app.allocations r
        where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id)
  ) then
    raise exception 'donation % has been spent; reverse its spending first', gift.receipt_number
      using errcode = 'object_not_in_prerequisite_state';
  end if;

  for placed in
    select a.*, e.id as event_id
    from app.allocations a
    join app.trail_events e on e.institute_id = a.institute_id and e.allocation_id = a.id
      and e.event_type = 'allocated'
    where a.institute_id = tenant and a.donation_id = gift.id
      and a.kind in ('to_cause', 'to_institute') and not a.is_reversal
      and not exists (select from app.allocations r
        where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id)
    order by a.created_at, a.id
  loop
    insert into app.allocations as a (institute_id, kind, donation_id, donation_type, cause_id,
      target_institute_id, amount_paisa, is_reversal, reverses_allocation_id, reason, created_by)
    values (tenant, placed.kind, gift.id, placed.donation_type, placed.cause_id,
      placed.target_institute_id, placed.amount_paisa, true, placed.id, p_category, actor)
    returning a.id into reversal_id;
    insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
      cause_id, allocation_id, reverses_event_id, reason, recorded_by)
    values (tenant, gift.id, 'reversal', today, placed.amount_paisa, placed.cause_id, reversal_id,
      placed.event_id, p_category, actor);
  end loop;

  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
    reverses_event_id, reason, recorded_by)
  select tenant, gift.id, 'reversal', today, e.amount_paisa, e.id, p_category, actor
  from app.trail_events e
  where e.institute_id = tenant and e.donation_id = gift.id and e.event_type = 'received';

  update app.donations set status = 'reversed' where institute_id = tenant and id = gift.id;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, changes, reason, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'donations.reversed', 'donations', gift.id::text, jsonb_build_object('category', p_category), note,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
end
$function$;
--> statement-breakpoint
revoke all on function app.reverse_donation(uuid, text, text) from public;
--> statement-breakpoint
RESET ROLE;
