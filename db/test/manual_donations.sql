begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('90000000-0000-4000-8000-000000000001', 'manual-fixture-a'),
  ('90000000-0000-4000-8000-000000000002', 'manual-fixture-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values
  ('90000000-0000-4000-8000-000000000001', '{"en":"Institute A"}', '{"en":"A"}', '{}', 'TESTA'),
  ('90000000-0000-4000-8000-000000000002', '{"en":"Institute B"}', '{"en":"B"}', '{}', 'TESTB');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password)
values
  ('90000000-0000-4000-8000-000000000011', '90000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active', true, false),
  ('90000000-0000-4000-8000-000000000012', '90000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active', true, false),
  ('90000000-0000-4000-8000-000000000013', '90000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active', true, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000011', 'finance_officer'),
  ('90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000012', 'editor'),
  ('90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000013', 'admin');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
select u.institute_id, u.id, 'test-secret', 'test-backup', true from app.users u
where u.institute_id = '90000000-0000-4000-8000-000000000001';
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at)
values
  ('90000000-0000-4000-8000-000000000021', '90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000011', 'verified-finance', now() + interval '1 hour', now(), now()),
  ('90000000-0000-4000-8000-000000000022', '90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000011', 'unverified-finance', now() + interval '1 hour', now(), null),
  ('90000000-0000-4000-8000-000000000023', '90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000011', 'stale-finance', now() + interval '1 hour', now() - interval '31 minutes', now()),
  ('90000000-0000-4000-8000-000000000024', '90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000012', 'verified-editor', now() + interval '1 hour', now(), now()),
  ('90000000-0000-4000-8000-000000000025', '90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000013', 'verified-admin', now() + interval '1 hour', now(), now());

insert into app.institute_bank_accounts
  (id, institute_id, label, bank_name, account_title, account_number, for_donation_types, is_active, show_on_donate)
values
  ('90000000-0000-4000-8000-000000000031', '90000000-0000-4000-8000-000000000001', '{"en":"Finance only"}', 'Bank A', 'Account A', 'internal-number', array['general'], true, false),
  ('90000000-0000-4000-8000-000000000032', '90000000-0000-4000-8000-000000000002', '{"en":"Other institute"}', 'Bank B', 'Account B', 'other-institute-number', array['general'], true, true),
  ('90000000-0000-4000-8000-000000000033', '90000000-0000-4000-8000-000000000001', '{"en":"Approved account"}', 'Bank A', 'Account Z', 'public-number', array['general', 'zakat'], true, true),
  ('90000000-0000-4000-8000-000000000034', '90000000-0000-4000-8000-000000000001', '{"en":"Inactive account"}', 'Bank A', 'Account I', 'inactive-number', array['general'], false, true);

insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_paisa, starts_on, ends_on, accepts_zakat, status)
select fixture.id::uuid, fixture.tenant::uuid, fixture.slug, 'campaign', '{"en":"Test"}', '{"en":"Test"}',
  100000, clock.today - 20, clock.today - 5, fixture.zakat, fixture.status
from (values
  ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000001', 'ended-campaign', false, 'active'),
  ('90000000-0000-4000-8000-000000000042', '90000000-0000-4000-8000-000000000001', 'closed-campaign', false, 'closed'),
  ('90000000-0000-4000-8000-000000000043', '90000000-0000-4000-8000-000000000002', 'other-campaign', false, 'active'),
  ('90000000-0000-4000-8000-000000000044', '90000000-0000-4000-8000-000000000001', 'archived-campaign', false, 'archived')
) fixture(id, tenant, slug, zakat, status)
cross join lateral (select (now() at time zone 'Asia/Karachi')::date as today) clock;

reset role;
set local role tazkiyah_auth;
do $test$
declare
  tenant constant uuid := '90000000-0000-4000-8000-000000000001';
  finance constant uuid := '90000000-0000-4000-8000-000000000011';
  session_id constant uuid := '90000000-0000-4000-8000-000000000021';
  operation constant uuid := '90000000-0000-4000-8000-000000000051';
  bank constant uuid := '90000000-0000-4000-8000-000000000031';
  cause constant uuid := '90000000-0000-4000-8000-000000000041';
  today constant date := (now() at time zone 'Asia/Karachi')::date;
  result record;
  options record;
  first_donation uuid;
  first_receipt text;
