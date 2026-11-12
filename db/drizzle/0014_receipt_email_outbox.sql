SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
RESET ROLE;
--> statement-breakpoint
do $mail_role$
begin
  if not exists (select from pg_catalog.pg_roles where rolname = 'tazkiyah_mail') then
    create role tazkiyah_mail nologin;
  end if;
  if exists (
    select from pg_catalog.pg_roles r where r.rolname = 'tazkiyah_mail'
      and (r.rolcanlogin or r.rolsuper or r.rolbypassrls or r.rolcreaterole or r.rolcreatedb or r.rolreplication
        or exists (select from pg_catalog.pg_auth_members m where m.member = r.oid))
  ) then
    raise exception 'The receipt email role must be NOLOGIN with no elevated privileges or memberships';
  end if;
end
$mail_role$;
--> statement-breakpoint
CREATE SCHEMA "mail" AUTHORIZATION tazkiyah_schema_owner;
--> statement-breakpoint
SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."receipt_email_jobs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"donation_id" uuid NOT NULL,
	"donor_id" uuid NOT NULL,
	"to_email" text,
	"state" text DEFAULT 'pending' NOT NULL,
	"attempts" smallint DEFAULT 0 NOT NULL,
	"first_attempt_at" timestamp with time zone,
	"next_attempt_at" timestamp with time zone DEFAULT now() NOT NULL,
	"claim_token" uuid,
	"lease_expires_at" timestamp with time zone,
	"snapshot" jsonb,
	"trail_link_id" uuid,
	"payload_hash" text,
	"last_error" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"finished_at" timestamp with time zone,
	CONSTRAINT "receipt_email_jobs_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "receipt_email_jobs_institute_id_donation_id_unique" UNIQUE("institute_id","donation_id"),
	CONSTRAINT "receipt_email_jobs_state_check" CHECK (state in ('pending', 'leased', 'sent', 'failed')),
	CONSTRAINT "receipt_email_jobs_attempts_check" CHECK (attempts between 0 and 6 and (attempts = 0) = (first_attempt_at is null)),
	CONSTRAINT "receipt_email_jobs_lease_check" CHECK ((state = 'leased') = (claim_token is not null) and (claim_token is null) = (lease_expires_at is null)),
	CONSTRAINT "receipt_email_jobs_terminal_check" CHECK (
        (state in ('sent', 'failed')) = (finished_at is not null)
        and (finished_at is null) = (to_email is not null)
        and (finished_at is null or snapshot is null)
      ),
	CONSTRAINT "receipt_email_jobs_payload_check" CHECK (payload_hash is null or payload_hash ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "receipt_email_jobs_error_check" CHECK (
        last_error is null or last_error in ('rate_limited', 'provider_unavailable', 'network_error',
          'configuration', 'provider_rejected', 'recipient_changed', 'donation_unavailable',
          'payload_changed', 'attempts_exhausted', 'retry_window_expired')
      )
);
--> statement-breakpoint
ALTER TABLE "app"."receipt_email_jobs" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."receipt_email_jobs" ADD CONSTRAINT "receipt_email_jobs_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."receipt_email_jobs" ADD CONSTRAINT "receipt_email_jobs_institute_id_donation_id_donations_institute_id_id_fk" FOREIGN KEY ("institute_id","donation_id") REFERENCES "app"."donations"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."receipt_email_jobs" ADD CONSTRAINT "receipt_email_jobs_institute_id_donor_id_donors_institute_id_id_fk" FOREIGN KEY ("institute_id","donor_id") REFERENCES "app"."donors"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."receipt_email_jobs" ADD CONSTRAINT "receipt_email_jobs_institute_id_trail_link_id_trail_links_institute_id_id_fk" FOREIGN KEY ("institute_id","trail_link_id") REFERENCES "app"."trail_links"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "receipt_email_jobs_pending" ON "app"."receipt_email_jobs" USING btree ("next_attempt_at","id") WHERE state = 'pending';--> statement-breakpoint
CREATE INDEX "receipt_email_jobs_leased" ON "app"."receipt_email_jobs" USING btree ("lease_expires_at","id") WHERE state = 'leased';--> statement-breakpoint
CREATE POLICY "iso" ON "app"."receipt_email_jobs" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));
--> statement-breakpoint
revoke all on schema mail from public, tazkiyah_app, tazkiyah_auth;
grant usage on schema mail to tazkiyah_mail;
revoke all on app.receipt_email_jobs from public, tazkiyah_app, tazkiyah_auth, tazkiyah_mail;
--> statement-breakpoint
create function app.enqueue_receipt_email() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.status <> 'recorded' or new.donor_id is null
    or current_setting('app.receipt_email_confirmed', true) is distinct from 'true'
  then return null; end if;

  insert into app.receipt_email_jobs (institute_id, donation_id, donor_id, to_email)
  select new.institute_id, new.id, guest.id, guest.email
  from app.donors guest
  where guest.institute_id = new.institute_id and guest.id = new.donor_id and guest.email is not null
  on conflict (institute_id, donation_id) do nothing;
  return null;
