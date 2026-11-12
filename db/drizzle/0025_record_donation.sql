SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The one recording path for money that has arrived (04 §8.3, P1-E3-T43):
-- the donation with its receipt number, the received event and, when a cause
-- is given, the to_cause allocation and its allocated event, plus the audit
-- row, all in the caller's transaction. Any failure undoes all of it, the
-- receipt counter included, so numbers stay gap-free. Table checks and
-- triggers enforce the data rules; this function enforces the actor.
-- Not granted to the runtime roles: the manual form and the transfer-notice
-- confirmation (P1-E3-T46) call it after their own session checks.
create function app.record_donation(
  p_operation_id uuid, p_donor_id uuid, p_cause_id uuid, p_donation_type text,
  p_amount_paisa bigint, p_credited_on date, p_bank_account_id uuid, p_bank_reference text,
  p_receipt_locale text, p_is_anonymous boolean default true, p_private_note text default null
) returns table (donation_id uuid, receipt_number text)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  receipt text;
  recorded_id uuid;
  allocation_id uuid;
begin
  if tenant is null or actor is null
    or not (app.has_role('admin') or app.has_role('finance_officer'))
  then
    raise exception 'recording a donation needs an admin or finance officer'
      using errcode = 'insufficient_privilege';
  end if;

  receipt := app.next_receipt_number(extract(year from today)::smallint);

  insert into app.donations as d (institute_id, operation_id, bank_account_id, bank_reference,
    credited_on, amount_minor, amount_paisa, donation_type, donor_id, cause_id, receipt_number,
    receipt_locale, is_anonymous, private_note, recorded_by)
  values (tenant, p_operation_id, p_bank_account_id, p_bank_reference, p_credited_on,
    p_amount_paisa, p_amount_paisa, p_donation_type, p_donor_id, p_cause_id, receipt,
    p_receipt_locale, coalesce(p_is_anonymous, true), p_private_note, actor)
  returning d.id into recorded_id;

  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, recorded_by)
  values (tenant, recorded_id, 'received', p_credited_on, p_amount_paisa, actor);
  if p_cause_id is not null then
    insert into app.allocations as a (institute_id, kind, donation_id, cause_id, donation_type,
      amount_paisa, created_by)
    values (tenant, 'to_cause', recorded_id, p_cause_id, p_donation_type, p_amount_paisa, actor)
    returning a.id into allocation_id;
    insert into app.trail_events (institute_id, donation_id, event_type, occurred_on,
      amount_paisa, cause_id, allocation_id, recorded_by)
    values (tenant, recorded_id, 'allocated', p_credited_on, p_amount_paisa, p_cause_id, allocation_id, actor);
  end if;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'donations.recorded', 'donations', recorded_id::text,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;

  return query select recorded_id, receipt;
end
$function$;
--> statement-breakpoint
revoke all on function app.record_donation(uuid, uuid, uuid, text, bigint, date, uuid, text, text,
  boolean, text) from public;
--> statement-breakpoint
-- The manual form keeps its checks and answers, and records through
-- app.record_donation().
create or replace function identity.record_manual_donation(
  p_session_id uuid, p_operation_id uuid, p_bank_account_id uuid, p_bank_reference text,
  p_credited_on date, p_amount_paisa bigint, p_donation_type text, p_cause_id uuid,
  p_donor_email text, p_receipt_locale text, p_anonymous boolean,
  p_confirm_large boolean, p_confirm_similar boolean
) returns table (code text, donation_id uuid, receipt_number text)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  reference text := btrim(p_bank_reference);
  guest_email text := nullif(lower(btrim(p_donor_email)), '');
  receipt text;
  prior app.donations%rowtype;
  guest_id uuid;
  recorded_id uuid;
