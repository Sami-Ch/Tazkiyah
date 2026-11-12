SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
create function identity.is_staff_admin_session(session_id uuid) returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return app.has_role('admin') and exists (
  select 1 from identity.sessions s
  join app.users u on (u.institute_id, u.id) = (s.institute_id, s.user_id)
  join identity.two_factor f on (f.institute_id, f.user_id) = (s.institute_id, s.user_id)
  where s.id = session_id and s.institute_id = app.current_institute_id()
    and s.user_id = app.current_user_id() and s.expires_at > now()
    and s.updated_at > now() - interval '30 minutes' and s.two_factor_verified_at is not null
    and u.status = 'active' and u.two_factor_enabled and not u.must_change_password and f.verified
);
--> statement-breakpoint
create function identity.list_staff(
  session_id uuid, search_text text, role_filter text, status_filter text, page_offset integer
) returns table (
  id uuid, name text, email text, status text, roles text[], manageable boolean, invitation_expires_at timestamptz
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select u.id, u.full_name, u.email, u.status, staff.roles,
    u.id <> app.current_user_id() and u.id is distinct from settings.principal_user_id
      and u.status in ('active', 'suspended'),
    i.expires_at
  from app.users u
  join app.institute_settings settings on settings.institute_id = u.institute_id
  join lateral (
    select array_agg(r.role order by r.role) as roles from app.user_roles r
    where (r.institute_id, r.user_id) = (u.institute_id, u.id)
      and r.role in ('admin', 'editor', 'finance_officer', 'teacher')
  ) staff on staff.roles is not null
  left join identity.staff_invitations i on (i.institute_id, i.user_id) = (u.institute_id, u.id)
  where identity.is_staff_admin_session(session_id)
    and u.institute_id = app.current_institute_id()
    and (status_filter is null or u.status = status_filter)
    and (role_filter is null or role_filter = any(staff.roles))
    and (
      search_text is null or strpos(lower(u.full_name), lower(search_text)) > 0
      or strpos(lower(coalesce(u.email, '')), lower(search_text)) > 0
    )
  order by lower(u.full_name), u.id
  limit 51 offset greatest(0, least(page_offset, 10000))
$function$;
--> statement-breakpoint
create function identity.update_staff_access(
  session_id uuid, target_id uuid, expected_status text, expected_roles text[],
  next_status text, next_roles text[]
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  target_status text;
  target_roles text[];
begin
  if not identity.is_staff_admin_session(session_id) or target_id = actor then
    return 'denied';
  end if;
  if (next_status is null) = (next_roles is null)
    or (next_status is not null and next_status not in ('active', 'suspended'))
    or (next_roles is not null and (
      cardinality(next_roles) not between 1 and 4
      or array_position(next_roles, null) is not null
      or not next_roles <@ array['admin', 'editor', 'finance_officer', 'teacher']
    ))
  then return 'invalid'; end if;

  -- Acquire the institute lock before touching session rows. Role and status changes can revoke them.
  perform pg_advisory_xact_lock(hashtextextended(tenant::text || ':staff-access', 0));
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;

  select u.status into target_status from app.users u
  join app.institute_settings settings on settings.institute_id = u.institute_id
  where u.institute_id = tenant and u.id = target_id
    and u.id is distinct from settings.principal_user_id
    and u.status in ('active', 'suspended')
  for update of u;
  if not found then return 'denied'; end if;

  select array_agg(r.role order by r.role) into target_roles from app.user_roles r
  where r.institute_id = tenant and r.user_id = target_id
    and r.role in ('admin', 'editor', 'finance_officer', 'teacher');
  if target_roles is null then return 'denied'; end if;
  if expected_status is distinct from target_status or expected_roles is distinct from target_roles then
    return 'stale';
  end if;

  update identity.sessions set updated_at = now()
  where id = session_id and institute_id = tenant and user_id = actor;
  if not found then return 'denied'; end if;

  if next_status is not null then
    update app.users set status = next_status, updated_at = now()
    where institute_id = tenant and id = target_id and status <> next_status;
  else
    delete from app.user_roles
    where institute_id = tenant and user_id = target_id and role = any(target_roles)
      and not role = any(next_roles);

    insert into app.user_roles (institute_id, user_id, role, granted_by)
    select tenant, target_id, role, actor from unnest(next_roles) as selected(role)
    on conflict (institute_id, user_id, role) do nothing;
  end if;

  return 'updated';
end
$function$;
--> statement-breakpoint
revoke all on function identity.is_staff_admin_session(uuid) from public;
revoke all on function identity.list_staff(uuid, text, text, text, integer) from public;
revoke all on function identity.update_staff_access(uuid, uuid, text, text[], text, text[]) from public;
grant execute on function identity.list_staff(uuid, text, text, text, integer) to tazkiyah_auth;
grant execute on function identity.update_staff_access(uuid, uuid, text, text[], text, text[]) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
