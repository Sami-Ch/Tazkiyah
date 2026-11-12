SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE POLICY "donors_own_read" ON "app"."donors" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (id in (select app.my_donor_ids()));--> statement-breakpoint
CREATE POLICY "donors_own_update" ON "app"."donors" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING (user_id = (select app.current_user_id())) WITH CHECK (user_id = (select app.current_user_id()));
--> statement-breakpoint
-- Claiming guest donations into an account (04 §8.2, 06 §11.3, P2-E5-T40,
-- REQ-DPR-003). Runs for the signed-in donor once their email is confirmed:
-- the guest donor row of this institute with the same email (stored trimmed
-- and lower-case) gets the account, claimed_at and a verified email. Past
-- donations already point at that row. Its live trail links are revoked,
-- because the account replaces them (06 §11.3, D-127). Two donor rows are
-- never merged: an account that already has a donor row gets 'conflict'.
-- Answers: claimed, none, unverified, conflict. Not granted to the runtime
-- roles; the sign-up and account pages call it through their own checks
-- (P2-E5-T01).
create function app.claim_donor_records()
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  account app.users%rowtype;
  guest app.donors%rowtype;
begin
  if tenant is null or actor is null or not app.has_role('donor') then
    raise exception 'claiming needs a signed-in donor account' using errcode = 'insufficient_privilege';
  end if;
  select u.* into account from app.users u where u.institute_id = tenant and u.id = actor;
  if not account.email_verified or account.email is null then
    return 'unverified';
  end if;

  select d.* into guest from app.donors d
  where d.institute_id = tenant and d.email = lower(btrim(account.email)) and d.user_id is null
    and d.erased_at is null
  for update;
  if not found then
    return 'none';
  end if;
  if exists (select from app.donors d where d.institute_id = tenant and d.user_id = actor) then
    return 'conflict';
  end if;

  update app.donors set user_id = actor, claimed_at = now(), email_verified_at = coalesce(email_verified_at, now())
  where institute_id = tenant and id = guest.id;
  update app.trail_links set revoked_at = clock_timestamp(), revoked_by = actor,
    revoke_reason = 'Claimed into an account'
  where institute_id = tenant and donor_id = guest.id and revoked_at is null;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'donors.claimed', 'donors', guest.id::text, nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return 'claimed';
end
$function$;
--> statement-breakpoint
revoke all on function app.claim_donor_records() from public;
--> statement-breakpoint
-- The donor's own row (04 §6.4): the policies above, with grants for reading
-- it and changing only the profile, language and reminder fields
-- (REQ-DPR-005, 06 §10.1). Staff keep reading donors through their definer
-- functions.
grant select on app.donors to tazkiyah_app;
--> statement-breakpoint
grant update (display_name, photo_media_id, profile_links, profile_public, preferred_language,
  reminder_opt_in, reminder_opt_in_at) on app.donors to tazkiyah_app;
--> statement-breakpoint
-- A profile photo is a donor photo upload.
create function app.donors_photo_rule() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.photo_media_id is not null
    and new.photo_media_id is distinct from (case when tg_op = 'UPDATE' then old.photo_media_id end)
    and not exists (select from app.media_assets m
      where m.institute_id = new.institute_id and m.id = new.photo_media_id
        and m.purpose = 'donor_photo' and m.kind = 'image')
  then
    raise exception 'a profile photo must be a donor photo upload' using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger donors_photo_rule before insert or update on app.donors
for each row execute function app.donors_photo_rule();
--> statement-breakpoint
RESET ROLE;
