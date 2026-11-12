-- 04 §8.3 donations rules (P1-E3-T41): public reference, currency fields,
-- required donor, column lock, cause rules, bank guard and receipt numbers.
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('91000000-0000-4000-8000-000000000001', 'donations-fixture-a'),
  ('91000000-0000-4000-8000-000000000002', 'donations-fixture-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values
  ('91000000-0000-4000-8000-000000000001', '{"en":"Institute A"}', '{"en":"A"}', '{}', 'DONA'),
  ('91000000-0000-4000-8000-000000000002', '{"en":"Institute B"}', '{"en":"B"}', '{}', 'DONB');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password)
values ('91000000-0000-4000-8000-000000000011', '91000000-0000-4000-8000-000000000001',
  'finance@example.test', 'Finance', 'active', true, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('91000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000011', 'finance_officer');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
values ('91000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000011', 'test-secret', 'test-backup', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at)
values ('91000000-0000-4000-8000-000000000021', '91000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000011', 'donations-finance', now() + interval '1 hour', now(), now());
insert into app.institute_bank_accounts
  (id, institute_id, label, bank_name, account_title, account_number, for_donation_types, is_active)
values ('91000000-0000-4000-8000-000000000031', '91000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank A', 'Account A', 'number-a', array['general', 'zakat', 'sadaqah'], true);
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_paisa, target_period,
  starts_on, ends_on, accepts_zakat, status)
values
  ('91000000-0000-4000-8000-000000000041', '91000000-0000-4000-8000-000000000001', 'ongoing', 'ongoing',
    '{"en":"Ongoing"}', '{"en":"Ongoing"}', null, 'monthly', null, null, false, 'active'),
  ('91000000-0000-4000-8000-000000000042', '91000000-0000-4000-8000-000000000001', 'campaign', 'campaign',
    '{"en":"Campaign"}', '{"en":"Campaign"}', 100000, null, date '2026-01-01', date '2026-01-31', true, 'active'),
  ('91000000-0000-4000-8000-000000000043', '91000000-0000-4000-8000-000000000001', 'draft', 'ongoing',
    '{"en":"Draft"}', '{"en":"Draft"}', null, 'monthly', null, null, false, 'draft');
insert into app.donors (id, institute_id, email, preferred_language) values
  ('91000000-0000-4000-8000-000000000051', '91000000-0000-4000-8000-000000000001', null, 'en');

-- Receipt numbers are per institute and per year, gap-free, and only the
-- schema owner's definer functions can draw them.
do $test$
begin
  assert not has_function_privilege('tazkiyah_auth', 'app.next_receipt_number(smallint)', 'EXECUTE');
  assert not has_function_privilege('tazkiyah_app', 'app.next_receipt_number(smallint)', 'EXECUTE');
  assert not has_function_privilege('tazkiyah_app', 'app.new_public_ref()', 'EXECUTE');
  perform set_config('app.institute_id', '91000000-0000-4000-8000-000000000001', true);
  assert app.next_receipt_number(2030::smallint) = 'DONA-2030-00001';
  assert app.next_receipt_number(2030::smallint) = 'DONA-2030-00002';
  assert app.next_receipt_number(2031::smallint) = 'DONA-2031-00001';
  perform set_config('app.institute_id', '91000000-0000-4000-8000-000000000002', true);
  assert app.next_receipt_number(2030::smallint) = 'DONB-2030-00001';
  perform set_config('app.institute_id', '', true);
  begin
    perform app.next_receipt_number(2030::smallint);
    assert false, 'a receipt number was drawn with no institute';
  exception when invalid_parameter_value then null;
  end;
  assert app.new_public_ref() ~ '^[a-z2-7]{10}$';
  assert (select count(distinct app.new_public_ref()) from generate_series(1, 200)) = 200;
end
$test$;

reset role;
set local role tazkiyah_auth;
do $test$
declare
  tenant constant uuid := '91000000-0000-4000-8000-000000000001';
  session_id constant uuid := '91000000-0000-4000-8000-000000000021';
  bank constant uuid := '91000000-0000-4000-8000-000000000031';
  today constant date := (now() at time zone 'Asia/Karachi')::date;
  first_result record;
  second_result record;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '91000000-0000-4000-8000-000000000011', true);
  select * into first_result from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'unknown-1', today, 250000, 'general', null, null, 'ur', true, true, true);
  select * into second_result from identity.record_manual_donation(session_id, gen_random_uuid(), bank,
    'unknown-2', today, 250000, 'general', '91000000-0000-4000-8000-000000000041', null, 'en', true, true, true);
  assert first_result.code = 'recorded' and second_result.code = 'recorded';
  assert first_result.receipt_number = 'DONA-' || extract(year from today) || '-00001';
  assert second_result.receipt_number = 'DONA-' || extract(year from today) || '-00002';
  perform set_config('test.first_donation', first_result.donation_id::text, true);
  perform set_config('test.second_donation', second_result.donation_id::text, true);
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
do $test$
declare
  tenant constant uuid := '91000000-0000-4000-8000-000000000001';
  first_id constant uuid := current_setting('test.first_donation')::uuid;
  second_id constant uuid := current_setting('test.second_donation')::uuid;
  first_row app.donations%rowtype;
  second_row app.donations%rowtype;
