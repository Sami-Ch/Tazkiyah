SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Reverse the effective matches of one entry or of one donation (06 §15.3):
-- a mirror allocation and a reversal of its spent event for each. Returns the
-- entries touched. Only for the definer functions below; not granted.
create function app.reverse_matches(p_spending_entry_id uuid, p_donation_id uuid, p_category text)
returns uuid[]
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  spend record;
  reversal_id uuid;
  touched uuid[] := '{}';
begin
  for spend in
    select a.*, e.id as event_id
    from app.allocations a
    join app.trail_events e on e.institute_id = a.institute_id and e.allocation_id = a.id and e.event_type = 'spent'
    where a.institute_id = tenant and a.kind = 'to_spending' and not a.is_reversal
      and (a.spending_entry_id = p_spending_entry_id or a.donation_id = p_donation_id)
      and not exists (select from app.allocations r where r.institute_id = tenant and r.reverses_allocation_id = a.id)
    order by a.created_at, a.id
  loop
    insert into app.allocations as a (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
      spending_entry_id, amount_paisa, is_reversal, reverses_allocation_id, reason, created_by)
    values (tenant, 'to_spending', spend.donation_id, spend.donation_type, spend.from_allocation_id, spend.cause_id,
      spend.spending_entry_id, spend.amount_paisa, true, spend.id, p_category, actor)
    returning a.id into reversal_id;
    insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
      allocation_id, spending_entry_id, reverses_event_id, reason, recorded_by)
    values (tenant, spend.donation_id, 'reversal', today, spend.amount_paisa, spend.cause_id, reversal_id,
      spend.spending_entry_id, spend.event_id, p_category, actor);
    if not spend.spending_entry_id = any (touched) then
      touched := touched || spend.spending_entry_id;
    end if;
  end loop;
  return touched;
end
$function$;
--> statement-breakpoint
revoke all on function app.reverse_matches(uuid, uuid, text) from public;
--> statement-breakpoint
-- Reverse a recorded spending entry (06 §15.3, 04 §9.3 "Correction",
-- P2-E2-T41): a reversal for every match, then the entry becomes reversed.
-- Reported events stay as history; the next report lists the entry under
-- "Corrections" (D-126). The freed money is unspent again. Sending it on to
-- other entries' shortfalls is the need queue of P2-E2-T02 (proposed
-- REQ-TRL-016); the corrected purchase is recorded as a new entry and
-- matched with app.match_spending().
create function app.reverse_spending(p_spending_entry_id uuid, p_category text, p_note text default null)
returns void
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  note text := nullif(btrim(p_note), '');
  entry app.spending_entries%rowtype;
begin
  if tenant is null or actor is null
    or not (app.has_role('admin') or app.has_role('finance_officer'))
  then
    raise exception 'reversing spending needs an admin or finance officer' using errcode = 'insufficient_privilege';
  end if;
  if p_category is null or p_category not in ('recorded_twice', 'wrong_details', 'wrong_type',
      'wrong_donor', 'transfer_returned', 'refund_to_donor', 'moved_to_another_cause', 'other')
    or (note is not null and (length(note) > 500 or note ~ '[[:cntrl:]]'))
    or (p_category = 'other' and note is null)
  then
    raise exception 'a reversal needs a known reason category, and a note for "other"'
      using errcode = 'invalid_parameter_value';
  end if;

  perform from app.causes c
  where c.institute_id = tenant
    and c.id = (select e.cause_id from app.spending_entries e where e.institute_id = tenant and e.id = p_spending_entry_id)
  for update;
  select e.* into entry from app.spending_entries e
  where e.institute_id = tenant and e.id = p_spending_entry_id
  for update;
  if not found then
    raise exception 'spending entry % not found', p_spending_entry_id using errcode = 'no_data_found';
  end if;
  if entry.status <> 'recorded' then
    raise exception 'only a recorded spending entry can be reversed, and % is %', entry.id, entry.status
      using errcode = 'object_not_in_prerequisite_state';
  end if;

  perform app.reverse_matches(entry.id, null, p_category);
  update app.spending_entries set status = 'reversed' where institute_id = tenant and id = entry.id;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, changes, reason, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'spending_entries.reversed', 'spending_entries', entry.id::text,
    jsonb_build_object('category', jsonb_build_object('old', null, 'new', p_category)), note,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
