begin;
grant tazkiyah_app to current_user;
set local role tazkiyah_schema_owner;
set local plpgsql.check_asserts = on;

insert into app.institutes (id, slug, status) values
  ('10000000-0000-0000-0000-000000000001', 'isolation-test-a', 'active'),
  ('10000000-0000-0000-0000-000000000002', 'isolation-test-b', 'active'),
  ('10000000-0000-0000-0000-000000000003', 'isolation-test-suspended', 'suspended');

insert into app.institute_domains (institute_id, domain, is_primary) values
  ('10000000-0000-0000-0000-000000000001', 'test-a.example', true),
  ('10000000-0000-0000-0000-000000000001', 'alias-a.example', false),
  ('10000000-0000-0000-0000-000000000002', 'test-b.example', true),
  ('10000000-0000-0000-0000-000000000003', 'suspended.example', true);

insert into app.institute_settings (institute_id, name, theme, address, receipt_prefix, contact) values
  ('10000000-0000-0000-0000-000000000001', '{"en":"Institute A","ur":"ادارہ الف"}',
    '{}', '{"en":"A address"}', 'TESTA', '{"email":"public@example.test","internal_note":"private"}'),
  ('10000000-0000-0000-0000-000000000002', '{"en":"Institute B"}',
    '{}', '{"en":"B address"}', 'TESTB', '{}'),
  ('10000000-0000-0000-0000-000000000003', '{"en":"Suspended institute"}',
    '{}', '{"en":"C address"}', 'TESTC', '{}');

update app.institute_settings set enabled_modules = array['student_hub']
where institute_id = '10000000-0000-0000-0000-000000000001';

insert into app.institute_bank_accounts
  (institute_id, label, bank_name, account_title, account_number, is_active, show_on_donate)
values
  ('10000000-0000-0000-0000-000000000001', '{"en":"A public account"}', 'Test bank', 'A', 'TEST-A', true, true),
  ('10000000-0000-0000-0000-000000000001', '{"en":"A inactive account"}', 'Test bank', 'A', 'TEST-INACTIVE', false, true),
  ('10000000-0000-0000-0000-000000000001', '{"en":"A internal account"}', 'Test bank', 'A', 'TEST-INTERNAL', true, default),
  ('10000000-0000-0000-0000-000000000002', '{"en":"B public account"}', 'Test bank', 'B', 'TEST-B', true, true);

do $test$
begin
  assert not app.valid_localized_text('["one"]'::jsonb);
  assert not app.valid_localized_text('{"en":42}'::jsonb);
  assert not app.valid_localized_text('{"ur":"\t"}'::jsonb);

  begin
    update app.institute_settings set name = '{"en":""}';
    raise exception 'Empty translation was accepted';
  exception when check_violation then
    null;
  end;
end
$test$;

set local role tazkiyah_app;

do $test$
declare
  a constant uuid := '10000000-0000-0000-0000-000000000001';
  b constant uuid := '10000000-0000-0000-0000-000000000002';
  suspended constant uuid := '10000000-0000-0000-0000-000000000003';
begin
  assert app.resolve_institute('WWW.TEST-A.EXAMPLE:443') = a;
  assert app.resolve_institute('alias-a.example') = a;
  assert app.resolve_institute('test-b.example') = b;
  assert app.resolve_institute('unknown.example') is null;
  assert app.resolve_institute('suspended.example') is null;
  assert exists (select 1 from app.list_active_institutes() as ids(id) where id = a);
  assert not exists (select 1 from app.list_active_institutes() as ids(id) where id = suspended);
  assert not exists (select 1 from public_api.institute_public);
  assert not app.module_enabled('student_hub');

  perform set_config('app.institute_id', a::text, true);
  assert (select array_agg(institute_id) from public_api.institute_public) = array[a];
  assert (select contact from public_api.institute_public) = '{"email":"public@example.test"}'::jsonb;
  assert (select jsonb_array_length(bank_accounts) from public_api.institute_public) = 1;
  assert (select bank_accounts -> 0 ->> 'account_number' from public_api.institute_public) = 'TEST-A';
  assert app.module_enabled('student_hub');
  assert not app.module_enabled('unrecognized');
  assert exists (select 1 from app.localize('{"en":"Institute A"}', 'ur')
    where text_value = 'Institute A' and is_fallback);
  assert exists (select 1 from app.localize('{"en":"Institute A","ur":"ادارہ الف"}', 'ur')
    where text_value = 'ادارہ الف' and not is_fallback);

  perform set_config('app.institute_id', b::text, true);
  assert (select array_agg(institute_id) from public_api.institute_public) = array[b];
  assert (select bank_accounts -> 0 ->> 'account_number' from public_api.institute_public) = 'TEST-B';
  assert not app.module_enabled('student_hub');

  perform set_config('app.institute_id', suspended::text, true);
  assert not exists (select 1 from public_api.institute_public);

  perform set_config('app.institute_id', a::text, true);
  assert not exists (select 1 from app.institute_settings);
end
$test$;

-- Add broad permissions only inside this rollback-only test. The restrictive
-- policy must still block cross-tenant reads and writes.
set local role tazkiyah_schema_owner;
grant select, update on app.institute_settings to tazkiyah_app;
create policy test_allow on app.institute_settings for all to tazkiyah_app using (true) with check (true);
set local role tazkiyah_app;

do $test$
declare
  a constant uuid := '10000000-0000-0000-0000-000000000001';
  b constant uuid := '10000000-0000-0000-0000-000000000002';
begin
  perform set_config('app.institute_id', a::text, true);
  assert (select array_agg(institute_id) from app.institute_settings) = array[a];
  update app.institute_settings set receipt_prefix = 'WRONG' where institute_id = b;
  assert not found;
  begin
    update app.institute_settings set institute_id = b where institute_id = a;
    raise exception 'RLS allowed reassignment to another institute';
  exception when insufficient_privilege then
    null;
  end;
end
$test$;

rollback;

begin;
grant tazkiyah_app to current_user;
set local role tazkiyah_app;
do $test$
begin
  assert app.current_institute_id() is null;
  assert not exists (select 1 from public_api.institute_public);
end
$test$;
rollback;
