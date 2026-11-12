SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
create type identity.donation_trail_row as (
  id uuid, receipt_number text, receipt_locale text, credited_on text, amount_paisa text,
  donation_type text, status text, recorded_at text, events jsonb, reversal_reason text,
  cause_title jsonb, public_ref text, bank_reference_tail text
);
--> statement-breakpoint
-- This helper is private to the definer functions below. Each caller must
-- first resolve a donor from an active private link or the signed-in account.
create function identity.donation_trail_page(
  p_donor uuid, p_before_recorded_at timestamptz, p_before_donation_id uuid, p_public_ref text
) returns setof identity.donation_trail_row
language sql stable
set search_path = pg_catalog, pg_temp
as $function$
  with page as materialized (
    select d.institute_id, d.id, d.receipt_number, d.receipt_locale, d.credited_on,
      d.amount_paisa, d.donation_type, d.status, d.recorded_at, d.cause_id, d.public_ref, d.bank_reference
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
    original_cause.title::jsonb, d.public_ref, right(d.bank_reference, 4)
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
drop function identity.read_guest_trail(text, timestamptz, uuid);
--> statement-breakpoint
create function identity.read_guest_trail(
  p_token_hash text, p_before_recorded_at timestamptz, p_before_donation_id uuid
) returns setof identity.donation_trail_row
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select page.*
  from app.trail_links link
  join app.institutes i on i.id = link.institute_id and i.status = 'active' and i.kind = 'institute'
  join app.donors donor on (donor.institute_id, donor.id) = (link.institute_id, link.donor_id)
  cross join lateral identity.donation_trail_page(link.donor_id, p_before_recorded_at, p_before_donation_id, null) page
  where link.institute_id = app.current_institute_id() and link.revoked_at is null
    and donor.user_id is null and donor.erased_at is null
    and p_token_hash ~ '^[0-9a-f]{64}$' and link.token_hash = p_token_hash
  order by page.recorded_at desc, page.id desc
$function$;
--> statement-breakpoint
create function identity.is_donor_session(p_session uuid) returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return app.has_role('donor') and exists (
  select from identity.sessions s
  join app.users u on (u.institute_id, u.id) = (s.institute_id, s.user_id)
  where s.id = p_session and s.institute_id = app.current_institute_id()
    and s.user_id = app.current_user_id() and s.expires_at > now()
    and s.updated_at > now() - (identity.session_limits(u.id)).idle
    and u.email_verified and not u.must_change_password and u.status in ('active', 'left')
    and (not (app.has_role('admin') or app.has_role('finance_officer')) or identity.staff_session_ok(p_session))
);
--> statement-breakpoint
create function identity.claim_guest_donations(p_session uuid) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if not identity.is_donor_session(p_session) then return 'denied'; end if;
  return app.claim_donor_records();
end
$function$;
--> statement-breakpoint
create function identity.read_account_trail(
  p_session uuid, p_before_recorded_at timestamptz, p_before_donation_id uuid, p_public_ref text
) returns setof identity.donation_trail_row
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select page.*
  from app.donors donor
  cross join lateral identity.donation_trail_page(donor.id, p_before_recorded_at, p_before_donation_id, p_public_ref) page
  where donor.institute_id = app.current_institute_id() and donor.user_id = app.current_user_id()
    and donor.erased_at is null and identity.is_donor_session(p_session)
  order by page.recorded_at desc, page.id desc
$function$;
--> statement-breakpoint
revoke all on function identity.donation_trail_page(uuid, timestamptz, uuid, text), identity.is_donor_session(uuid),
  identity.read_guest_trail(text, timestamptz, uuid), identity.claim_guest_donations(uuid),
  identity.read_account_trail(uuid, timestamptz, uuid, text) from public;
grant execute on function identity.read_guest_trail(text, timestamptz, uuid),
  identity.claim_guest_donations(uuid), identity.read_account_trail(uuid, timestamptz, uuid, text) to tazkiyah_auth;
--> statement-breakpoint
-- A claimed account replaces the guest trail. Issuance and receipt email
-- use the same donor row lock as the claim.
create or replace function identity.issue_trail_link(
  p_session_id uuid, p_receipt_number text, p_donor_email text, p_token_hash text, p_token_hint text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  target_donor uuid;
  issued_link uuid;
  changed_at timestamptz;
  receipt text := upper(btrim(p_receipt_number));
  confirmed_email text := lower(btrim(p_donor_email));
begin
  if not identity.is_staff_admin_session(p_session_id) then return 'denied'; end if;
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
    or p_token_hint is null or p_token_hint !~ '^[A-Za-z0-9_-]{4}$'
    or receipt is null or length(receipt) not between 1 and 120
    or confirmed_email is null or length(confirmed_email) not between 3 and 254
    or confirmed_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
  then return 'invalid'; end if;

  -- Serialize mutations for this donor even when requests use different receipts.
  select guest.id into target_donor
  from app.donations d
  join app.donors guest on (guest.institute_id, guest.id) = (d.institute_id, d.donor_id)
  where d.institute_id = tenant and d.receipt_number = receipt and d.status = 'recorded'
    and guest.email = confirmed_email and guest.user_id is null and guest.erased_at is null
  for update of guest;
  if not found then return 'unavailable'; end if;

  changed_at := clock_timestamp();
  update app.trail_links set revoked_at = changed_at, revoked_by = actor, revoke_reason = 'Replaced by a new link'
  where institute_id = tenant and donor_id = target_donor and revoked_at is null;
  insert into app.trail_links (institute_id, donor_id, token_hash, token_hint, created_at, created_by)
  values (tenant, target_donor, p_token_hash, p_token_hint, changed_at, actor)
  returning id into issued_link;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'trail_links.issued', 'trail_links', issued_link::text,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return 'issued';
exception when unique_violation then
  -- PL/pgSQL rolls back the attempted rotation, preserving the current link.
  return 'collision';
end
$function$;
--> statement-breakpoint
create or replace function mail.prepare_receipt_email(
  p_job_id uuid, p_claim_token uuid, p_trail_hash text, p_payload_hash text
) returns table (
  outcome text, to_email text, receipt_number text, receipt_locale text, credited_on text, amount_paisa text,
  donation_type text, institute_name jsonb, cause_title jsonb, domain text, include_trail boolean
)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  job app.receipt_email_jobs%rowtype;
  donation app.donations%rowtype;
  live_email text;
  account_user uuid;
  canonical_domain text;
  institution jsonb;
  cause jsonb;
begin
  select j.* into job from app.receipt_email_jobs j
  where j.id = p_job_id and j.state = 'leased' and j.claim_token = p_claim_token
    and j.lease_expires_at > clock_timestamp()
  for update;
  if not found then outcome := 'stale'; return next; return; end if;
  if p_trail_hash is null or p_trail_hash !~ '^[0-9a-f]{64}$'
    or (p_payload_hash is not null and (p_payload_hash !~ '^[0-9a-f]{64}$' or job.snapshot is null))
  then outcome := 'invalid'; return next; return; end if;

  select d.* into donation from app.donations d
  where d.institute_id = job.institute_id and d.id = job.donation_id and d.status = 'recorded';
  if not found or donation.donor_id is distinct from job.donor_id
  then outcome := 'donation_unavailable'; return next; return; end if;

  -- The same donor lock also serializes administrator issuance and revocation.
  select guest.email, guest.user_id into live_email, account_user from app.donors guest
  where guest.institute_id = job.institute_id and guest.id = job.donor_id and guest.erased_at is null
  for update;
  if live_email is distinct from job.to_email
  then outcome := 'recipient_changed'; return next; return; end if;

  select settings.name::jsonb, address.domain into institution, canonical_domain
  from app.institutes i
  join app.institute_settings settings on settings.institute_id = i.id
  join app.institute_domains address on address.institute_id = i.id and address.is_primary
  where i.id = job.institute_id and i.status = 'active' and i.kind = 'institute';
  if not found then outcome := 'configuration'; return next; return; end if;

  if job.snapshot is null then
    select c.title::jsonb into cause from app.causes c
    where c.institute_id = job.institute_id and c.id = donation.cause_id;

    if account_user is null and not exists (
      select from app.trail_links link
      where link.institute_id = job.institute_id and link.donor_id = job.donor_id and link.revoked_at is null
    ) then
      insert into app.trail_links (institute_id, donor_id, token_hash, created_by)
      values (job.institute_id, job.donor_id, p_trail_hash, donation.recorded_by)
      on conflict (token_hash) do nothing
      returning id into job.trail_link_id;
      if not found then outcome := 'payload_changed'; return next; return; end if;
      insert into app.audit_log (institute_id, actor_kind, action, entity_table, entity_id)
      values (job.institute_id, 'job', 'trail_links.email_issued', 'trail_links', job.trail_link_id::text);
    end if;

    job.snapshot := jsonb_build_object(
      'receipt_number', donation.receipt_number, 'receipt_locale', donation.receipt_locale,
      'credited_on', to_char(donation.credited_on, 'YYYY-MM-DD'), 'amount_paisa', donation.amount_paisa::text,
      'donation_type', donation.donation_type, 'institute_name', institution, 'cause_title', cause,
      'domain', canonical_domain
    );
    update app.receipt_email_jobs j set snapshot = job.snapshot, trail_link_id = job.trail_link_id
    where j.id = job.id;
  elsif canonical_domain is distinct from job.snapshot ->> 'domain'
    or (job.trail_link_id is not null and not exists (
      select from app.trail_links link
      where link.institute_id = job.institute_id and link.id = job.trail_link_id
        and link.donor_id = job.donor_id and link.revoked_at is null and link.token_hash = p_trail_hash
    ))
  then outcome := 'payload_changed'; return next; return; end if;

  if p_payload_hash is not null then
    if job.payload_hash is not null and job.payload_hash <> p_payload_hash
    then outcome := 'payload_changed'; return next; return; end if;
    update app.receipt_email_jobs j set payload_hash = p_payload_hash
    where j.id = job.id and j.payload_hash is null;
  end if;

  outcome := 'ready';
  to_email := job.to_email;
  receipt_number := job.snapshot ->> 'receipt_number';
  receipt_locale := job.snapshot ->> 'receipt_locale';
  credited_on := job.snapshot ->> 'credited_on';
  amount_paisa := job.snapshot ->> 'amount_paisa';
  donation_type := job.snapshot ->> 'donation_type';
  institute_name := job.snapshot -> 'institute_name';
  cause_title := nullif(job.snapshot -> 'cause_title', 'null'::jsonb);
  domain := job.snapshot ->> 'domain';
  include_trail := job.trail_link_id is not null;
  return next;
end
$function$;
--> statement-breakpoint
RESET ROLE;
