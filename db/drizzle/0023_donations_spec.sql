SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Donations to the full 04 §8.3 shape (P1-E3-T41): public reference, currency
-- fields, reserved gateway and platform-transfer sources, trail privacy flag,
-- staff note, required donor, column lock, cause rules and receipt numbering.
--
-- A 10-character base32 reference for public URLs. 50 random bits; it is not
-- the receipt number and carries nothing about the donor.
create function app.new_public_ref() returns text
language sql volatile
set search_path = pg_catalog, pg_temp
return (
  select string_agg(substr('abcdefghijklmnopqrstuvwxyz234567', (get_byte(bytes, i) & 31) + 1, 1), '' order by i)
  from (select uuid_send(gen_random_uuid()) as bytes) random_source,
    unnest(array[0, 1, 2, 3, 4, 5, 9, 10, 11, 12]) as i
);
--> statement-breakpoint
revoke all on function app.new_public_ref() from public;
--> statement-breakpoint
-- The next receipt number of the current institute for a year, gap-free: the
-- counter row stays locked until the recording transaction ends (§8.3).
-- Called only from definer functions; the runtime roles cannot burn numbers.
create function app.next_receipt_number(p_year smallint) returns text
language plpgsql volatile
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  prefix text;
  sequence_number bigint;
begin
  select s.receipt_prefix into prefix from app.institute_settings s where s.institute_id = tenant;
  if tenant is null or prefix is null or p_year is null then
    raise exception 'receipt numbers need an institute with a receipt prefix and a year'
      using errcode = 'invalid_parameter_value';
  end if;
  insert into app.receipt_counters as counters (institute_id, year, last_number)
  values (tenant, p_year, 1)
  on conflict (institute_id, year) do update set last_number = counters.last_number + 1
  returning counters.last_number into sequence_number;
  return prefix || '-' || p_year || '-' ||
    lpad(sequence_number::text, greatest(5, length(sequence_number::text)), '0');
