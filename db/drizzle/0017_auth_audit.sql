SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Sign-ins, failed two-factor codes and new credentials go to the audit log
-- with IDs only (03 §6.4, 05 §9). Staff role and account changes are already
-- written by app.audit_row_change.
create function identity.audit_auth_event() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  event text;
  actor uuid;
begin
  if new.institute_id is distinct from tenant then return null; end if;
  if tg_table_name = 'sessions' then
    event := 'auth.signed_in';
    actor := new.user_id;
  elsif tg_table_name = 'two_factor' then
    if coalesce(new.failed_verification_count, 0) <= coalesce(old.failed_verification_count, 0) then
      return null;
    end if;
    event := 'auth.two_factor_failed';
    actor := new.user_id;
  else
    event := 'auth.account_created';
    actor := app.current_user_id();
  end if;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, request_id)
  values (tenant, actor, case when actor is null then 'system' else 'user' end,
    array(select r.role from app.user_roles r
      where r.institute_id = tenant and r.user_id = actor order by r.role),
    event, 'users', new.user_id::text, nullif(current_setting('app.request_id', true), ''));
  return null;
end
$function$;
--> statement-breakpoint
create trigger audit_sign_in after insert on identity.sessions
for each row execute function identity.audit_auth_event();
--> statement-breakpoint
create trigger audit_two_factor_failure after update of failed_verification_count on identity.two_factor
for each row execute function identity.audit_auth_event();
--> statement-breakpoint
create trigger audit_account_created after insert on identity.accounts
for each row execute function identity.audit_auth_event();
--> statement-breakpoint
revoke all on function identity.audit_auth_event() from public;
--> statement-breakpoint
RESET ROLE;