end
$function$;
--> statement-breakpoint
revoke all on function app.reverse_spending(uuid, text, text) from public;
--> statement-breakpoint
-- Publish a spending report (06 §9.3, 04 §9.7, P2-E2-T41): the report becomes
-- published, and each donation whose money its entries used gets one reported
-- event for its effective matched total in the report (D-126), dated the day
-- of publishing. Admins and finance officers publish, as in the 05 §7
-- matrix (report.publish).
create function app.publish_spending_report(p_report_id uuid)
returns integer
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  report app.spending_reports%rowtype;
  written integer;
begin
  if tenant is null or actor is null
    or not (app.has_role('admin') or app.has_role('finance_officer'))
  then
    raise exception 'publishing a report needs an admin or finance officer' using errcode = 'insufficient_privilege';
  end if;
  select r.* into report from app.spending_reports r
  where r.institute_id = tenant and r.id = p_report_id
  for update;
  if not found then
    raise exception 'spending report % not found', p_report_id using errcode = 'no_data_found';
  end if;
  if report.status <> 'draft' then
    raise exception 'spending report % is already published', report.id using errcode = 'object_not_in_prerequisite_state';
  end if;
  if not exists (select from app.spending_entries e where e.institute_id = tenant and e.report_id = report.id) then
    raise exception 'spending report % has no entries', report.id using errcode = 'object_not_in_prerequisite_state';
  end if;

  update app.spending_reports set status = 'published', published_at = now(), published_by = actor
  where institute_id = tenant and id = report.id;

  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
    spending_report_id, recorded_by)
  select tenant, a.donation_id, 'reported', today,
    sum(case when a.is_reversal then -a.amount_paisa else a.amount_paisa end), report.id, actor
  from app.allocations a
  join app.spending_entries e on e.institute_id = a.institute_id and e.id = a.spending_entry_id
  where a.institute_id = tenant and a.kind = 'to_spending' and e.report_id = report.id
  group by a.donation_id
  having sum(case when a.is_reversal then -a.amount_paisa else a.amount_paisa end) > 0
  order by min(a.created_at), a.donation_id;
  get diagnostics written = row_count;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'spending_reports.published', 'spending_reports', report.id::text,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return written;
end
$function$;
--> statement-breakpoint
revoke all on function app.publish_spending_report(uuid) from public;
--> statement-breakpoint
create or replace function app.match_spending(p_spending_entry_id uuid)
returns table (matched_paisa bigint, unmatched_paisa bigint)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  entry app.spending_entries%rowtype;
  needed bigint;
  added bigint := 0;
  money record;
  take bigint;
  spend_id uuid;
  report app.spending_reports%rowtype;
