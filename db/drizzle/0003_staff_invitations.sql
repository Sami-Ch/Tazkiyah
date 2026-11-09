SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "identity"."staff_invitations" (
	"institute_id" uuid DEFAULT app.current_institute_id() NOT NULL,
	"user_id" uuid NOT NULL,
	"token_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	CONSTRAINT "staff_invitations_institute_id_user_id_pk" PRIMARY KEY("institute_id","user_id"),
	CONSTRAINT "staff_invitations_institute_id_token_hash_unique" UNIQUE("institute_id","token_hash")
);
--> statement-breakpoint
ALTER TABLE "identity"."staff_invitations" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "identity"."staff_invitations" ADD CONSTRAINT "staff_invitations_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity"."staff_invitations" ADD CONSTRAINT "staff_invitations_institute_id_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE POLICY "iso" ON "identity"."staff_invitations" AS RESTRICTIVE FOR ALL TO "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "auth_access" ON "identity"."staff_invitations" AS PERMISSIVE FOR ALL TO "tazkiyah_auth" USING (true) WITH CHECK (true);
--> statement-breakpoint
grant select on identity.staff_invitations to tazkiyah_auth;
grant execute on function app.is_staff() to tazkiyah_auth;
--> statement-breakpoint
create function identity.issue_staff_invitation(
  session_id uuid, staff_name text, staff_email text, staff_role text,
  staff_language text, invitation_hash text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  staff_id uuid;
  outcome text := 'created';
begin
  if not app.has_role('admin') or not exists (
    select 1 from identity.sessions s
    join app.users u on (u.institute_id, u.id) = (s.institute_id, s.user_id)
    join identity.two_factor f on (f.institute_id, f.user_id) = (s.institute_id, s.user_id)
    where s.id = session_id and s.institute_id = tenant and s.user_id = actor
      and s.expires_at > now() and s.updated_at > now() - interval '30 minutes'
      and s.two_factor_verified_at is not null
      and u.status = 'active' and u.two_factor_enabled and f.verified
      and not u.must_change_password
  ) then
    return 'denied';
  end if;
  if staff_name is null or length(btrim(staff_name)) not between 1 and 120
    or staff_email is null or length(staff_email) > 254
    or staff_email <> lower(btrim(staff_email))
    or staff_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    or staff_role is null or staff_role not in ('teacher', 'editor', 'finance_officer')
    or staff_language is null or staff_language not in ('en', 'ur')
    or invitation_hash is null or invitation_hash !~ '^[a-f0-9]{64}$'
  then
    return 'invalid';
  end if;

  insert into app.users (institute_id, full_name, email, preferred_language)
  values (tenant, btrim(staff_name), staff_email, staff_language)
  on conflict do nothing
  returning id into staff_id;

  if staff_id is null then
    select u.id into staff_id from app.users u
    join identity.staff_invitations i on (i.institute_id, i.user_id) = (u.institute_id, u.id)
    where u.institute_id = tenant and lower(u.email) = staff_email and u.status = 'invited'
      and exists (
        select 1 from app.user_roles r
        where r.institute_id = tenant and r.user_id = u.id and r.role = staff_role
      )
      and not exists (
        select 1 from app.user_roles r
        where r.institute_id = tenant and r.user_id = u.id and r.role <> staff_role
      )
    for update of u;
    if staff_id is null then return 'conflict'; end if;
    update app.users
    set full_name = btrim(staff_name), preferred_language = staff_language, updated_at = now()
    where institute_id = tenant and id = staff_id;
    outcome := 'reissued';
  else
    insert into app.user_roles (institute_id, user_id, role, granted_by)
    values (tenant, staff_id, staff_role, actor);
  end if;

  insert into identity.staff_invitations (institute_id, user_id, token_hash, expires_at)
  values (tenant, staff_id, invitation_hash, now() + interval '24 hours')
  on conflict (institute_id, user_id) do update
    set token_hash = excluded.token_hash, expires_at = excluded.expires_at;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles, action, entity_table, entity_id)
  values (tenant, actor, 'user', array['admin'], 'staff.invitation.' || outcome, 'users', staff_id::text);
  return outcome;
end
$function$;
--> statement-breakpoint
create function identity.accept_staff_invitation(invitation_hash text, password_hash text)
returns boolean
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  staff_id uuid;
begin
  if password_hash is null or length(password_hash) not between 64 and 255 then return false; end if;

  -- Lock the user first, in the same order as invitation reissue.
  select u.id into staff_id from identity.staff_invitations i
  join app.users u on (u.institute_id, u.id) = (i.institute_id, i.user_id)
  where i.institute_id = tenant and i.token_hash = invitation_hash
    and i.expires_at > now() and u.status = 'invited'
    and exists (
      select 1 from app.user_roles r where r.institute_id = tenant and r.user_id = u.id
        and r.role in ('teacher', 'editor', 'finance_officer')
    )
  for update of u;
  if staff_id is null then return false; end if;

  delete from identity.staff_invitations
  where institute_id = tenant and user_id = staff_id
    and token_hash = invitation_hash and expires_at > clock_timestamp();
  if not found then return false; end if;

  insert into identity.accounts (institute_id, user_id, provider_id, account_id, password)
  values (tenant, staff_id, 'credential', staff_id::text, password_hash);
  update app.users
  set status = 'active', must_change_password = false, onboarded_at = now(), updated_at = now()
  where institute_id = tenant and id = staff_id;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, action, entity_table, entity_id)
  values (tenant, staff_id, 'user', 'staff.invitation.accepted', 'users', staff_id::text);
  return true;
end
$function$;
--> statement-breakpoint
revoke all on function identity.issue_staff_invitation(uuid, text, text, text, text, text) from public;
revoke all on function identity.accept_staff_invitation(text, text) from public;
grant execute on function identity.issue_staff_invitation(uuid, text, text, text, text, text) to tazkiyah_auth;
grant execute on function identity.accept_staff_invitation(text, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
