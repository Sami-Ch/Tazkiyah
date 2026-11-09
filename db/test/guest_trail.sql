begin;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('13000000-0000-4000-8000-000000000001', 'trail-fixture-a'),
  ('13000000-0000-4000-8000-000000000002', 'trail-fixture-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
select id, '{"en":"Trail institute"}', '{"en":"Trail address"}', '{}', 'TRAIL'
from app.institutes where slug in ('trail-fixture-a', 'trail-fixture-b');

insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('13000000-0000-4000-8000-000000000011', '13000000-0000-4000-8000-000000000001',
    'admin-a@example.test', 'Admin A', 'active', true, false),
  ('13000000-0000-4000-8000-000000000012', '13000000-0000-4000-8000-000000000002',
    'admin-b@example.test', 'Admin B', 'active', true, false),
  ('13000000-0000-4000-8000-000000000013', '13000000-0000-4000-8000-000000000001',
    'finance-a@example.test', 'Finance A', 'active', true, false);
insert into app.user_roles (institute_id, user_id, role)
select institute_id, id, case when full_name = 'Finance A' then 'finance_officer' else 'admin' end
from app.users where id in (
  '13000000-0000-4000-8000-000000000011', '13000000-0000-4000-8000-000000000012',
  '13000000-0000-4000-8000-000000000013'
);
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
select institute_id, user_id, 'fixture-secret', 'fixture-codes', true
from app.user_roles where user_id in (
  '13000000-0000-4000-8000-000000000011', '13000000-0000-4000-8000-000000000012',
  '13000000-0000-4000-8000-000000000013'
);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, two_factor_verified_at)
values
  ('13000000-0000-4000-8000-000000000021', '13000000-0000-4000-8000-000000000001',
    '13000000-0000-4000-8000-000000000011', 'verified-admin-a', now() + interval '1 hour', now()),
  ('13000000-0000-4000-8000-000000000022', '13000000-0000-4000-8000-000000000002',
    '13000000-0000-4000-8000-000000000012', 'verified-admin-b', now() + interval '1 hour', now()),
  ('13000000-0000-4000-8000-000000000023', '13000000-0000-4000-8000-000000000001',
    '13000000-0000-4000-8000-000000000013', 'verified-finance-a', now() + interval '1 hour', now()),
  ('13000000-0000-4000-8000-000000000024', '13000000-0000-4000-8000-000000000001',
    '13000000-0000-4000-8000-000000000011', 'unverified-admin-a', now() + interval '1 hour', null);

insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values
  ('13000000-0000-4000-8000-000000000031', '13000000-0000-4000-8000-000000000001',
    '{"en":"Fixture account A"}', 'Bank A', 'Institution A', 'private-bank-account-a'),
  ('13000000-0000-4000-8000-000000000032', '13000000-0000-4000-8000-000000000002',
    '{"en":"Fixture account B"}', 'Bank B', 'Institution B', 'private-bank-account-b');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, status, target_period)
values ('13000000-0000-4000-8000-000000000041', '13000000-0000-4000-8000-000000000001',
  'trail-books', 'ongoing', '{"en":"Books","ur":"کتب"}', '{"en":"Books","ur":"کتب"}', 'active', 'yearly');

reset role;
set local role tazkiyah_auth;
do $test$
declare
  tenant_a constant uuid := '13000000-0000-4000-8000-000000000001';
  tenant_b constant uuid := '13000000-0000-4000-8000-000000000002';
  admin_a constant uuid := '13000000-0000-4000-8000-000000000021';
  admin_b constant uuid := '13000000-0000-4000-8000-000000000022';
  bank_a constant uuid := '13000000-0000-4000-8000-000000000031';
  bank_b constant uuid := '13000000-0000-4000-8000-000000000032';
  cause constant uuid := '13000000-0000-4000-8000-000000000041';
  today constant date := (now() at time zone 'Asia/Karachi')::date;
  old_hash constant text := repeat('a', 64);
  live_hash constant text := repeat('b', 64);
  other_hash constant text := repeat('c', 64);
  target_email constant text := 'donor-a@example.test';
  first_receipt text;
  last_receipt text;
  other_receipt text;
  missing_donor_receipt text;
  receipt_b text;
  cursor_at timestamptz;
  cursor_id uuid;
  first_ids uuid[];
  result record;