begin
  if tenant is null or actor is null
    or not (app.has_role('admin') or app.has_role('finance_officer'))
  then
    raise exception 'matching spending needs an admin or finance officer'
      using errcode = 'insufficient_privilege';
  end if;

  perform from app.causes c
  where c.institute_id = tenant
    and c.id = (select e.cause_id from app.spending_entries e where e.institute_id = tenant and e.id = p_spending_entry_id)
  for update;
  select e.* into entry from app.spending_entries e
  where e.institute_id = tenant and e.id = p_spending_entry_id
  for update;
  if not found then
    raise exception 'spending entry % not found', p_spending_entry_id using errcode = 'no_data_found';
  end if;
  if entry.status <> 'recorded' then
    raise exception 'only a recorded spending entry is matched, and % is %', entry.id, entry.status
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  select r.* into report from app.spending_reports r
  where r.institute_id = tenant and r.id = entry.report_id and r.status = 'published';

  select entry.amount_paisa - coalesce(sum(case when a.is_reversal then -a.amount_paisa else a.amount_paisa end), 0)
  into needed
  from app.allocations a
  where a.institute_id = tenant and a.spending_entry_id = entry.id and a.kind = 'to_spending';

  for money in
    select s.id, s.donation_id, s.donation_type, s.amount_paisa - coalesce((
        select sum(o.amount_paisa) from app.allocations o
        where o.institute_id = tenant and o.from_allocation_id = s.id and not o.is_reversal
          and not exists (select from app.allocations r
            where r.institute_id = tenant and r.reverses_allocation_id = o.id)
      ), 0) as balance,
      placed.occurred_on as entered_on
    from app.allocations s
    join app.donations d on d.institute_id = tenant and d.id = s.donation_id
    join app.trail_events placed on placed.institute_id = tenant and placed.allocation_id = s.id
      and placed.event_type = 'allocated'
    where s.institute_id = tenant and s.cause_id = entry.cause_id and s.kind = 'to_cause'
      and not s.is_reversal
      and not exists (select from app.allocations r
        where r.institute_id = tenant and r.reverses_allocation_id = s.id)
    order by placed.occurred_on, d.receipt_number, placed.id
  loop
    exit when needed <= 0;
    continue when money.balance <= 0;
    take := least(money.balance, needed);
    insert into app.allocations as a (institute_id, kind, donation_id, donation_type, from_allocation_id,
      cause_id, spending_entry_id, amount_paisa, created_by)
    values (tenant, 'to_spending', money.donation_id, money.donation_type, money.id, entry.cause_id,
      entry.id, take, actor)
    returning a.id into spend_id;
    -- The money is spent on the purchase date, or on the day it entered the
    -- cause if it came later.
    insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
      cause_id, allocation_id, spending_entry_id, recorded_by)
    values (tenant, money.donation_id, 'spent', greatest(entry.spent_on, money.entered_on), take,
      entry.cause_id, spend_id, entry.id, actor);
    -- Money matched to an entry that is already reported is reported at once (06 §8.1).
    if report.id is not null then
      insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
        spending_report_id, recorded_by)
      values (tenant, money.donation_id, 'reported', greatest(entry.spent_on, money.entered_on), take,
        report.id, actor);
    end if;
    needed := needed - take;
    added := added + take;
  end loop;

  if added > 0 then
    insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
      action, entity_table, entity_id, request_id)
    select tenant, actor, 'user', array_agg(r.role order by r.role),
      'spending_entries.matched', 'spending_entries', entry.id::text,
      nullif(current_setting('app.request_id', true), '')
    from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  end if;

  return query select entry.amount_paisa - needed, needed;
end
$function$;
--> statement-breakpoint
-- Reverse a whole donation, spent or not (06 §15.3, P2-E2-T41).
create or replace function app.reverse_donation(p_donation_id uuid, p_category text, p_note text default null)
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
  touched uuid[];
  entry_id uuid;
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
  -- Spent money first: reverse each match and each reported event (06 §15.3),
  -- remembering the entries, which are matched again from other money below.
  touched := app.reverse_matches(null, gift.id, p_category);
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
    spending_report_id, reverses_event_id, reason, recorded_by)
  select tenant, gift.id, 'reversal', today, e.amount_paisa, null, e.id, p_category, actor
  from app.trail_events e
  where e.institute_id = tenant and e.donation_id = gift.id and e.event_type = 'reported'
    and not exists (select from app.trail_events r where r.institute_id = tenant and r.reverses_event_id = e.id)
  order by e.id;

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
    'donations.reversed', 'donations', gift.id::text, jsonb_build_object('category', jsonb_build_object('old', null, 'new', p_category)), note,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;

  -- The entries it paid for now have shortfalls; other unspent money in each
  -- cause covers them, oldest entry first (06 §15.3).
  for entry_id in
    select e.id from app.spending_entries e
    where e.institute_id = tenant and e.id = any (touched) and e.status = 'recorded'
    order by e.spent_on, e.created_at, e.id
  loop
    perform app.match_spending(entry_id);
  end loop;
end
$function$;
--> statement-breakpoint
RESET ROLE;
