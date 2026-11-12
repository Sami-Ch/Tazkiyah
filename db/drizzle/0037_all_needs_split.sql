SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- All-needs money not yet placed in a cause (04 §9.7, 06 §7.1), one row per
-- recorded all-needs donation with money left. Zakat waits in its own pool.
-- An owner view with its own institute filter, not granted to the runtime
-- roles: the admin dashboard and split screen read it through definer
-- functions.
create view app.unallocated_all_needs with (security_barrier = true) as
select d.institute_id, d.id as donation_id, d.donation_type,
  case when d.donation_type = 'zakat' then 'zakat' else 'general' end as pool,
  d.credited_on, d.receipt_number, d.amount_paisa,
  (d.amount_paisa - coalesce(placed.total, 0))::bigint as unallocated_paisa
from app.donations d
left join lateral (
  select sum(a.amount_paisa) as total from app.allocations a
  where a.institute_id = d.institute_id and a.donation_id = d.id
    and a.kind in ('to_cause', 'to_institute') and not a.is_reversal
    and not exists (select from app.allocations r
      where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id)
) placed on true
where d.institute_id = (select app.current_institute_id())
  and d.cause_id is null and d.status = 'recorded'
  and d.amount_paisa > coalesce(placed.total, 0);
--> statement-breakpoint
revoke all on app.unallocated_all_needs from public, tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
-- The all-needs split (06 §7.2, P2-E4-T40), admin only (D-012). p_parts is an
-- ordered array of {"cause_id", "amount_paisa"}; causes are filled in that
-- order. Money is taken oldest donation first, by credit date and then
-- receipt number, using part of a donation where that is enough. Each piece
-- gets a to_cause allocation and an allocated event dated today, which is its
-- date in the cause's FIFO queue (06-P02). What is not split stays in the
-- pool. The pool is locked for the run, so two splits cannot place the same
-- money twice. Running FIFO for the receiving causes afterwards is the
-- automatic shortfall fill of P2-E2-T02 (proposed REQ-TRL-016), not done here.
create function app.split_all_needs(p_pool text, p_parts jsonb)
returns table (donation_id uuid, cause_id uuid, allocation_id uuid, amount_paisa bigint)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  part jsonb;
  target uuid;
  wanted bigint;
  total bigint := 0;
  available bigint;
  money record;
  take bigint;
  placed_id uuid;
  touched uuid[] := '{}';
begin
  if tenant is null or actor is null or not app.has_role('admin') then
    raise exception 'only an admin splits all-needs money' using errcode = 'insufficient_privilege';
  end if;
  if p_pool is null or p_pool not in ('zakat', 'general')
    or jsonb_typeof(p_parts) is distinct from 'array' or jsonb_array_length(p_parts) = 0
  then
    raise exception 'a split needs a pool and at least one cause' using errcode = 'invalid_parameter_value';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(tenant::text || '/all-needs/' || p_pool, 0));

  for part in select value from jsonb_array_elements(p_parts) loop
    begin
      target := (part ->> 'cause_id')::uuid;
      wanted := (part ->> 'amount_paisa')::bigint;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'each part needs a cause and an amount' using errcode = 'invalid_parameter_value';
    end;
    if target is null or wanted is null or wanted < 100 or wanted % 100 <> 0 then
      raise exception 'each part needs a cause and a whole-rupee amount' using errcode = 'invalid_parameter_value';
    end if;
    if not exists (select from app.causes c
      where c.institute_id = tenant and c.id = target and c.status in ('active', 'closed')
        and (p_pool <> 'zakat' or c.accepts_zakat))
    then
      raise exception 'cause % cannot take money from the % pool', target, p_pool using errcode = 'check_violation';
    end if;
    total := total + wanted;
  end loop;

  select coalesce(sum(u.unallocated_paisa), 0) into available
  from app.unallocated_all_needs u where u.pool = p_pool;
  if total > available then
    raise exception 'the split needs % paisa but the % pool holds %', total, p_pool, available
      using errcode = 'check_violation';
  end if;

  for part in select value from jsonb_array_elements(p_parts) loop
    target := (part ->> 'cause_id')::uuid;
    wanted := (part ->> 'amount_paisa')::bigint;
    for money in
      -- Each part opens a new walk, which sees what earlier parts took.
      select u.donation_id, u.donation_type, u.unallocated_paisa as left_paisa
      from app.unallocated_all_needs u
      where u.pool = p_pool
      order by u.credited_on, u.receipt_number
    loop
      exit when wanted = 0;
      continue when money.left_paisa <= 0;
      take := least(money.left_paisa, wanted);
      insert into app.allocations as a (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa,
        created_by)
      values (tenant, 'to_cause', money.donation_id, money.donation_type, target, take, actor)
      returning a.id into placed_id;
      insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
        allocation_id, recorded_by)
      values (tenant, money.donation_id, 'allocated', today, take, target, placed_id, actor);
      touched := touched || placed_id;
      wanted := wanted - take;
      return query select money.donation_id, target, placed_id, take;
    end loop;
  end loop;

  -- One audit row per donation that gave money, with ids and amounts only.
  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, changes, request_id)
  select tenant, actor, 'user', roles.list, 'donations.split', 'donations', gift.id::text,
    jsonb_build_object('pool', p_pool, 'amount_paisa', gift.amount),
    nullif(current_setting('app.request_id', true), '')
  from (select a.donation_id as id, sum(a.amount_paisa) as amount from app.allocations a
      where a.institute_id = tenant and a.id = any (touched)
      group by a.donation_id) gift
  cross join (select array_agg(r.role order by r.role) as list from app.user_roles r
    where r.institute_id = tenant and r.user_id = actor) roles;
end
$function$;
--> statement-breakpoint
revoke all on function app.split_all_needs(text, jsonb) from public;
--> statement-breakpoint
RESET ROLE;