end
$function$;
--> statement-breakpoint
revoke all on function app.next_receipt_number(smallint) from public;
--> statement-breakpoint
-- Every donation now has a donor. A transfer recorded with no known donor gets
-- its own donor row with no email (04 §8.2), so nothing links unknown gifts.
alter table app.donations add column backfill_donor_id uuid;
--> statement-breakpoint
update app.donations set backfill_donor_id = gen_random_uuid() where donor_id is null;
--> statement-breakpoint
insert into app.donors (id, institute_id, email, preferred_language, created_at)
select d.backfill_donor_id, d.institute_id, null, d.receipt_locale, d.recorded_at
from app.donations d where d.backfill_donor_id is not null;
--> statement-breakpoint
update app.donations set donor_id = backfill_donor_id where backfill_donor_id is not null;
--> statement-breakpoint
alter table app.donations drop column backfill_donor_id;
--> statement-breakpoint
ALTER TABLE "app"."donations" DROP CONSTRAINT "donations_bank_reference_check";--> statement-breakpoint
ALTER TABLE "app"."donations" ALTER COLUMN "bank_account_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donations" ALTER COLUMN "bank_reference" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donations" ALTER COLUMN "currency" SET DATA TYPE char(3);--> statement-breakpoint
ALTER TABLE "app"."donations" ALTER COLUMN "currency" SET DEFAULT 'PKR';--> statement-breakpoint
ALTER TABLE "app"."donations" ALTER COLUMN "donor_id" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "public_ref" text DEFAULT app.new_public_ref() NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "amount_minor" bigint;--> statement-breakpoint
UPDATE "app"."donations" SET "amount_minor" = "amount_paisa";--> statement-breakpoint
ALTER TABLE "app"."donations" ALTER COLUMN "amount_minor" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "fx_rate" numeric(18, 8);--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "gateway_payment_id" text;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "source_allocation_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "trail_public" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "private_note" text;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_source_allocation_id_allocations_id_fk" FOREIGN KEY ("source_allocation_id") REFERENCES "app"."allocations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_public_ref_unique" UNIQUE("institute_id","public_ref");--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_gateway_payment_id_unique" UNIQUE("institute_id","gateway_payment_id");--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_bank_guard_check" CHECK (method <> 'bank_transfer' or (bank_account_id is not null and bank_reference is not null));--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_method_check" CHECK (method in ('bank_transfer', 'card', 'jazzcash', 'easypaisa', 'platform_transfer') and frequency in ('one_off', 'monthly', 'yearly'));--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_source_check" CHECK ((method = 'platform_transfer') = (source_allocation_id is not null) and (gateway_payment_id is null or method in ('card', 'jazzcash', 'easypaisa')));--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_currency_check" CHECK (currency ~ '^[A-Z]{3}$' and amount_minor > 0 and ((currency = 'PKR' and amount_minor = amount_paisa and fx_rate is null) or (currency <> 'PKR' and fx_rate > 0)));--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_public_ref_check" CHECK (public_ref ~ '^[a-z2-7]{10}$');--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_private_note_check" CHECK (private_note is null or length(private_note) between 1 and 2000);--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_bank_reference_check" CHECK (bank_reference is null or (length(bank_reference) between 1 and 120 and bank_reference = btrim(bank_reference) and bank_reference !~ '[[:cntrl:]]'));
--> statement-breakpoint
-- After insert only is_anonymous, trail_public and status may change, and
-- status only from recorded to reversed. Corrections are a reversal plus a new
-- donation (REQ-DON-012); donations are never deleted.
create function app.donations_column_lock() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op <> 'UPDATE' then
    raise exception 'donations cannot be deleted; record a reversal instead'
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if to_jsonb(new) - array['is_anonymous', 'trail_public', 'status']
    is distinct from to_jsonb(old) - array['is_anonymous', 'trail_public', 'status']
  then
    raise exception 'donation % is locked: only the name and trail choices may change', old.id
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if new.status is distinct from old.status
    and not (old.status = 'recorded' and new.status = 'reversed')
  then
    raise exception 'donation % cannot move from % to %', old.id, old.status, new.status
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger donations_column_lock before update or delete on app.donations
for each row execute function app.donations_column_lock();
--> statement-breakpoint
create trigger donations_no_truncate before truncate on app.donations
for each statement execute function app.forbid_change();
--> statement-breakpoint
-- A donation given to a cause needs an active cause, inside a campaign's end
-- date (REQ-DON-006), and a Zakat-eligible cause for Zakat money (§9.4 rule 1).
create function app.donations_cause_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
declare
  target app.causes%rowtype;
begin
  if new.cause_id is null then return new; end if;
  select c.* into target from app.causes c
  where c.institute_id = new.institute_id and c.id = new.cause_id;
  if not found or target.status <> 'active' then
    raise exception 'donations can be given only to an active cause'
      using errcode = 'check_violation';
  end if;
  if target.cause_type = 'campaign' and new.credited_on > target.ends_on then
    raise exception 'the campaign ended on %; record a later transfer as all needs', target.ends_on
      using errcode = 'check_violation';
  end if;
  if new.donation_type = 'zakat' and not target.accepts_zakat then
    raise exception 'this cause does not accept Zakat'
      using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger donations_cause_rules before insert on app.donations
for each row execute function app.donations_cause_rules();
--> statement-breakpoint
-- Recording now always names a donor (an emailless one when the payer is not
-- known), fills the currency fields and takes the receipt number from
-- app.next_receipt_number(). Everything else is unchanged from 0009.
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

  insert into app.trail_events (institute_id, donation_id, event_type, credited_on, amount_paisa, recorded_by)
  values (tenant, recorded_id, 'received', p_credited_on, p_amount_paisa, actor);
  if p_cause_id is not null then
    insert into app.allocations as a (institute_id, donation_id, cause_id, donation_type, amount_paisa, created_by)
    values (tenant, recorded_id, p_cause_id, p_donation_type, p_amount_paisa, actor)
    returning a.id into allocation_id;
    insert into app.trail_events (institute_id, donation_id, event_type, credited_on,
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
RESET ROLE;