begin
  if not identity.is_finance_session(p_session_id) then
    return query select 'denied'::text, null::uuid, null::text;
    return;
  end if;
  if p_operation_id is null or p_bank_account_id is null or reference is null
    or length(reference) not between 1 and 120 or reference ~ '[[:cntrl:]]'
    or p_credited_on is null or p_credited_on not between date '1900-01-01' and today
    or p_amount_paisa is null or p_amount_paisa not between 100 and 99999999999900
    or p_amount_paisa % 100 <> 0
    or p_donation_type is null or p_donation_type not in ('zakat', 'sadaqah', 'general')
    or p_receipt_locale is null or p_receipt_locale not in ('en', 'ur')
    or p_anonymous is distinct from true
    or (guest_email is not null and (length(guest_email) > 254
      or guest_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'))
  then
    return query select 'invalid'::text, null::uuid, null::text;
    return;
  end if;

  -- Serialize retries even when a reused operation changes the bank account.
  perform pg_advisory_xact_lock(hashtextextended(tenant::text || '/' || p_operation_id::text, 294751));
  select d.* into prior from app.donations d
  where d.institute_id = tenant and d.operation_id = p_operation_id;
  if found then
    if prior.bank_account_id = p_bank_account_id and prior.bank_reference = reference
      and prior.credited_on = p_credited_on and prior.amount_paisa = p_amount_paisa
      and prior.donation_type = p_donation_type and prior.cause_id is not distinct from p_cause_id
      and prior.receipt_locale = p_receipt_locale
      and guest_email is not distinct from (
        select guest.email from app.donors guest where guest.institute_id = tenant and guest.id = prior.donor_id
      )
    then return query select 'existing'::text, prior.id, prior.receipt_number;
    else return query select 'operation_conflict'::text, null::uuid, null::text;
    end if;
    return;
  end if;

  -- Serialize reference and similar-credit checks for this account.
  perform from app.institute_bank_accounts b
  where b.institute_id = tenant and b.id = p_bank_account_id and b.is_active
    and p_donation_type = any (b.for_donation_types)
  for update;
  if not found then
    return query select 'bank_unavailable'::text, null::uuid, null::text;
    return;
  end if;
  if exists (
    select from app.donations d where d.institute_id = tenant and d.bank_account_id = p_bank_account_id
      and d.bank_reference = reference and d.status = 'recorded'
  ) then
    return query select 'bank_reference_conflict'::text, null::uuid, null::text;
    return;
  end if;
  if p_amount_paisa > 100000000 and p_confirm_large is distinct from true then
    return query select 'large_confirmation_required'::text, null::uuid, null::text;
    return;
  end if;
  if p_confirm_similar is distinct from true and exists (
    select from app.donations d where d.institute_id = tenant and d.bank_account_id = p_bank_account_id
      and d.credited_on = p_credited_on and d.amount_paisa = p_amount_paisa and d.status = 'recorded'
  ) then
    return query select 'similar_confirmation_required'::text, null::uuid, null::text;
    return;
  end if;

  if p_cause_id is not null then
    -- The public view closes ended campaigns by date. Historic in-window credits remain eligible.
    perform from app.causes c
    where c.institute_id = tenant and c.id = p_cause_id and c.status = 'active'
      and (c.starts_on is null or p_credited_on >= c.starts_on)
      and (c.ends_on is null or p_credited_on <= c.ends_on)
      and (p_donation_type <> 'zakat' or c.accepts_zakat)
    for update;
    if not found then
      return query select 'cause_unavailable'::text, null::uuid, null::text;
      return;
    end if;
  end if;

  if not exists (select from app.institute_settings s where s.institute_id = tenant) then
    return query select 'invalid'::text, null::uuid, null::text;
    return;
  end if;

  if guest_email is not null then
    insert into app.donors as guest (institute_id, email, preferred_language)
    values (tenant, guest_email, p_receipt_locale)
    on conflict (institute_id, email) do nothing
    returning guest.id into guest_id;
    if guest_id is null then
      select guest.id into strict guest_id from app.donors guest
      where guest.institute_id = tenant and guest.email = guest_email;
    end if;
  else
    insert into app.donors as guest (institute_id, email, preferred_language)
    values (tenant, null, p_receipt_locale)
    returning guest.id into guest_id;
  end if;

  select r.donation_id, r.receipt_number into recorded_id, receipt
  from app.record_donation(p_operation_id, guest_id, p_cause_id, p_donation_type, p_amount_paisa,
    p_credited_on, p_bank_account_id, reference, p_receipt_locale) r;

  return query select 'recorded'::text, recorded_id, receipt;
end
$function$;
--> statement-breakpoint
RESET ROLE;
