SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Staff-created student accounts with a starting password and a forced change
-- at first sign-in (03 §6.2, 07 §4.1, P0-E5-T03). Classes, personas and the
-- orphan flag join this in P3-E1-T41 (app.create_student_account).

-- True when the session belongs to the current user, is live, and the user is
-- active with no pending password change. Admins and finance officers also
-- need a two-factor-verified session that was used in the last 30 minutes.
create function identity.staff_session_ok(p_session_id uuid) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
return exists (
  select 1 from identity.sessions s
  join app.users u on (u.institute_id, u.id) = (s.institute_id, s.user_id)
  where s.id = p_session_id and s.institute_id = app.current_institute_id()
    and s.user_id = app.current_user_id() and s.expires_at > now()
    and u.status = 'active' and not u.must_change_password
    and app.is_staff()
    and (
      not (app.has_role('admin') or app.has_role('finance_officer'))
      or (s.two_factor_verified_at is not null and s.updated_at > now() - interval '30 minutes'
        and u.two_factor_enabled)
    )
);
--> statement-breakpoint
-- Generates the username, for example maa-2026-0142: the institute's receipt
-- prefix, the year and a number. It holds no part of the student's name
-- (REQ-CHS-001, D-119).
create function identity.create_student_account(
  session_id uuid, student_name text, password_hash text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  prefix text;
  stem text;
  next_number integer;
  student_id uuid;
  student_username text;
begin
  if not identity.staff_session_ok(session_id)
    or not (app.has_role('admin') or app.has_role('teacher')) then
    return null;
  end if;
  if student_name is null or length(btrim(student_name)) not between 1 and 120
    or password_hash is null or length(password_hash) not between 64 and 255 then
    raise exception 'Invalid student account' using errcode = '22023';
  end if;

  -- Lock the settings row so two staff members never get the same number.
  select lower(s.receipt_prefix) into prefix from app.institute_settings s
  where s.institute_id = tenant for update;
  if prefix is null then
    raise exception 'Institute settings are missing' using errcode = '55000';
  end if;
  stem := prefix || '-' || extract(year from now())::text || '-';
  select coalesce(max(substr(u.username, length(stem) + 1)::integer), 0) + 1 into next_number
  from app.users u
  where u.institute_id = tenant and u.username like stem || '%'
    and substr(u.username, length(stem) + 1) ~ '^[0-9]+$';
  student_username := stem || lpad(next_number::text, 4, '0');

  insert into app.users (institute_id, full_name, username, status, must_change_password)
  values (tenant, btrim(student_name), student_username, 'active', true)
  returning id into student_id;
  insert into app.user_roles (institute_id, user_id, role, granted_by)
  values (tenant, student_id, 'student', actor);
  insert into identity.accounts (institute_id, user_id, provider_id, account_id, password)
  values (tenant, student_id, 'credential', student_id::text, password_hash);
  return student_username;
end
$function$;
--> statement-breakpoint
-- The student replaces the starting password once, from the session that the
-- starting password opened. Other sessions end.
create function identity.set_first_password(p_session_id uuid, password_hash text)
returns boolean
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  student uuid;
begin
  if password_hash is null or length(password_hash) not between 64 and 255 then return false; end if;
  select u.id into student from identity.sessions s
  join app.users u on (u.institute_id, u.id) = (s.institute_id, s.user_id)
  where s.id = p_session_id and s.institute_id = tenant and s.expires_at > now()
    and u.status in ('active', 'left') and u.must_change_password
  for update of u;
  if student is null then return false; end if;

  update identity.accounts set password = password_hash, updated_at = now()
  where institute_id = tenant and user_id = student and provider_id = 'credential';
  if not found then return false; end if;
  update app.users set must_change_password = false, updated_at = now()
  where institute_id = tenant and id = student;
  delete from identity.sessions
  where institute_id = tenant and user_id = student and id <> p_session_id;
  insert into app.audit_log (institute_id, actor_user_id, actor_kind, action, entity_table, entity_id)
  values (tenant, student, 'user', 'auth.first_password_set', 'users', student::text);
  return true;
end
$function$;
--> statement-breakpoint
-- True while the user must replace a starting password and may open nothing
-- else.
create function identity.must_change_password(p_user_id uuid) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
return exists (
  select 1 from app.users u
  where u.institute_id = app.current_institute_id() and u.id = p_user_id and u.must_change_password
);
--> statement-breakpoint
revoke all on function identity.staff_session_ok(uuid),
  identity.create_student_account(uuid, text, text),
  identity.set_first_password(uuid, text),
  identity.must_change_password(uuid) from public;
grant execute on function identity.create_student_account(uuid, text, text),
  identity.set_first_password(uuid, text),
  identity.must_change_password(uuid) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
