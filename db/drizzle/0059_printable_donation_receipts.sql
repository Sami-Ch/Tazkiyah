SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "replaces_donation_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_replaces_donation_fkey" FOREIGN KEY ("institute_id","replaces_donation_id") REFERENCES "app"."donations"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_replaces_once" UNIQUE("institute_id","replaces_donation_id");--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_replaces_check" CHECK (replaces_donation_id is null or (id <> replaces_donation_id and method = 'bank_transfer'));
--> statement-breakpoint
create or replace function app.donations_column_lock() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op <> 'UPDATE' then
    raise exception 'donations cannot be deleted; record a reversal instead'
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if to_jsonb(new) - array['is_anonymous', 'trail_public', 'status', 'statement_audit_id', 'statement_matched', 'replaces_donation_id']
    is distinct from to_jsonb(old) - array['is_anonymous', 'trail_public', 'status', 'statement_audit_id', 'statement_matched', 'replaces_donation_id']
  then
    raise exception 'donation % is locked: record a reversal to correct its details', old.id
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if new.status is distinct from old.status
    and not (old.status = 'recorded' and new.status = 'reversed')
  then
    raise exception 'donation % cannot move from % to %', old.id, old.status, new.status
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if new.replaces_donation_id is distinct from old.replaces_donation_id
    and (old.replaces_donation_id is not null or new.status <> 'recorded' or not exists (
      select from app.donations replaced
      where replaced.institute_id = new.institute_id and replaced.id = new.replaces_donation_id
        and replaced.method = 'bank_transfer' and replaced.status = 'reversed'
    ))
  then
    raise exception 'a replacement receipt must point to a cancelled bank transfer and cannot be changed'
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
alter function identity.record_manual_donation(uuid, uuid, uuid, text, date, bigint,
  text, uuid, text, text, boolean, boolean, boolean) rename to record_manual_donation_core;
--> statement-breakpoint
revoke all on function identity.record_manual_donation_core(uuid, uuid, uuid, text, date, bigint,
  text, uuid, text, text, boolean, boolean, boolean) from tazkiyah_auth;
--> statement-breakpoint
create function identity.record_manual_donation(
  p_session_id uuid, p_operation_id uuid, p_bank_account_id uuid, p_bank_reference text,
  p_credited_on date, p_amount_paisa bigint, p_donation_type text, p_cause_id uuid,
  p_donor_email text, p_receipt_locale text, p_anonymous boolean, p_confirm_large boolean,
  p_confirm_similar boolean, p_replaces_receipt text default null
) returns table (code text, donation_id uuid, receipt_number text)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  replaces_receipt text := nullif(upper(btrim(p_replaces_receipt)), '');
  prior_replaces_receipt text;
  replaces_id uuid;
  result record;
