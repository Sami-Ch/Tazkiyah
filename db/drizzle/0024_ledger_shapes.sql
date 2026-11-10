SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "app"."allocations" DROP CONSTRAINT "allocations_manual_kind_check";--> statement-breakpoint
ALTER TABLE "app"."trail_events" DROP CONSTRAINT "trail_events_manual_shape_check";--> statement-breakpoint
ALTER TABLE "app"."allocations" ALTER COLUMN "cause_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD COLUMN "from_allocation_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD COLUMN "spending_entry_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD COLUMN "target_institute_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD COLUMN "is_reversal" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD COLUMN "reverses_allocation_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD COLUMN "reason" text;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD COLUMN "spending_entry_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD COLUMN "spending_report_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD COLUMN "reverses_event_id" bigint;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD COLUMN "reason" text;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD COLUMN "details" jsonb DEFAULT '{}'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_target_institute_id_institutes_id_fk" FOREIGN KEY ("target_institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_institute_id_from_allocation_id_allocations_institute_id_id_fk" FOREIGN KEY ("institute_id","from_allocation_id") REFERENCES "app"."allocations"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_institute_id_reverses_allocation_id_allocations_institute_id_id_fk" FOREIGN KEY ("institute_id","reverses_allocation_id") REFERENCES "app"."allocations"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_reverses_event_id_trail_events_institute_id_id_fk" FOREIGN KEY ("institute_id","reverses_event_id") REFERENCES "app"."trail_events"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "allocations_from_allocation" ON "app"."allocations" USING btree ("institute_id","from_allocation_id") WHERE from_allocation_id is not null;--> statement-breakpoint
CREATE INDEX "allocations_spending_entry" ON "app"."allocations" USING btree ("institute_id","spending_entry_id") WHERE spending_entry_id is not null;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_institute_id_reverses_allocation_id_unique" UNIQUE("institute_id","reverses_allocation_id");--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_reverses_event_id_unique" UNIQUE("institute_id","reverses_event_id");--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_shape_check" CHECK ((kind = 'to_cause' and cause_id is not null and from_allocation_id is null and spending_entry_id is null and target_institute_id is null) or (kind = 'to_spending' and cause_id is not null and from_allocation_id is not null and spending_entry_id is not null and target_institute_id is null) or (kind = 'to_institute' and target_institute_id is not null and cause_id is null and from_allocation_id is null and spending_entry_id is null));--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_reversal_check" CHECK (is_reversal = (reverses_allocation_id is not null) and (reason is null) = (not is_reversal) and (reason is null or (length(reason) between 1 and 500 and reason = btrim(reason))));--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_shape_check" CHECK ((event_type = 'received' and cause_id is null and allocation_id is null and spending_entry_id is null and spending_report_id is null and reverses_event_id is null) or (event_type = 'allocated' and allocation_id is not null and spending_entry_id is null and spending_report_id is null and reverses_event_id is null) or (event_type = 'spent' and cause_id is not null and allocation_id is not null and spending_entry_id is not null and spending_report_id is null and reverses_event_id is null) or (event_type = 'reported' and cause_id is null and allocation_id is null and spending_entry_id is null and spending_report_id is not null and reverses_event_id is null) or (event_type = 'reversal' and reverses_event_id is not null and spending_report_id is null));--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_reason_check" CHECK ((reason is null) = (event_type <> 'reversal') and (reason is null or (length(reason) between 1 and 500 and reason = btrim(reason))));--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_details_check" CHECK (jsonb_typeof(details) = 'object');
--> statement-breakpoint
ALTER TABLE "app"."trail_events" RENAME COLUMN "credited_on" TO "occurred_on";
--> statement-breakpoint
-- Allocation rules checked on every insert (04 §9.2, P1-E3-T42). The donation
-- row is locked first, so every allocation of one donation is serialized and
-- the deferred sum check below sees a stable ledger.
create function app.allocations_rules() returns trigger
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
  if new.donation_type <> gift.donation_type then
    raise exception 'allocation type % must equal the donation type %', new.donation_type, gift.donation_type
      using errcode = 'check_violation';
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
create trigger allocations_rules before insert on app.allocations
for each row execute function app.allocations_rules();
--> statement-breakpoint
-- Sum checks at commit (§9.2). "Effective" rows are originals with no
-- reversal. A reversed cause allocation counts as zero, so it cannot be
-- reversed while money spent from it remains (REQ-TRL-003, P1-E3-T45).
-- The per-spending-entry cap arrives with spending_entries (P2-E1-T40).
create function app.allocations_sum_check() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
declare
  placed bigint;
  cap bigint;
  source_id uuid;
begin
  select coalesce(sum(a.amount_paisa), 0) into placed from app.allocations a
  where a.institute_id = new.institute_id and a.donation_id = new.donation_id
    and a.kind in ('to_cause', 'to_institute') and not a.is_reversal
    and not exists (select from app.allocations r
      where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id);
  select d.amount_paisa into cap from app.donations d
  where d.institute_id = new.institute_id and d.id = new.donation_id;
  if placed > cap then
    raise exception 'donation % would have % paisa allocated but holds only %', new.donation_id, placed, cap
      using errcode = 'check_violation';
  end if;

  source_id := case
    when new.kind = 'to_spending' then new.from_allocation_id
    when new.kind = 'to_cause' and new.is_reversal then new.reverses_allocation_id
  end;
  if source_id is not null then
    select coalesce(sum(a.amount_paisa), 0) into placed from app.allocations a
    where a.institute_id = new.institute_id and a.from_allocation_id = source_id and not a.is_reversal
      and not exists (select from app.allocations r
        where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id);
    select case when exists (select from app.allocations r
        where r.institute_id = s.institute_id and r.reverses_allocation_id = s.id)
      then 0 else s.amount_paisa end into cap
    from app.allocations s where s.institute_id = new.institute_id and s.id = source_id;
    if placed > cap then
      raise exception 'allocation % would have % paisa spent from it but holds only %', source_id, placed, cap
        using errcode = 'check_violation';
    end if;
  end if;
  return null;
end
$function$;
--> statement-breakpoint
create constraint trigger allocations_sum_check after insert on app.allocations
deferrable initially deferred
for each row execute function app.allocations_sum_check();
--> statement-breakpoint
-- Trail events must agree with the ledger (§9.6): an allocated or spent event
-- names its own allocation with the same donation, cause and amount; a
-- received event carries the donation's amount; a reversal points at an
-- earlier non-reversal event of the same donation and, when that event had an
-- allocation, at the allocation that reverses it.
create function app.trail_events_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
declare
  ledger app.allocations%rowtype;
  original app.trail_events%rowtype;
begin
  if new.event_type = 'received' and new.amount_paisa is distinct from (
    select d.amount_paisa from app.donations d where d.institute_id = new.institute_id and d.id = new.donation_id
  ) then
    raise exception 'a received event carries the whole donation amount' using errcode = 'check_violation';
  end if;

  if new.allocation_id is not null then
    select a.* into ledger from app.allocations a
    where a.institute_id = new.institute_id and a.id = new.allocation_id;
    if ledger.donation_id <> new.donation_id or ledger.amount_paisa <> new.amount_paisa
      or ledger.cause_id is distinct from new.cause_id
      or ledger.spending_entry_id is distinct from new.spending_entry_id
      or (new.event_type = 'allocated' and (ledger.kind = 'to_spending' or ledger.is_reversal))
      or (new.event_type = 'spent' and (ledger.kind <> 'to_spending' or ledger.is_reversal))
      or (new.event_type = 'reversal' and not ledger.is_reversal)
    then
      raise exception 'trail event does not match allocation %', new.allocation_id
        using errcode = 'check_violation';
    end if;
  end if;

  if new.event_type = 'reversal' then
    select e.* into original from app.trail_events e
    where e.institute_id = new.institute_id and e.id = new.reverses_event_id;
    if original.donation_id <> new.donation_id or original.event_type = 'reversal'
      or original.amount_paisa <> new.amount_paisa
      or (original.allocation_id is null) <> (new.allocation_id is null)
      or (new.allocation_id is not null and ledger.reverses_allocation_id <> original.allocation_id)
    then
      raise exception 'reversal event does not match event %', new.reverses_event_id
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger trail_events_rules before insert on app.trail_events
for each row execute function app.trail_events_rules();
--> statement-breakpoint
-- The renamed column, in the recording function (unchanged otherwise).
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
  allocation_id uuid;
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

  receipt := app.next_receipt_number(extract(year from today)::smallint);

  insert into app.donations as d (institute_id, operation_id, bank_account_id, bank_reference,
    credited_on, amount_minor, amount_paisa, donation_type, donor_id, cause_id, receipt_number,
    receipt_locale, recorded_by)
  values (tenant, p_operation_id, p_bank_account_id, reference, p_credited_on,
    p_amount_paisa, p_amount_paisa, p_donation_type, guest_id, p_cause_id, receipt,
    p_receipt_locale, actor)
  returning d.id into recorded_id;

  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, recorded_by)
  values (tenant, recorded_id, 'received', p_credited_on, p_amount_paisa, actor);
  if p_cause_id is not null then
    insert into app.allocations as a (institute_id, donation_id, cause_id, donation_type, amount_paisa, created_by)
    values (tenant, recorded_id, p_cause_id, p_donation_type, p_amount_paisa, actor)
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

  return query select 'recorded'::text, recorded_id, receipt;
