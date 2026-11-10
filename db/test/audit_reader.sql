-- app.audit_entries and identity.read_audit_log (P1-E5-T40): staff names only,
-- redaction kept, actor and record filters, and the filter indexes.
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('99000000-0000-4000-8000-000000000001', 'audit-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('99000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'AUD');
insert into app.users (id, institute_id, email, username, full_name, status, two_factor_enabled, must_change_password) values
  ('99000000-0000-4000-8000-000000000011', '99000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Moazam Admin', 'active', true, false),
  ('99000000-0000-4000-8000-000000000012', '99000000-0000-4000-8000-000000000001', null, 'aud-2026-0001', 'Real Student Name', 'active', false, false),
  ('99000000-0000-4000-8000-000000000013', '99000000-0000-4000-8000-000000000001', 'giver@example.test', null, 'Real Donor Name', 'active', false, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000011', 'admin'),
  ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000012', 'student'),
  ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000013', 'donor');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
values ('99000000-0000-4000-8000-000000000001', '99000000-0000-4000-8000-000000000011', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at)
values ('99000000-0000-4000-8000-000000000021', '99000000-0000-4000-8000-000000000001',
  '99000000-0000-4000-8000-000000000011', 'audit-admin', now() + interval '1 hour', now(), now());
insert into app.audit_log (institute_id, occurred_at, actor_user_id, actor_kind, actor_roles, action,
  entity_table, entity_id, changes, reason)
values
  ('99000000-0000-4000-8000-000000000001', now() - interval '5 minutes', '99000000-0000-4000-8000-000000000011',
    'user', array['admin'], 'causes.update', 'causes', '99000000-0000-4000-8000-000000000041',
    '{"status":{"old":"draft","new":"active"},"title":{"old":"Secret old","new":"Secret new"}}', null),
  ('99000000-0000-4000-8000-000000000001', now() - interval '4 minutes', '99000000-0000-4000-8000-000000000012',
    'user', array['student'], 'users.update', 'users', '99000000-0000-4000-8000-000000000012', '{}', null),
  ('99000000-0000-4000-8000-000000000001', now() - interval '3 minutes', '99000000-0000-4000-8000-000000000013',
    'user', array['donor'], 'donors.update', 'donors', '99000000-0000-4000-8000-000000000051', '{}', null),
  ('99000000-0000-4000-8000-000000000001', now() - interval '2 minutes', null,
    'job', array[]::text[], 'retention.run', 'audit_log', 'run', '{}', null),
  ('99000000-0000-4000-8000-000000000001', now() - interval '1 minute', '99000000-0000-4000-8000-000000000011',
    'user', array['admin'], 'donations.reversed', 'donations', '99000000-0000-4000-8000-000000000061',
    '{"category":{"old":null,"new":"recorded_twice"}}', 'Same line entered twice');

reset role;
set local role tazkiyah_auth;
do $test$
declare
  admin_session constant uuid := '99000000-0000-4000-8000-000000000021';
  entry record;
begin
  assert not has_table_privilege('tazkiyah_auth', 'app.audit_entries', 'SELECT');
  assert not has_table_privilege('tazkiyah_app', 'app.audit_entries', 'SELECT');
  perform set_config('app.institute_id', '99000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '99000000-0000-4000-8000-000000000011', true);
  assert (select count(*) from identity.read_audit_log(admin_session, 1, null, null, 0)) = 5;

  -- Names only for staff actors.
  assert (select array_agg(coalesce(actor_name, '-') order by occurred_at)
    from identity.read_audit_log(admin_session, 1, null, null, 0))
    = array['Moazam Admin', '-', '-', '-', 'Moazam Admin'];
  assert not exists (select from identity.read_audit_log(admin_session, 1, null, null, 0) t
    where t::text ~ '(Real Student Name|Real Donor Name|Secret)');

  -- Redaction kept: status is shown, the title change is only counted.
  select * into strict entry from identity.read_audit_log(admin_session, 1, 'causes.update', null, 0);
  assert entry.changes = '{"status":{"old":"draft","new":"active"}}' and entry.hidden_fields = 1;

  -- Reason, actor filter and record filter.
  select * into strict entry from identity.read_audit_log(admin_session, 1, 'donations.reversed', null, 0);
  assert entry.has_reason and entry.hidden_fields = 0
    and entry.changes = '{"category":{"old":null,"new":"recorded_twice"}}';
  assert not exists (select from identity.read_audit_log(admin_session, 1, null, null, 0) t
    where t::text like '%Same line%');
  assert (select count(*) from identity.read_audit_log(admin_session, 1, null, null, 0) where has_reason) = 1;
  assert (select count(*) from identity.read_audit_log(admin_session, null, null, null, 0,
    '99000000-0000-4000-8000-000000000011')) = 2;
  assert (select count(*) from identity.read_audit_log(admin_session, null, null, 'causes', 0, null,
    '99000000-0000-4000-8000-000000000041')) = 1;

  -- Not an admin session, no rows.
  perform set_config('app.user_id', '99000000-0000-4000-8000-000000000012', true);
  assert not exists (select from identity.read_audit_log(admin_session, null, null, null, 0));
end
$test$;

-- The filters use the 04 §13.1 indexes.
reset role;
set local role tazkiyah_schema_owner;
insert into app.audit_log (institute_id, occurred_at, actor_user_id, actor_kind, actor_roles, action,
  entity_table, entity_id)
select '99000000-0000-4000-8000-000000000001', now() - make_interval(mins => n),
  case when n % 50 = 0 then '99000000-0000-4000-8000-000000000011'::uuid end,
  case when n % 50 = 0 then 'user' else 'job' end, '{}', 'causes.update', 'causes', gen_random_uuid()::text
from generate_series(1, 3000) n;
analyze app.audit_log;
set local enable_seqscan = off;
do $test$
declare
  line text;
  plan text := '';
begin
  for line in execute $q$explain select id from app.audit_log
    where institute_id = '99000000-0000-4000-8000-000000000001' and entity_table = 'causes'
      and entity_id = '99000000-0000-4000-8000-000000000041'$q$ loop
    plan := plan || line || E'\n';
  end loop;
  assert plan ~ 'audit_log_entity', 'Record filter does not use its index: ' || plan;
  plan := '';
  for line in execute $q$explain select id from app.audit_log
    where institute_id = '99000000-0000-4000-8000-000000000001'
      and actor_user_id = '99000000-0000-4000-8000-000000000011' order by occurred_at desc limit 50$q$ loop
    plan := plan || line || E'\n';
  end loop;
  assert plan ~ 'audit_log_actor', 'Actor filter does not use its index: ' || plan;
end
$test$;
