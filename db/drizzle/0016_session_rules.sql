SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Session rules per role group (03 §6.5). The strictest group a user holds wins.
create function identity.session_limits(p_user_id uuid, out idle interval, out absolute interval)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select
    case
      when bool_or(r.role in ('admin', 'finance_officer')) then interval '30 minutes'
      when bool_or(r.role in ('teacher', 'editor')) then interval '7 days'
      else interval '30 days'
    end,
    case
      when bool_or(r.role in ('admin', 'finance_officer')) then interval '12 hours'
      when bool_or(r.role in ('teacher', 'editor')) then interval '30 days'
      else interval '90 days'
    end
  from (select null::text as role
    union all
    select role from app.user_roles
    where institute_id = app.current_institute_id() and user_id = p_user_id) as r
$function$;
--> statement-breakpoint
create function identity.cap_session_lifetime() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  new.expires_at := least(new.expires_at, now() + (identity.session_limits(new.user_id)).absolute);
  return new;
end
$function$;
--> statement-breakpoint
create trigger cap_session_lifetime before insert on identity.sessions
for each row execute function identity.cap_session_lifetime();
--> statement-breakpoint
-- Ends a session that is past its lifetime or idle for longer than its role
-- allows, and otherwise records the activity. Returns whether it is still valid.
create function identity.touch_session(p_session_id uuid) returns boolean
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  current identity.sessions%rowtype;
begin
  select * into current from identity.sessions
  where institute_id = tenant and id = p_session_id
  for update;
  if not found then return false; end if;
  if current.expires_at <= now()
    or current.updated_at <= now() - (identity.session_limits(current.user_id)).idle
  then
    delete from identity.sessions where institute_id = tenant and id = p_session_id;
    return false;
  end if;
  update identity.sessions set updated_at = now() where institute_id = tenant and id = p_session_id;
  return true;
end
$function$;
--> statement-breakpoint
revoke all on function identity.session_limits(uuid), identity.cap_session_lifetime(),
  identity.touch_session(uuid) from public;
--> statement-breakpoint
grant execute on function identity.touch_session(uuid) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
