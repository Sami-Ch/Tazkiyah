begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('16000000-0000-4000-8000-000000000001', 'auth-audit-fixture');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('16000000-0000-4000-8000-000000000011', '16000000-0000-4000-8000-000000000001',
    'audit-admin@example.test', 'Audit Admin', 'active', true, false),
  ('16000000-0000-4000-8000-000000000012', '16000000-0000-4000-8000-000000000001',
    'audit-teacher@example.test', 'Audit Teacher', 'invited', false, true);
insert into app.user_roles (institute_id, user_id, role) values
  ('16000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000011', 'admin');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('16000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000011', 'secret', 'codes', true);

reset role;
set local role tazkiyah_auth;
select set_config('app.institute_id', '16000000-0000-4000-8000-000000000001', true),
  set_config('app.request_id', 'auth-audit-test', true);
insert into identity.sessions (user_id, token, expires_at)
values ('16000000-0000-4000-8000-000000000011', 'audit-session', now() + interval '1 hour');
update identity.two_factor set failed_verification_count = 1
where user_id = '16000000-0000-4000-8000-000000000011';
update identity.two_factor set failed_verification_count = 0
where user_id = '16000000-0000-4000-8000-000000000011';
select set_config('app.user_id', '16000000-0000-4000-8000-000000000011', true);
-- Credentials are written only by definer functions, which run as the owner.
reset role;
set local role tazkiyah_schema_owner;
insert into identity.accounts (user_id, provider_id, account_id, password)
values ('16000000-0000-4000-8000-000000000012', 'credential', '16000000-0000-4000-8000-000000000012',
  repeat('h', 64));

insert into app.user_roles (institute_id, user_id, role) values
  ('16000000-0000-4000-8000-000000000001', '16000000-0000-4000-8000-000000000012', 'teacher');
delete from app.user_roles where user_id = '16000000-0000-4000-8000-000000000012';

do $test$
declare
  tenant constant uuid := '16000000-0000-4000-8000-000000000001';
  admin constant uuid := '16000000-0000-4000-8000-000000000011';
  teacher constant uuid := '16000000-0000-4000-8000-000000000012';
begin
  assert (select count(*) from app.audit_log where institute_id = tenant and action = 'auth.signed_in'
    and actor_user_id = admin and actor_roles = array['admin'] and entity_id = admin::text
    and request_id = 'auth-audit-test') = 1, 'Sign-in was not audited once';
  assert (select count(*) from app.audit_log where institute_id = tenant
    and action = 'auth.two_factor_failed' and actor_user_id = admin) = 1,
    'A failed two-factor code was not audited exactly once';
  assert (select count(*) from app.audit_log where institute_id = tenant
    and action = 'auth.account_created' and actor_user_id = admin and entity_id = teacher::text) = 1,
    'Account creation was not audited';
  assert (select count(*) from app.audit_log where institute_id = tenant
    and entity_table = 'user_roles' and actor_user_id = admin) = 2,
    'Granting and removing a role were not both audited';
  assert not exists (
    select from app.audit_log a where a.institute_id = tenant
      and (a::text like '%@example.test%' or a::text like '%audit-session%' or a::text like '%hhhh%')
  ), 'An auth audit row holds an email, token or password hash';
end
$test$;

rollback;