begin
  select * into strict first_row from app.donations where id = first_id;
  select * into strict second_row from app.donations where id = second_id;

  -- A transfer with no known donor still has its own donor row, with no email,
  -- and two unknown transfers never share one.
  assert first_row.donor_id is not null and second_row.donor_id is not null;
  assert first_row.donor_id <> second_row.donor_id;
  assert (select email is null and preferred_language = 'ur' from app.donors where id = first_row.donor_id);

  assert first_row.public_ref ~ '^[a-z2-7]{10}$' and first_row.public_ref <> second_row.public_ref;
  assert first_row.public_ref <> first_row.receipt_number;
  assert first_row.currency = 'PKR' and first_row.amount_minor = first_row.amount_paisa
    and first_row.fx_rate is null;
  assert not first_row.trail_public and first_row.is_anonymous and first_row.private_note is null;

  -- Column lock: the trail choice and status may change; nothing else.
  update app.donations set trail_public = true where id = first_id;
  begin
    update app.donations set amount_paisa = amount_paisa + 100, amount_minor = amount_minor + 100 where id = first_id;
    assert false, 'the amount changed after recording';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.donations set cause_id = '91000000-0000-4000-8000-000000000041' where id = first_id;
    assert false, 'the cause changed after recording';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.donations set private_note = 'later note' where id = first_id;
    assert false, 'the note changed after recording';
  exception when object_not_in_prerequisite_state then null;
  end;
  update app.donations set status = 'reversed' where id = first_id;
  begin
    update app.donations set status = 'recorded' where id = first_id;
    assert false, 'a reversed donation was restored';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    delete from app.donations where id = second_id;
    assert false, 'a donation was deleted';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- Cause rules hold for every insert, not only the recording function.
  begin
    insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
      amount_minor, amount_paisa, donation_type, donor_id, cause_id, receipt_number, receipt_locale, recorded_by)
    values (tenant, gen_random_uuid(), '91000000-0000-4000-8000-000000000031', 'draft-cause', date '2026-01-10',
      100, 100, 'general', '91000000-0000-4000-8000-000000000051', '91000000-0000-4000-8000-000000000043',
      'DONA-T-1', 'en', '91000000-0000-4000-8000-000000000011');
    assert false, 'a donation went to a draft cause';
  exception when check_violation then null;
  end;
  begin
    insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
      amount_minor, amount_paisa, donation_type, donor_id, cause_id, receipt_number, receipt_locale, recorded_by)
    values (tenant, gen_random_uuid(), '91000000-0000-4000-8000-000000000031', 'late', date '2026-02-01',
      100, 100, 'general', '91000000-0000-4000-8000-000000000051', '91000000-0000-4000-8000-000000000042',
      'DONA-T-2', 'en', '91000000-0000-4000-8000-000000000011');
    assert false, 'a donation went to a campaign after its end date';
  exception when check_violation then null;
  end;
  begin
    insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
      amount_minor, amount_paisa, donation_type, donor_id, cause_id, receipt_number, receipt_locale, recorded_by)
    values (tenant, gen_random_uuid(), '91000000-0000-4000-8000-000000000031', 'zakat', date '2026-01-10',
      100, 100, 'zakat', '91000000-0000-4000-8000-000000000051', '91000000-0000-4000-8000-000000000041',
      'DONA-T-3', 'en', '91000000-0000-4000-8000-000000000011');
    assert false, 'Zakat went to a cause that does not accept it';
  exception when check_violation then null;
  end;
  -- On the end date itself, and Zakat to an eligible campaign, are accepted.
  insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
    amount_minor, amount_paisa, donation_type, donor_id, cause_id, receipt_number, receipt_locale, recorded_by)
  values (tenant, gen_random_uuid(), '91000000-0000-4000-8000-000000000031', 'on-end-date', date '2026-01-31',
    100, 100, 'zakat', '91000000-0000-4000-8000-000000000051', '91000000-0000-4000-8000-000000000042',
    'DONA-T-4', 'en', '91000000-0000-4000-8000-000000000011');

  -- Bank guard and currency fields.
  begin
    insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
      amount_minor, amount_paisa, donation_type, donor_id, receipt_number, receipt_locale, recorded_by)
    values (tenant, gen_random_uuid(), '91000000-0000-4000-8000-000000000031', null, date '2026-01-10',
      100, 100, 'general', '91000000-0000-4000-8000-000000000051', 'DONA-T-5', 'en',
      '91000000-0000-4000-8000-000000000011');
    assert false, 'a bank transfer was recorded with no bank reference';
  exception when check_violation then null;
  end;
  begin
    insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
      amount_minor, amount_paisa, donation_type, donor_id, receipt_number, receipt_locale, recorded_by)
    values (tenant, gen_random_uuid(), '91000000-0000-4000-8000-000000000031', 'minor', date '2026-01-10',
      200, 100, 'general', '91000000-0000-4000-8000-000000000051', 'DONA-T-6', 'en',
      '91000000-0000-4000-8000-000000000011');
    assert false, 'a PKR donation had different minor and paisa amounts';
  exception when check_violation then null;
  end;
  begin
    insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
      amount_minor, amount_paisa, donation_type, receipt_number, receipt_locale, recorded_by)
    values (tenant, gen_random_uuid(), '91000000-0000-4000-8000-000000000031', 'no-donor', date '2026-01-10',
      100, 100, 'general', 'DONA-T-7', 'en', '91000000-0000-4000-8000-000000000011');
    assert false, 'a donation was recorded with no donor';
  exception when not_null_violation then null;
  end;
end
$test$;

do $test$
begin
  truncate app.donations cascade;
  assert false, 'donations were truncated';
exception when object_not_in_prerequisite_state then null;
end
$test$;