begin
  assert not has_table_privilege(current_user, 'app.trail_links', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE');
  assert not has_table_privilege('tazkiyah_app', 'app.trail_links', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE');
  assert not has_function_privilege('tazkiyah_app', 'identity.read_guest_trail(text,timestamptz,uuid)', 'EXECUTE');
  assert not exists (select from identity.read_guest_trail(old_hash, null, null));

  perform set_config('app.institute_id', tenant_a::text, true);
  perform set_config('app.user_id', '13000000-0000-4000-8000-000000000011', true);
  for n in 1..23 loop
    select * into strict result from identity.record_manual_donation(
      admin_a, gen_random_uuid(), bank_a, 'private-ref-' || n, today, 10000,
      'general', case when n = 1 then cause end, target_email, 'ur', true, false, true
    );
    assert result.code = 'recorded';
    if n = 1 then first_receipt := result.receipt_number; end if;
    last_receipt := result.receipt_number;
  end loop;
  select receipt_number into strict other_receipt from identity.record_manual_donation(
    admin_a, gen_random_uuid(), bank_a, 'private-ref-other-donor', today, 10000,
    'general', null, 'other-donor@example.test', 'en', true, false, true
  );
  select receipt_number into strict missing_donor_receipt from identity.record_manual_donation(
    admin_a, gen_random_uuid(), bank_a, 'private-ref-no-donor', today, 10000,
    'general', null, null, 'en', true, false, true
  );

  assert identity.issue_trail_link(
    '13000000-0000-4000-8000-000000000024', first_receipt, target_email, old_hash
  ) = 'denied', 'Admin MFA was bypassed';
  perform set_config('app.user_id', '13000000-0000-4000-8000-000000000013', true);
  assert identity.issue_trail_link(
    '13000000-0000-4000-8000-000000000023', first_receipt, target_email, old_hash
  ) = 'denied', 'Finance can issue an admin-only link';
  assert identity.revoke_trail_link(
    '13000000-0000-4000-8000-000000000023', first_receipt
  ) = 'denied', 'Finance can revoke an admin-only link';
  perform set_config('app.user_id', '13000000-0000-4000-8000-000000000011', true);
  assert identity.issue_trail_link(admin_a, first_receipt, target_email, 'raw-token') = 'invalid';
  assert identity.issue_trail_link(admin_a, first_receipt, 'different@example.test', old_hash) = 'unavailable';
  assert identity.issue_trail_link(admin_a, missing_donor_receipt, target_email, old_hash) = 'unavailable';
  assert identity.issue_trail_link(admin_a, lower(first_receipt), '  DONOR-A@EXAMPLE.TEST  ', old_hash) = 'issued';
  assert identity.issue_trail_link(admin_a, last_receipt, target_email, live_hash) = 'issued';
  assert not exists (select from identity.read_guest_trail(old_hash, null, null)), 'Old token survived rotation';
  assert identity.issue_trail_link(admin_a, last_receipt, target_email, old_hash) = 'collision',
    'A revoked hash was reactivated';

  perform set_config('app.user_id', '', true);
  assert (select count(*) from identity.read_guest_trail(live_hash, null, null)) = 21, 'First page is unbounded';
  select array_agg(id) into strict first_ids from (
    select id from identity.read_guest_trail(live_hash, null, null) limit 20
  ) first_twenty;
  select recorded_at::timestamptz, id into strict cursor_at, cursor_id
  from identity.read_guest_trail(live_hash, null, null) offset 19 limit 1;
  assert (select count(*) from identity.read_guest_trail(live_hash, cursor_at, cursor_id)) = 3;
  assert not exists (select from identity.read_guest_trail(live_hash, cursor_at, cursor_id) where id = any(first_ids)),
    'Keyset repeated an earlier donation';
  assert not exists (select from identity.read_guest_trail(live_hash, cursor_at + interval '1 day', null)),
    'An incomplete cursor was accepted';
  assert not exists (
    select from identity.read_guest_trail(live_hash, null, null)
    where receipt_number in (other_receipt, missing_donor_receipt)
      or receipt_locale <> 'ur' or credited_on <> today::text or amount_paisa <> '10000'
  ), 'A private page mixed donors or returned incorrect receipt values';
  select * into strict result from (
    select * from identity.read_guest_trail(live_hash, null, null)
    union
    select * from identity.read_guest_trail(live_hash, cursor_at, cursor_id)
  ) trail where receipt_number = first_receipt;
  assert result.events = jsonb_build_array(
    jsonb_build_object('event_type', 'received', 'credited_on', today::text, 'amount_paisa', '10000', 'cause_title', null),
    jsonb_build_object('event_type', 'allocated', 'credited_on', today::text, 'amount_paisa', '10000',
      'cause_title', '{"en":"Books","ur":"کتب"}'::jsonb)
  ), 'Trail events lost exact values or included unintended fields';
  assert row_to_json(result)::text !~ '(private-ref|private-bank|example.test|donor_id|recorded_by|token_hash)',
    'A private response included sensitive metadata';

  perform set_config('app.institute_id', tenant_b::text, true);
  perform set_config('app.user_id', '13000000-0000-4000-8000-000000000012', true);
  select receipt_number into strict receipt_b from identity.record_manual_donation(
    admin_b, gen_random_uuid(), bank_b, 'private-ref-b', today, 20000,
    'sadaqah', null, target_email, 'en', true, false, true
  );
  assert receipt_b = first_receipt, 'Fixture needs the same receipt in both tenants';
  assert not exists (select from identity.read_guest_trail(live_hash, null, null)), 'A valid hash crossed tenant boundaries';
  assert identity.issue_trail_link(admin_b, last_receipt, target_email, other_hash) = 'unavailable',
    'Issuance resolved a receipt in another tenant';
  assert identity.issue_trail_link(admin_b, receipt_b, target_email, other_hash) = 'issued';
  assert (select amount_paisa from identity.read_guest_trail(other_hash, null, null)) = '20000';
  assert identity.revoke_trail_link(admin_b, last_receipt) = 'unavailable', 'Revocation resolved a receipt in another tenant';

  perform set_config('app.institute_id', tenant_a::text, true);
  perform set_config('app.user_id', '13000000-0000-4000-8000-000000000011', true);
  assert not exists (select from identity.read_guest_trail(other_hash, null, null));
  assert identity.revoke_trail_link(admin_a, first_receipt) = 'revoked';
  assert identity.revoke_trail_link(admin_a, first_receipt) = 'revoked';
  assert not exists (select from identity.read_guest_trail(live_hash, null, null)), 'Revoked link is still readable';
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
do $test$
begin
  assert (select count(*) from app.trail_links where revoked_at is null and institute_id in (
    '13000000-0000-4000-8000-000000000001', '13000000-0000-4000-8000-000000000002'
  )) = 1;
  assert (
    select count(*) = 4 and bool_and(
      actor_kind = 'user' and actor_roles = array['admin'] and changes = '{}'::jsonb
        and reason is null and entity_id ~ '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$'
    )
    from app.audit_log where entity_table = 'trail_links' and institute_id in (
      '13000000-0000-4000-8000-000000000001', '13000000-0000-4000-8000-000000000002'
    )
  ), 'Issue and revoke did not produce ID-only audit records';
end
$test$;
rollback;
