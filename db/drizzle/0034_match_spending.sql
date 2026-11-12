SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- First-in-first-out matching of one recorded spending entry (04 §9.3,
-- P2-E2-T40). The cause row is locked first, so two runs in one cause wait for
-- each other and cannot spend the same money twice. The walk reads the cause's
-- to_cause allocations with money left, oldest first by the date the money
-- entered the cause, which is the date of its allocated event: the credit date
-- for a gift to the cause and the split date for an all-needs piece (06-P02,
-- D-125). Ties go to the lower receipt number, then the order of recording.
-- Each step writes a to_spending allocation and a spent event. A run only adds
-- matches (06-P03), so calling it again only covers what is still unmatched.
-- If the money runs out first, the entry stays partly matched. Not granted to
-- the runtime roles: "Record batch" (P2-E1-T03) calls it after its own checks.
create function app.match_spending(p_spending_entry_id uuid)
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
revoke all on function app.match_spending(uuid) from public;
--> statement-breakpoint
RESET ROLE;
