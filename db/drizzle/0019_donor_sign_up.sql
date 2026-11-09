SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Donor self sign-up, email verification and password reset (03 §6.2,
-- P0-E5-T02). Better Auth inserts the user as tazkiyah_auth. A row inserted by
-- that role is always an active donor with an unverified email, no username and
-- no two-factor; student and staff accounts are only made by definer functions
-- that check the creator's role.
create function identity.shape_signed_up_user() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.username is not null then
    raise exception 'Self sign-up cannot choose a username' using errcode = '42501';
  end if;
  new.status := 'active';
  new.must_change_password := false;
  new.email_verified := false;
  new.two_factor_enabled := false;
  new.is_orphan := false;
  new.date_of_birth := null;
  new.public_name := null;
  new.public_bio := null;
  new.left_at := null;
  new.onboarded_at := null;
  new.last_login_at := null;
  new.photo_media_id := null;
  new.auth_image := null;
  new.created_at := now();
  new.updated_at := now();
  return new;
end
$function$;
--> statement-breakpoint
create trigger shape_signed_up_user before insert on app.users
for each row when (current_user = 'tazkiyah_auth')
execute function identity.shape_signed_up_user();
--> statement-breakpoint
create function identity.grant_donor_role() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  insert into app.user_roles (institute_id, user_id, role)
  values (new.institute_id, new.id, 'donor');
  return null;
end
$function$;
--> statement-breakpoint
create trigger grant_donor_role after insert on app.users
for each row when (current_user = 'tazkiyah_auth')
execute function identity.grant_donor_role();
--> statement-breakpoint
-- True for an account that holds no role but donor. Only these accounts must
-- verify their email before they can sign in; staff and students are created
-- by someone who already checked who they are.
create function identity.is_donor_only(p_user_id uuid) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
return not exists (
  select 1 from app.user_roles r
  where r.institute_id = app.current_institute_id() and r.user_id = p_user_id
    and r.role <> 'donor'
);
--> statement-breakpoint
create function identity.needs_email_verification(p_user_id uuid) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
return identity.is_donor_only(p_user_id) and exists (
  select 1 from app.users u
  where u.institute_id = app.current_institute_id() and u.id = p_user_id
    and not u.email_verified
);
--> statement-breakpoint
-- Students reset their password through a teacher, never by email (03 §6.2).
create function identity.can_reset_by_email(p_user_id uuid) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
return not exists (
  select 1 from app.user_roles r
  where r.institute_id = app.current_institute_id() and r.user_id = p_user_id
    and r.role = 'student'
);
--> statement-breakpoint
create policy auth_sign_up on app.users as permissive for insert to tazkiyah_auth
with check (status = 'active' and username is null and not email_verified);
--> statement-breakpoint
-- The auth role may only add a password to a donor-only account with no
-- credential yet, which is the account sign-up has just created. Staff get
-- theirs through their invitation, students from a teacher (D-118).
create function identity.can_add_credential(p_user_id uuid) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
return identity.is_donor_only(p_user_id) and not exists (
  select 1 from identity.accounts a
  where a.institute_id = app.current_institute_id() and a.user_id = p_user_id
);
--> statement-breakpoint
create policy auth_credential_insert on identity.accounts as restrictive for insert to tazkiyah_auth
with check (provider_id = 'credential' and account_id = user_id::text
  and identity.can_add_credential(user_id));
--> statement-breakpoint
-- A password changes by email reset only for accounts that may reset by email.
create policy auth_credential_update on identity.accounts as restrictive for update to tazkiyah_auth
using (identity.can_reset_by_email(user_id))
with check (identity.can_reset_by_email(user_id));
--> statement-breakpoint
revoke all on function identity.shape_signed_up_user(), identity.grant_donor_role(),
  identity.is_donor_only(uuid), identity.needs_email_verification(uuid),
  identity.can_reset_by_email(uuid), identity.can_add_credential(uuid) from public;
grant execute on function identity.is_donor_only(uuid), identity.needs_email_verification(uuid),
  identity.can_reset_by_email(uuid), identity.can_add_credential(uuid) to tazkiyah_auth;
grant select (name) on public_api.institute_public to tazkiyah_auth;
-- The localized_text domain check on public_bio runs as the inserting role.
grant execute on function app.valid_localized_text(jsonb) to tazkiyah_auth;
-- Drizzle names every column on insert, so the grant covers the table; the
-- trigger above overwrites every column sign-up must not choose.
grant insert on app.users to tazkiyah_auth;
grant update (email_verified) on app.users to tazkiyah_auth;
grant insert on identity.accounts to tazkiyah_auth;
grant update (password, updated_at) on identity.accounts to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
