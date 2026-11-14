SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Staff spending workspace (06 §9, P2-E1-T01, P2-E1-T05). Finance officers and
-- admins see open drafts, recent entries, unspent money by cause and type, and
-- the all-needs pools. Receipt photos wait for object storage (P2-E1-T30).
create function identity.spending_workspace(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  allowed boolean := identity.is_finance_session(p_session_id);
begin
  if not allowed then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'batch_on', to_char(today, 'YYYY-MM-DD'),
    'causes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'title', c.title,
        'status', c.status,
        'balances', coalesce((
          select jsonb_agg(jsonb_build_object(
            'donation_type', b.donation_type,
            'unspent_paisa', b.unspent_paisa::text,
            'raised_paisa', b.raised_paisa::text,
            'spent_paisa', b.spent_paisa::text
          ) order by b.donation_type)
          from app.cause_balances b
          where b.cause_id = c.id
        ), '[]'::jsonb)
      ) order by c.display_order, c.slug)
      from app.causes c
      where c.institute_id = tenant and c.status in ('active', 'closed')
    ), '[]'::jsonb),
    'pools', coalesce((
      select jsonb_agg(jsonb_build_object(
        'pool', p.pool,
        'unallocated_paisa', p.total::text,
        'gifts', p.gifts
      ) order by p.pool)
      from (
        select u.pool, sum(u.unallocated_paisa) as total, count(*)::int as gifts
        from app.unallocated_all_needs u
        group by u.pool
      ) p
    ), '[]'::jsonb),
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id,
        'cause_id', e.cause_id,
        'amount_paisa', e.amount_paisa::text,
        'spent_on', to_char(e.spent_on, 'YYYY-MM-DD'),
        'description', e.description,
        'status', e.status,
        'receipt_public', e.receipt_public,
        'matched_paisa', coalesce(matched.total, 0)::text
      ) order by e.created_at desc, e.id desc)
      from app.spending_entries e
      left join lateral (
        select sum(case when a.is_reversal then -a.amount_paisa else a.amount_paisa end) as total
        from app.allocations a
        where a.institute_id = e.institute_id and a.spending_entry_id = e.id and a.kind = 'to_spending'
      ) matched on true
      where e.institute_id = tenant
        and (e.status = 'draft' or e.created_at > now() - interval '90 days')
    ), '[]'::jsonb)
  );
end
$function$;
--> statement-breakpoint
-- Save one draft in the open batch (P2-E1-T01). A draft may exceed the unspent
-- balance; recording it may not. The answer says which.
create function identity.save_spending_draft(
  p_session_id uuid, p_cause_id uuid, p_amount_paisa bigint, p_spent_on date,
  p_description jsonb, p_receipt_public boolean
) returns table (code text, entry_id uuid)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  unspent bigint;
  saved uuid;
begin
  if not identity.is_finance_session(p_session_id) then
    return query select 'denied'::text, null::uuid;
    return;
  end if;
  if p_cause_id is null or p_amount_paisa is null
    or p_amount_paisa not between 100 and 99999999999900 or p_amount_paisa % 100 <> 0
    or p_spent_on is null or p_spent_on not between date '1900-01-01' and today
    or p_description is null or not app.valid_localized_text(p_description)
    or exists (
      select from jsonb_each(p_description) as item(language, body)
      where language not in ('en', 'ur') or length(body #>> '{}') > 500
        or (body #>> '{}') ~ '[[:cntrl:]]'
    )
  then
    return query select 'invalid'::text, null::uuid;
    return;
  end if;
  perform from app.causes c
  where c.institute_id = tenant and c.id = p_cause_id and c.status in ('active', 'closed')
  for update;
  if not found then
    return query select 'cause_unavailable'::text, null::uuid;
    return;
  end if;

  insert into app.spending_entries as e (
    institute_id, cause_id, amount_paisa, spent_on, description, receipt_public, status, recorded_by
  ) values (
    tenant, p_cause_id, p_amount_paisa, p_spent_on, p_description,
    coalesce(p_receipt_public, true), 'draft', actor
  ) returning e.id into saved;

  select coalesce(sum(b.unspent_paisa), 0) into unspent
  from app.cause_balances b where b.cause_id = p_cause_id;
  return query select
    case when p_amount_paisa > unspent then 'saved_over_balance' else 'saved' end,
    saved;
end
$function$;
--> statement-breakpoint
-- Turn open drafts into recorded entries and match them oldest first
-- (P2-E1-T03, P2-E2-T01). An entry larger than the money still unspent is left
-- as a draft. p_entry_id null records every open draft.
create function identity.record_spending_batch(p_session_id uuid, p_entry_id uuid)
returns table (entry_id uuid, code text, matched_paisa bigint, unmatched_paisa bigint)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  entry app.spending_entries%rowtype;
  unspent bigint;
  matched bigint;
  unmatched bigint;
  seen boolean := false;
begin
  if not identity.is_finance_session(p_session_id) then
    return query select null::uuid, 'denied'::text, null::bigint, null::bigint;
    return;
  end if;
  for entry in
    select e.* from app.spending_entries e
    where e.institute_id = tenant and e.status = 'draft'
      and (p_entry_id is null or e.id = p_entry_id)
    order by e.created_at, e.id
    for update
  loop
    seen := true;
    select coalesce(sum(b.unspent_paisa), 0) into unspent
    from app.cause_balances b where b.cause_id = entry.cause_id;
    if entry.amount_paisa > unspent then
      return query select entry.id, 'over_balance'::text, 0::bigint, entry.amount_paisa;
      continue;
    end if;
    update app.spending_entries set status = 'recorded'
    where institute_id = tenant and id = entry.id;
    select m.matched_paisa, m.unmatched_paisa into matched, unmatched
    from app.match_spending(entry.id) m;
    if unmatched > 0 then
      perform app.reverse_spending(entry.id, 'other', 'Not enough unspent money in the cause');
      return query select entry.id, 'over_balance'::text, 0::bigint, unmatched;
    else
      return query select entry.id, 'recorded'::text, matched, unmatched;
    end if;
  end loop;
  if not seen then
    return query select p_entry_id,
      case when p_entry_id is null then 'nothing_open' else 'not_draft' end,
      null::bigint, null::bigint;
  end if;
end
$function$;
--> statement-breakpoint
-- Reverse one recorded entry and release its matches (P2-E1-T04, P2-E2-T03).
create function identity.reverse_spending_entry(
  p_session_id uuid, p_entry_id uuid, p_category text, p_note text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if not identity.is_finance_session(p_session_id) then
    return 'denied';
  end if;
  begin
    perform app.reverse_spending(p_entry_id, p_category, p_note);
    return 'reversed';
  exception
    when invalid_parameter_value then return 'invalid';
    when no_data_found then return 'not_found';
    when object_not_in_prerequisite_state then return 'not_recorded';
    when insufficient_privilege then return 'denied';
  end;
end
$function$;
--> statement-breakpoint
revoke all on function identity.spending_workspace(uuid),
  identity.save_spending_draft(uuid, uuid, bigint, date, jsonb, boolean),
  identity.record_spending_batch(uuid, uuid),
  identity.reverse_spending_entry(uuid, uuid, text, text) from public;
--> statement-breakpoint
grant execute on function identity.spending_workspace(uuid),
  identity.save_spending_draft(uuid, uuid, bigint, date, jsonb, boolean),
  identity.record_spending_batch(uuid, uuid),
  identity.reverse_spending_entry(uuid, uuid, text, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