end
$function$;
--> statement-breakpoint
create trigger enqueue_receipt_email after insert on app.donations
for each row execute function app.enqueue_receipt_email();
--> statement-breakpoint
create function mail.claim_receipt_emails(p_limit integer)
returns table (job_id uuid, claim_token uuid)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  claim_at timestamptz := clock_timestamp();
begin
  if p_limit is null or p_limit < 1 then return; end if;

  -- Reap abandoned or exhausted jobs in bounded batches without blocking live leases.
  with expired as (
    select j.id
    from app.receipt_email_jobs j
    where (j.state = 'pending' or (j.state = 'leased' and j.lease_expires_at <= claim_at))
      and (j.attempts >= 6 or j.first_attempt_at + interval '23 hours' <= claim_at)
    order by j.created_at, j.id
    limit 50 for update skip locked
  )
  update app.receipt_email_jobs j
  set state = 'failed', claim_token = null, lease_expires_at = null, finished_at = claim_at,
    to_email = null, snapshot = null,
    last_error = case when j.first_attempt_at + interval '23 hours' <= claim_at
      then 'retry_window_expired' else 'attempts_exhausted' end
  from expired where j.id = expired.id;

  return query
  with ready as (
    select j.id
    from app.receipt_email_jobs j
    where ((j.state = 'pending' and j.next_attempt_at <= claim_at)
        or (j.state = 'leased' and j.lease_expires_at <= claim_at))
      and j.attempts < 6
      and (j.first_attempt_at is null or j.first_attempt_at + interval '23 hours' > claim_at)
    order by j.next_attempt_at, j.id
    limit least(p_limit, 10) for update skip locked
  )
  update app.receipt_email_jobs j
  set state = 'leased', attempts = j.attempts + 1,
    first_attempt_at = coalesce(j.first_attempt_at, claim_at),
    claim_token = gen_random_uuid(),
    lease_expires_at = least(claim_at + interval '5 minutes',
      coalesce(j.first_attempt_at, claim_at) + interval '23 hours')
  from ready where j.id = ready.id
  returning j.id, j.claim_token;
end
$function$;
--> statement-breakpoint
create function mail.prepare_receipt_email(
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
  select guest.email into live_email from app.donors guest
  where guest.institute_id = job.institute_id and guest.id = job.donor_id
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

    if not exists (
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
create function mail.finish_receipt_email(
  p_job_id uuid, p_claim_token uuid, p_result text, p_retry_after_seconds integer default null
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  job app.receipt_email_jobs%rowtype;
  finished timestamptz := clock_timestamp();
  retry_at timestamptz;
  error_code text := p_result;
  backoff_seconds constant integer[] := array[120, 900, 3600, 10800, 21600];
begin
  if p_result is null or p_result not in ('sent', 'rate_limited', 'provider_unavailable', 'network_error',
      'configuration', 'provider_rejected', 'recipient_changed', 'donation_unavailable', 'payload_changed')
  then return 'invalid'; end if;

  select j.* into job from app.receipt_email_jobs j
  where j.id = p_job_id and j.state = 'leased' and j.claim_token = p_claim_token
    and j.lease_expires_at > finished
  for update;
  if not found then return 'stale'; end if;

  if p_result = 'sent' then
    if job.payload_hash is null then return 'invalid'; end if;
    update app.receipt_email_jobs j
    set state = 'sent', claim_token = null, lease_expires_at = null, finished_at = finished,
      to_email = null, snapshot = null, last_error = null
    where j.id = job.id;
    return 'sent';
  end if;

  if p_result in ('rate_limited', 'provider_unavailable', 'network_error', 'configuration') then
    if job.attempts >= 6 then
      error_code := 'attempts_exhausted';
    else
      retry_at := finished + make_interval(secs => greatest(backoff_seconds[job.attempts],
        least(coalesce(p_retry_after_seconds, 0), 28800)));
      if retry_at < job.first_attempt_at + interval '23 hours' then
        update app.receipt_email_jobs j
        set state = 'pending', claim_token = null, lease_expires_at = null, next_attempt_at = retry_at,
          last_error = p_result
        where j.id = job.id;
        return 'retry';
      end if;
      error_code := 'retry_window_expired';
    end if;
  end if;

  update app.receipt_email_jobs j
  set state = 'failed', claim_token = null, lease_expires_at = null, finished_at = finished,
    to_email = null, snapshot = null, last_error = error_code
  where j.id = job.id;
  return 'failed';
end
$function$;
--> statement-breakpoint
revoke all on function app.enqueue_receipt_email(),
  mail.claim_receipt_emails(integer), mail.prepare_receipt_email(uuid, uuid, text, text),
  mail.finish_receipt_email(uuid, uuid, text, integer) from public;
grant execute on function mail.claim_receipt_emails(integer), mail.prepare_receipt_email(uuid, uuid, text, text),
  mail.finish_receipt_email(uuid, uuid, text, integer) to tazkiyah_mail;
--> statement-breakpoint
RESET ROLE;