begin
  assert not has_table_privilege(current_user, 'app.donors', 'SELECT, INSERT, UPDATE, DELETE');
  assert not has_table_privilege(current_user, 'app.donations', 'SELECT, INSERT, UPDATE, DELETE');
  assert not has_table_privilege(current_user, 'app.allocations', 'SELECT, INSERT, UPDATE, DELETE');
  assert not has_table_privilege(current_user, 'app.trail_events', 'SELECT, INSERT, UPDATE, DELETE');
  assert not has_table_privilege(current_user, 'app.receipt_counters', 'SELECT, INSERT, UPDATE, DELETE');
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', finance::text, true);
  assert (select bank_accounts -> 0 ->> 'account_number' from public_api.institute_public) = 'public-number';
  assert (select jsonb_array_length(bank_accounts) from public_api.institute_public) = 1;
  assert not (select allowed from identity.read_manual_donation_options('90000000-0000-4000-8000-000000000022'));
  assert not (select allowed from identity.read_manual_donation_options('90000000-0000-4000-8000-000000000023'));
  assert not (select allowed from identity.read_manual_donation_options('90000000-0000-4000-8000-000000000025'));
  select * into options from identity.read_manual_donation_options(session_id);
  assert options.allowed and jsonb_array_length(options.bank_accounts) = 2 and jsonb_array_length(options.causes) = 1;

  select * into result from identity.record_manual_donation(session_id, operation, bank, 'private-reference',
    today - 10, 1500000, 'general', cause, ' Donor@Example.Test ', 'ur', true, false, false);
  assert result.code = 'recorded';
  first_donation := result.donation_id;
  first_receipt := result.receipt_number;
  assert first_receipt = 'TESTA-' || extract(year from today) || '-00001';
  select * into result from identity.record_manual_donation(session_id, operation, bank, ' private-reference ',
    today - 10, 1500000, 'general', cause, 'donor@example.test', 'ur', true, true, true);
  assert result.code = 'existing' and result.donation_id = first_donation and result.receipt_number = first_receipt;
  select * into result from identity.record_manual_donation(session_id, operation, bank, 'private-reference',
    today - 10, 1500100, 'general', cause, 'donor@example.test', 'ur', true, false, false);
  assert result.code = 'operation_conflict' and result.donation_id is null;

  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'private-reference', today - 10, 1500000, 'general', cause, null, 'en', true, true, true)) = 'bank_reference_conflict';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'similar', today - 10, 1500000, 'general', null, null, 'en', true, false, null)) = 'similar_confirmation_required';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'large', today, 100000100, 'general', null, null, 'en', true, null, false)) = 'large_confirmation_required';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'anonymous', today, 100, 'general', null, null, 'en', null, true, true)) = 'invalid';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'bank-type', today, 100, 'zakat', null, null, 'en', true, true, true)) = 'bank_unavailable';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(),
    '90000000-0000-4000-8000-000000000032', 'other-bank', today, 100, 'general', null, null, 'en', true, true, true)) = 'bank_unavailable';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(),
    '90000000-0000-4000-8000-000000000034', 'inactive-bank', today, 100, 'general', null, null, 'en', true, true, true)) = 'bank_unavailable';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'too-late', today, 100, 'general', cause, null, 'en', true, true, true)) = 'cause_unavailable';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'too-early', today - 21, 100, 'general', cause, null, 'en', true, true, true)) = 'cause_unavailable';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'closed', today - 10, 100, 'general', '90000000-0000-4000-8000-000000000042', null, 'en', true, true, true)) = 'cause_unavailable';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'other-cause', today - 10, 100, 'general', '90000000-0000-4000-8000-000000000043', null, 'en', true, true, true)) = 'cause_unavailable';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'archived', today - 10, 100, 'general', '90000000-0000-4000-8000-000000000044', null, 'en', true, true, true)) = 'cause_unavailable';
  assert (select code from identity.record_manual_donation(session_id, gen_random_uuid(),
    '90000000-0000-4000-8000-000000000033', 'zakat-cause', today - 10, 100, 'zakat', cause, null, 'en', true, true, true)) = 'cause_unavailable';

  perform set_config('app.user_id', '90000000-0000-4000-8000-000000000012', true);
  assert not exists (select from identity.list_manual_donations('90000000-0000-4000-8000-000000000024'));
  assert (select code from identity.record_manual_donation('90000000-0000-4000-8000-000000000024',
    gen_random_uuid(), bank, 'editor', today, 100, 'general', null, null, 'en', true, true, true)) = 'denied';

  perform set_config('app.user_id', '90000000-0000-4000-8000-000000000013', true);
  select * into result from identity.record_manual_donation('90000000-0000-4000-8000-000000000025',
    gen_random_uuid(), bank, 'similar', today - 10, 1500000, 'general', null, null, 'en', true, false, true);
  assert result.code = 'recorded' and result.receipt_number = 'TESTA-' || extract(year from today) || '-00002';
  select * into result from identity.record_manual_donation('90000000-0000-4000-8000-000000000025',
    gen_random_uuid(), bank, 'large', today, 100000100, 'general', null, 'DONOR@example.test', 'en', true, true, false);
  assert result.code = 'recorded' and result.receipt_number = 'TESTA-' || extract(year from today) || '-00003';
  assert (select count(*) from identity.list_manual_donations('90000000-0000-4000-8000-000000000025')) = 3;
  assert (select count(*) from identity.read_audit_log('90000000-0000-4000-8000-000000000025', null,
    'donations.recorded', 'donations', 0)) = 3;

  perform set_config('app.institute_id', '90000000-0000-4000-8000-000000000002', true);
  assert not exists (select from identity.list_manual_donations('90000000-0000-4000-8000-000000000025'));
  assert not (select allowed from identity.read_manual_donation_options('90000000-0000-4000-8000-000000000025'));
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
do $test$
declare
  tenant constant uuid := '90000000-0000-4000-8000-000000000001';
begin
  assert (select count(*) from app.donations where institute_id = tenant) = 3;
  assert (select count(*) from app.donors where institute_id = tenant and email = 'donor@example.test') = 1;
  assert (select count(*) from app.allocations where institute_id = tenant and amount_paisa = 1500000) = 1;
  assert (select count(*) from app.trail_events where institute_id = tenant and event_type = 'received') = 3;
  assert (select count(*) from app.trail_events where institute_id = tenant and event_type = 'allocated') = 1;
  assert (select count(*) from app.audit_log where institute_id = tenant and action = 'donations.recorded' and changes = '{}') = 3;
  assert not exists (select from app.audit_log where institute_id = tenant
    and to_jsonb(audit_log)::text ~ 'private-reference|donor@example.test');
  begin
    delete from app.trail_events where institute_id = tenant;
    raise exception 'Deleting trail events unexpectedly succeeded';
  exception when object_not_in_prerequisite_state then null;
  end;
end
$test$;
rollback;
