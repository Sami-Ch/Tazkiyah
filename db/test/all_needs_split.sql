-- The all-needs split and its pools (06 §7, 04 §9.7, P2-E4-T40).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('9e000000-0000-4000-8000-000000000001', 'split-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('9e000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SPL');
insert into app.users (id, institute_id, email, full_name, status) values
  ('9e000000-0000-4000-8000-000000000011', '9e000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active'),
  ('9e000000-0000-4000-8000-000000000012', '9e000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('9e000000-0000-4000-8000-000000000001', '9e000000-0000-4000-8000-000000000011', 'admin'),
  ('9e000000-0000-4000-8000-000000000001', '9e000000-0000-4000-8000-000000000012', 'finance_officer');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('9e000000-0000-4000-8000-000000000031', '9e000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values
  ('9e000000-0000-4000-8000-000000000041', '9e000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat stock"}', '{"en":"Wheat"}', 'monthly', 'active', true),
  ('9e000000-0000-4000-8000-000000000042', '9e000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
    '{"en":"Kitchen gas"}', '{"en":"Gas"}', 'monthly', 'active', false),
  ('9e000000-0000-4000-8000-000000000043', '9e000000-0000-4000-8000-000000000001', 'draft', 'ongoing',
    '{"en":"Draft"}', '{"en":"Draft"}', 'monthly', 'draft', false);
insert into app.donors (id, institute_id, preferred_language) values
  ('9e000000-0000-4000-8000-000000000051', '9e000000-0000-4000-8000-000000000001', 'en'),
  ('9e000000-0000-4000-8000-000000000052', '9e000000-0000-4000-8000-000000000001', 'en'),
  ('9e000000-0000-4000-8000-000000000053', '9e000000-0000-4000-8000-000000000001', 'en');

do $test$
declare
  tenant constant uuid := '9e000000-0000-4000-8000-000000000001';
  admin constant uuid := '9e000000-0000-4000-8000-000000000011';
  bank constant uuid := '9e000000-0000-4000-8000-000000000031';
  wheat constant uuid := '9e000000-0000-4000-8000-000000000041';
  gas constant uuid := '9e000000-0000-4000-8000-000000000042';
  today constant date := (now() at time zone 'Asia/Karachi')::date;
  farah uuid; kamran uuid; zakat_gift uuid; returned uuid;
  pieces text[];
begin
  assert not has_function_privilege('tazkiyah_app', 'app.split_all_needs(text, jsonb)', 'EXECUTE');
  assert not has_function_privilege('tazkiyah_auth', 'app.split_all_needs(text, jsonb)', 'EXECUTE');
  assert not has_table_privilege('tazkiyah_app', 'app.unallocated_all_needs', 'SELECT');
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);

  -- 06 §7.3: Farah and Kamran in the general pool; a Zakat gift in its own pool.
  select donation_id into farah from app.record_donation(gen_random_uuid(), '9e000000-0000-4000-8000-000000000051',
    null, 'general', 4000000, date '2026-03-05', bank, 'F', 'en');
  select donation_id into kamran from app.record_donation(gen_random_uuid(), '9e000000-0000-4000-8000-000000000052',
    null, 'sadaqah', 1000000, date '2026-03-08', bank, 'K', 'en');
  select donation_id into zakat_gift from app.record_donation(gen_random_uuid(), '9e000000-0000-4000-8000-000000000053',
    null, 'zakat', 900000, date '2026-03-01', bank, 'Z', 'en');
  select donation_id into returned from app.record_donation(gen_random_uuid(), '9e000000-0000-4000-8000-000000000053',
    null, 'general', 500000, date '2026-03-01', bank, 'R', 'en');
  perform app.reverse_donation(returned, 'transfer_returned', null);

  assert (select array_agg(pool || ':' || unallocated_paisa order by credited_on, receipt_number)
    from app.unallocated_all_needs) = array['zakat:900000', 'general:4000000', 'general:1000000'],
    'the pools are wrong before the split';

  -- Refusals: a finance officer, too much money, a draft cause, Zakat into a non-Zakat cause.
  perform set_config('app.user_id', '9e000000-0000-4000-8000-000000000012', true);
  begin
    perform app.split_all_needs('general', jsonb_build_array(jsonb_build_object('cause_id', wheat, 'amount_paisa', 100000)));
    assert false, 'a finance officer split all-needs money';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', admin::text, true);
  begin
    perform app.split_all_needs('general', jsonb_build_array(jsonb_build_object('cause_id', wheat, 'amount_paisa', 5000100)));
    assert false, 'a split took more than the pool holds';
  exception when check_violation then null;
  end;
  begin
    perform app.split_all_needs('general', jsonb_build_array(
      jsonb_build_object('cause_id', '9e000000-0000-4000-8000-000000000043', 'amount_paisa', 100000)));
    assert false, 'money was split into a draft cause';
  exception when check_violation then null;
  end;
  begin
    perform app.split_all_needs('zakat', jsonb_build_array(jsonb_build_object('cause_id', gas, 'amount_paisa', 100000)));
    assert false, 'Zakat was split into a non-Zakat cause';
  exception when check_violation then null;
  end;
  begin
    perform app.split_all_needs('general', jsonb_build_array(jsonb_build_object('cause_id', wheat, 'amount_paisa', 100050)));
    assert false, 'a split part was not whole rupees';
  exception when invalid_parameter_value then null;
  end;

  -- Rs 45,000: Wheat Rs 25,000, then Kitchen gas Rs 20,000, oldest money first.
  select array_agg(case donation_id when farah then 'farah' when kamran then 'kamran' end
      || '>' || case cause_id when wheat then 'wheat' else 'gas' end || ':' || amount_paisa)
  into pieces
  from app.split_all_needs('general', jsonb_build_array(
    jsonb_build_object('cause_id', wheat, 'amount_paisa', 2500000),
    jsonb_build_object('cause_id', gas, 'amount_paisa', 2000000)));
  assert pieces = array['farah>wheat:2500000', 'farah>gas:1500000', 'kamran>gas:500000'],
    'unexpected split: ' || array_to_string(pieces, ' ');

  -- Kamran's Rs 5,000 stays in the pool; the Zakat pool is untouched.
  assert (select array_agg(donation_id || ':' || unallocated_paisa order by credited_on)
    from app.unallocated_all_needs) = array[zakat_gift || ':900000', kamran || ':500000'];

  -- Each piece has an allocated event dated the split day, and an audit row per donation.
  assert (select count(*) from app.trail_events
    where donation_id in (farah, kamran) and event_type = 'allocated' and occurred_on = today) = 3;
  assert (select count(*) from app.audit_log where action = 'donations.split') = 2;
  assert (select (changes ->> 'amount_paisa')::bigint from app.audit_log
    where action = 'donations.split' and entity_id = farah::text) = 4000000;
  assert not exists (select from app.allocation_event_gaps);

  -- The Zakat pool goes into a Zakat cause.
  perform app.split_all_needs('zakat', jsonb_build_array(jsonb_build_object('cause_id', wheat, 'amount_paisa', 900000)));
  assert not exists (select from app.unallocated_all_needs where pool = 'zakat');
  assert (select raised_paisa from app.cause_balances where cause_id = wheat and donation_type = 'zakat') = 900000;
end
$test$;
