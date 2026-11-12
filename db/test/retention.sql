begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('15000000-0000-4000-8000-000000000001', 'retention-fixture');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := '15000000-0000-4000-8000-000000000001';
  counts jsonb;
begin
  assert not has_function_privilege('tazkiyah_app', 'app.retention_rules()', 'EXECUTE');

  begin
    perform app.run_retention();
    raise exception 'Retention ran without an institute';
  exception when insufficient_privilege then
    null;
  end;

  perform set_config('app.institute_id', tenant::text, true);
  begin
    perform app.run_retention();
    raise exception 'Retention ran outside a job';
  exception when insufficient_privilege then
    null;
  end;

  perform set_config('app.actor_kind', 'job', true);
  perform set_config('app.request_id', 'retention-test', true);
  counts := app.run_retention();
  assert counts = '{}'::jsonb, 'Retention removed rows with no approved rules';
end
$test$;

set local role tazkiyah_schema_owner;
do $test$
begin
  assert not exists (select from app.retention_rules()), 'Retention rules exist before REQ-SEC-011 is approved';
  assert (
    select count(*) from app.audit_log
    where institute_id = '15000000-0000-4000-8000-000000000001' and action = 'retention.run'
      and actor_kind = 'job' and actor_user_id is null and request_id = 'retention-test'
      and changes = '{"deleted_rows": {"new": {}}}'
  ) = 1, 'Retention did not write exactly one audit row';
end
$test$;

rollback;
