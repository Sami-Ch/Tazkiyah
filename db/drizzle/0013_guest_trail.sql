SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."trail_links" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"donor_id" uuid NOT NULL,
	"token_hash" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_by" uuid NOT NULL,
	"revoked_at" timestamp with time zone,
	"revoked_by" uuid,
	CONSTRAINT "trail_links_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "trail_links_token_hash_unique" UNIQUE("token_hash"),
	CONSTRAINT "trail_links_hash_check" CHECK (token_hash ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "trail_links_revocation_check" CHECK ((revoked_at is null) = (revoked_by is null))
);
--> statement-breakpoint
ALTER TABLE "app"."trail_links" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD CONSTRAINT "trail_links_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD CONSTRAINT "trail_links_institute_id_donor_id_donors_institute_id_id_fk" FOREIGN KEY ("institute_id","donor_id") REFERENCES "app"."donors"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD CONSTRAINT "trail_links_institute_id_created_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","created_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD CONSTRAINT "trail_links_institute_id_revoked_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","revoked_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "trail_links_one_active" ON "app"."trail_links" USING btree ("institute_id","donor_id") WHERE revoked_at is null;--> statement-breakpoint
CREATE INDEX "donations_guest_trail_index" ON "app"."donations" USING btree ("institute_id","donor_id","recorded_at" DESC NULLS LAST,"id" DESC NULLS LAST) WHERE donor_id is not null;--> statement-breakpoint
CREATE INDEX "trail_events_donation_index" ON "app"."trail_events" USING btree ("institute_id","donation_id","id");--> statement-breakpoint
CREATE POLICY "iso" ON "app"."trail_links" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));
--> statement-breakpoint
revoke all on app.trail_links from public, tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
create function identity.issue_trail_link(
  p_session_id uuid, p_receipt_number text, p_donor_email text, p_token_hash text
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
    or receipt is null or length(receipt) not between 1 and 120
    or confirmed_email is null or length(confirmed_email) not between 3 and 254
    or confirmed_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
  then return 'invalid'; end if;

  -- Serialize mutations for this donor even when requests use different receipts.
  select guest.id into target_donor
  from app.donations d
  join app.donors guest on (guest.institute_id, guest.id) = (d.institute_id, d.donor_id)
  where d.institute_id = tenant and d.receipt_number = receipt and d.status = 'recorded'
    and guest.email = confirmed_email
  for update of guest;
  if not found then return 'unavailable'; end if;

  changed_at := clock_timestamp();
  update app.trail_links set revoked_at = changed_at, revoked_by = actor
  where institute_id = tenant and donor_id = target_donor and revoked_at is null;
  insert into app.trail_links (institute_id, donor_id, token_hash, created_at, created_by)
  values (tenant, target_donor, p_token_hash, changed_at, actor)
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
create function identity.revoke_trail_link(p_session_id uuid, p_receipt_number text)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  target_donor uuid;
  revoked_link uuid;
begin
  if not identity.is_staff_admin_session(p_session_id) then return 'denied'; end if;

  -- A reversed receipt can still identify a donor whose existing link needs revocation.
  select guest.id into target_donor
  from app.donations d
  join app.donors guest on (guest.institute_id, guest.id) = (d.institute_id, d.donor_id)
  where d.institute_id = tenant and d.receipt_number = upper(btrim(p_receipt_number))
  for update of guest;
  if not found then return 'unavailable'; end if;

  update app.trail_links set revoked_at = clock_timestamp(), revoked_by = actor
  where institute_id = tenant and donor_id = target_donor and revoked_at is null
  returning id into revoked_link;
  if found then
    insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
      action, entity_table, entity_id, request_id)
    select tenant, actor, 'user', array_agg(r.role order by r.role),
      'trail_links.revoked', 'trail_links', revoked_link::text,
      nullif(current_setting('app.request_id', true), '')
    from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  end if;
  return 'revoked';
end
$function$;
--> statement-breakpoint
create function identity.read_guest_trail(
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
      'credited_on', to_char(e.credited_on, 'YYYY-MM-DD'),
      'amount_paisa', e.amount_paisa::text,
      'cause_title', c.title
    ) order by e.id) as events
    from app.trail_events e
    left join app.causes c on (c.institute_id, c.id) = (e.institute_id, e.cause_id)
    where e.institute_id = d.institute_id and e.donation_id = d.id
      and e.event_type in ('received', 'allocated')
  ) trail
  order by d.recorded_at desc, d.id desc
$function$;
--> statement-breakpoint
revoke all on function identity.issue_trail_link(uuid, text, text, text),
  identity.revoke_trail_link(uuid, text), identity.read_guest_trail(text, timestamptz, uuid)
from public;
grant execute on function identity.issue_trail_link(uuid, text, text, text),
  identity.revoke_trail_link(uuid, text), identity.read_guest_trail(text, timestamptz, uuid)
to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
