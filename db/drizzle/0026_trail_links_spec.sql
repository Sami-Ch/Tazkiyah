SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "app"."trail_links" DROP CONSTRAINT "trail_links_revocation_check";--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD COLUMN "token_hint" text;--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD COLUMN "expires_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD COLUMN "revoke_reason" text;--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD COLUMN "last_used_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD CONSTRAINT "trail_links_hint_check" CHECK (token_hint is null or token_hint ~ '^[A-Za-z0-9_-]{4}$');--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD CONSTRAINT "trail_links_expiry_check" CHECK (expires_at is null or expires_at > created_at);--> statement-breakpoint
ALTER TABLE "app"."trail_links" ADD CONSTRAINT "trail_links_revocation_check" CHECK ((revoked_at is null) = (revoked_by is null) and (revoke_reason is null or (revoked_at is not null and length(revoke_reason) between 1 and 200 and revoke_reason !~ '[[:cntrl:]]')));--> statement-breakpoint
-- The current user's donor rows plus the trail-token donor (04 §6.2). The
-- token donor counts only while that donor holds a live link, so a revoked
-- link stops working inside the same transaction.
create function app.my_donor_ids() returns setof uuid
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select d.id from app.donors d
  where d.institute_id = app.current_institute_id() and d.user_id = app.current_user_id()
  union
  select l.donor_id from app.trail_links l
  where l.institute_id = app.current_institute_id() and l.donor_id = app.current_trail_donor_id()
    and l.revoked_at is null and (l.expires_at is null or l.expires_at > now())
$function$;
--> statement-breakpoint
revoke all on function app.my_donor_ids() from public;
--> statement-breakpoint
grant execute on function app.my_donor_ids() to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
CREATE POLICY "trail_links_own_read" ON "app"."trail_links" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (donor_id in (select app.my_donor_ids()) or (select app.has_role('admin')) or (select app.has_role('finance_officer')));
--> statement-breakpoint
-- Donors and finance staff read link metadata, never the hash (§6.4).
grant select (id, institute_id, donor_id, token_hint, created_at, expires_at, revoked_at,
  revoke_reason, last_used_at) on app.trail_links to tazkiyah_app;
--> statement-breakpoint
-- A link changes only by being revoked, once, and by its last use moving
-- forward (§8.6, REQ-SEC-004). Revocation is never cleared.
create function app.trail_links_guard() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if to_jsonb(new) - array['revoked_at', 'revoked_by', 'revoke_reason', 'last_used_at']
    is distinct from to_jsonb(old) - array['revoked_at', 'revoked_by', 'revoke_reason', 'last_used_at']
    or (old.revoked_at is not null and (new.revoked_at, new.revoked_by, new.revoke_reason)
      is distinct from (old.revoked_at, old.revoked_by, old.revoke_reason))
    or new.last_used_at < old.last_used_at or (old.last_used_at is not null and new.last_used_at is null)
  then
    raise exception 'trail link % can only be revoked once or marked as used', old.id
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger trail_links_guard before update on app.trail_links
for each row execute function app.trail_links_guard();
--> statement-breakpoint
-- Resolve a guest token (§8.6): hash it, find a live link in this institute
-- and set app.trail_donor_id for the transaction. Anything else clears it and
-- returns null. Last use is written at most once an hour.
create function app.use_trail_token(token text) returns uuid
language plpgsql volatile security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  link record;
begin
  perform set_config('app.trail_donor_id', '', true);
  if token is null or token !~ '^[A-Za-z0-9_-]{43}$' then return null; end if;
  select l.id, l.donor_id, l.last_used_at into link
  from app.trail_links l
  join app.institutes i on i.id = l.institute_id and i.status = 'active' and i.kind = 'institute'
  where l.institute_id = app.current_institute_id()
    and l.token_hash = encode(sha256(convert_to(token, 'UTF8')), 'hex')
    and l.revoked_at is null and (l.expires_at is null or l.expires_at > now());
  if not found then return null; end if;
  if link.last_used_at is null or link.last_used_at < now() - interval '1 hour' then
    update app.trail_links set last_used_at = now()
    where institute_id = app.current_institute_id() and id = link.id;
  end if;
  perform set_config('app.trail_donor_id', link.donor_id::text, true);
  return link.donor_id;
end
$function$;
--> statement-breakpoint
revoke all on function app.use_trail_token(text) from public;
--> statement-breakpoint
grant execute on function app.use_trail_token(text) to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
-- Issue and revoke keep their two-factor admin check (06 §11.2) and gain the
-- token hint and a revocation reason.
drop function identity.issue_trail_link(uuid, text, text, text);
--> statement-breakpoint
drop function identity.revoke_trail_link(uuid, text);
--> statement-breakpoint
create function identity.issue_trail_link(
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
    and guest.email = confirmed_email
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
create function identity.revoke_trail_link(
  p_session_id uuid, p_receipt_number text, p_reason text default null
) returns text
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
  if p_reason is not null and (length(btrim(p_reason)) not between 1 and 200 or p_reason ~ '[[:cntrl:]]') then
    return 'invalid';
  end if;

  -- A reversed receipt can still identify a donor whose existing link needs revocation.
  select guest.id into target_donor
  from app.donations d
  join app.donors guest on (guest.institute_id, guest.id) = (d.institute_id, d.donor_id)
  where d.institute_id = tenant and d.receipt_number = upper(btrim(p_receipt_number))
  for update of guest;
  if not found then return 'unavailable'; end if;

  update app.trail_links set revoked_at = clock_timestamp(), revoked_by = actor,
    revoke_reason = nullif(btrim(p_reason), '')
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
revoke all on function identity.issue_trail_link(uuid, text, text, text, text),
  identity.revoke_trail_link(uuid, text, text) from public;
--> statement-breakpoint
grant execute on function identity.issue_trail_link(uuid, text, text, text, text),
  identity.revoke_trail_link(uuid, text, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
