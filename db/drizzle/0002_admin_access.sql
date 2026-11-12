SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "identity"."sessions" ADD COLUMN "two_factor_verified_at" timestamp with time zone;
--> statement-breakpoint
grant execute on function app.has_role(text) to tazkiyah_auth;
--> statement-breakpoint
create function identity.revoke_user_sessions() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_table_schema = 'app' and tg_table_name = 'users' then
    delete from identity.sessions
      where institute_id = new.institute_id and user_id = new.id;
  else
    if tg_op <> 'INSERT' then
      delete from identity.sessions
        where institute_id = old.institute_id and user_id = old.user_id;
    end if;
    if tg_op = 'INSERT' or (
      tg_op = 'UPDATE' and (new.institute_id, new.user_id) is distinct from (old.institute_id, old.user_id)
    ) then
      delete from identity.sessions
        where institute_id = new.institute_id and user_id = new.user_id;
    end if;
  end if;
  return null;
end
$function$;
--> statement-breakpoint
create trigger revoke_sessions_on_role_change
after insert or update or delete on app.user_roles
for each row execute function identity.revoke_user_sessions();
--> statement-breakpoint
create trigger revoke_sessions_on_auth_change
after update of two_factor_enabled, status on app.users
for each row
when (old.two_factor_enabled is distinct from new.two_factor_enabled or old.status is distinct from new.status)
execute function identity.revoke_user_sessions();
--> statement-breakpoint
RESET ROLE;