end
$function$;
--> statement-breakpoint
-- The guest trail reads the renamed column and leaves out reversed events.
create or replace function identity.read_guest_trail(
  p_token_hash text, p_before_recorded_at timestamptz, p_before_donation_id uuid
) returns table (
  id uuid, receipt_number text, receipt_locale text, credited_on text, amount_paisa text,
  donation_type text, status text, recorded_at text, events jsonb
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
    coalesce(trail.events, '[]'::jsonb)
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
-- Public totals count only allocations that have not been reversed. A
-- reversal has its original's cause and kind, so it simply subtracts.
create or replace view public_api.causes with (security_barrier = true) as
select c.id, c.slug, c.cause_type, c.title, c.summary, c.body, c.target_paisa,
  c.target_period, c.stock_year_start_month, c.starts_on, c.ends_on,
  c.accepts_zakat, c.zakat_approved_by,
  case when c.status = 'active' and c.ends_on < clock.today then 'closed' else c.status end as status,
  c.display_order, c.created_at,
  totals.raised_paisa, totals.lifetime_raised_paisa
from app.causes c
join public_api.institute_public i on i.institute_id = c.institute_id
cross join lateral (select (now() at time zone 'Asia/Karachi')::date as today) clock
cross join lateral (
  select case
    when c.cause_type = 'ongoing' and c.target_period = 'monthly'
      then date_trunc('month', clock.today::timestamp)::date
    when c.cause_type = 'ongoing' and c.target_period = 'yearly'
      then date_trunc('year', clock.today::timestamp)::date
    when c.cause_type = 'yearly_stock'
      then (date_trunc('year', clock.today - months.shift) + months.shift)::date
    else '-infinity'::date
  end as first_day
  from (select make_interval(months => c.stock_year_start_month - 1) as shift) months
) period
cross join lateral (
  select
    coalesce(sum(signed.amount) filter (where d.credited_on >= period.first_day), 0) as raised_paisa,
    coalesce(sum(signed.amount), 0) as lifetime_raised_paisa
  from app.allocations a
  join app.donations d on (d.institute_id, d.id) = (a.institute_id, a.donation_id)
  cross join lateral (select case when a.is_reversal then -a.amount_paisa else a.amount_paisa end as amount) signed
  where a.institute_id = c.institute_id and a.cause_id = c.id
    and a.kind = 'to_cause' and d.status = 'recorded'
) totals
where c.status in ('active', 'closed', 'archived')
  and (c.starts_on is null or c.starts_on <= clock.today);
--> statement-breakpoint
RESET ROLE;