begin
  if not identity.is_finance_session(p_session_id) then
    return query select 'denied'::text, null::uuid, null::text;
    return;
  end if;
  if p_operation_id is null or (replaces_receipt is not null
    and replaces_receipt !~ '^[A-Z0-9]{1,64}-[0-9]{4}-[0-9]{5,19}$')
  then
    return query select 'invalid'::text, null::uuid, null::text;
    return;
  end if;

  -- Share the core's operation lock so a retry must use the same predecessor.
  perform pg_advisory_xact_lock(hashtextextended(tenant::text || '/' || p_operation_id::text, 294751));
  select old.receipt_number into prior_replaces_receipt
  from app.donations existing
  left join app.donations old on (old.institute_id, old.id) = (existing.institute_id, existing.replaces_donation_id)
  where existing.institute_id = tenant and existing.operation_id = p_operation_id;
  if found then
    if prior_replaces_receipt is distinct from replaces_receipt then
      return query select 'operation_conflict'::text, null::uuid, null::text;
      return;
    end if;
  elsif replaces_receipt is not null then
    -- Serialize competing corrections before allocating a new receipt number.
    select d.id into replaces_id from app.donations d
    where d.institute_id = tenant and d.receipt_number = replaces_receipt
      and d.method = 'bank_transfer' and d.status = 'reversed'
    for no key update;
    if not found or exists (
      select from app.donations d where d.institute_id = tenant and d.replaces_donation_id = replaces_id
    )
    then
      return query select 'replacement_unavailable'::text, null::uuid, null::text;
      return;
    end if;
  end if;

  select * into strict result from identity.record_manual_donation_core(
    p_session_id, p_operation_id, p_bank_account_id, p_bank_reference, p_credited_on,
    p_amount_paisa, p_donation_type, p_cause_id, p_donor_email, p_receipt_locale,
    p_anonymous, p_confirm_large, p_confirm_similar
  );
  if result.code = 'recorded' and replaces_id is not null then
    update app.donations d set replaces_donation_id = replaces_id
    where d.institute_id = tenant and d.id = result.donation_id;

    insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
      action, entity_table, entity_id, changes, request_id)
    select tenant, actor, 'user', array_agg(r.role order by r.role), 'donations.receipt_replaced',
      'donations', result.donation_id::text,
      jsonb_build_object('replaces_donation_id', jsonb_build_object('old', null, 'new', replaces_id)),
      nullif(current_setting('app.request_id', true), '')
    from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  end if;
  return query select result.code, result.donation_id, result.receipt_number;
end
$function$;
--> statement-breakpoint
revoke all on function identity.record_manual_donation(uuid, uuid, uuid, text, date, bigint,
  text, uuid, text, text, boolean, boolean, boolean, text) from public;
grant execute on function identity.record_manual_donation(uuid, uuid, uuid, text, date, bigint,
  text, uuid, text, text, boolean, boolean, boolean, text) to tazkiyah_auth;
--> statement-breakpoint
alter type identity.donation_trail_row
  add attribute donor_name text,
  add attribute issuer_name jsonb,
  add attribute issuer_address jsonb,
  add attribute issuer_slug text,
  add attribute issuer_logo_key text,
  add attribute replaces_donation boolean,
  add attribute replaces_receipt text;
--> statement-breakpoint
create or replace function identity.donation_trail_page(
  p_donor uuid, p_before_recorded_at timestamptz, p_before_donation_id uuid, p_public_ref text
) returns setof identity.donation_trail_row
language sql stable
set search_path = pg_catalog, pg_temp
as $function$
  with page as materialized (
    select d.institute_id, d.id, d.receipt_number, d.receipt_locale, d.credited_on,
      d.amount_paisa, d.donation_type, d.status, d.recorded_at, d.cause_id, d.public_ref,
      d.bank_reference, d.is_anonymous, d.donor_id, d.replaces_donation_id
    from app.donations d
    where d.institute_id = app.current_institute_id() and d.donor_id = p_donor
      and (p_public_ref is null or d.public_ref = p_public_ref)
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
    original_cause.title::jsonb, d.public_ref, right(d.bank_reference, 4),
    case when not d.is_anonymous then coalesce(donor.display_name, account.full_name) end,
    settings.name::jsonb, settings.address::jsonb, i.slug, logo.storage_key,
    d.replaces_donation_id is not null, replaced.receipt_number
  from page d
  join app.institutes i on i.id = d.institute_id
  left join app.institute_settings settings on settings.institute_id = i.id
  left join public_api.institute_logo logo on logo.institute_id = i.id
  join app.donors donor on (donor.institute_id, donor.id) = (d.institute_id, d.donor_id)
  left join app.users account on (account.institute_id, account.id) = (donor.institute_id, donor.user_id)
  -- A correction to the donor must not expose the other donor's receipt number.
  left join app.donations replaced on (replaced.institute_id, replaced.id, replaced.donor_id)
    = (d.institute_id, d.replaces_donation_id, d.donor_id)
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
RESET ROLE;
