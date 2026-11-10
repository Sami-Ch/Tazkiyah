-- app.reverse_donation() (P1-E3-T45): reversal allocations and events for a
-- whole donation, refused while money spent from it remains.
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('95000000-0000-4000-8000-000000000001', 'reverse-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('95000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'REV');
insert into app.users (id, institute_id, email, full_name, status) values
  ('95000000-0000-4000-8000-000000000011', '95000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active'),
  ('95000000-0000-4000-8000-000000000012', '95000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('95000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000011', 'finance_officer'),
  ('95000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000012', 'editor');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number, show_on_donate)
values ('95000000-0000-4000-8000-000000000031', '95000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number', true);
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status)
values
  ('95000000-0000-4000-8000-000000000041', '95000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat"}', '{"en":"Wheat"}', 'monthly', 'active'),
  ('95000000-0000-4000-8000-000000000042', '95000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
    '{"en":"Gas"}', '{"en":"Gas"}', 'monthly', 'active');
insert into app.donors (id, institute_id, preferred_language)
values ('95000000-0000-4000-8000-000000000051', '95000000-0000-4000-8000-000000000001', 'en');
insert into app.spending_entries (id, institute_id, cause_id, amount_paisa, spent_on, description, recorded_by, status)
values ('95000000-0000-4000-8000-000000000071', '95000000-0000-4000-8000-000000000001',
  '95000000-0000-4000-8000-000000000041', 100000, current_date, '{"en":"Wheat"}',
  '95000000-0000-4000-8000-000000000011', 'recorded');

do $test$
declare
  tenant constant uuid := '95000000-0000-4000-8000-000000000001';
  donor constant uuid := '95000000-0000-4000-8000-000000000051';
  bank constant uuid := '95000000-0000-4000-8000-000000000031';
  wheat constant uuid := '95000000-0000-4000-8000-000000000041';
  gas constant uuid := '95000000-0000-4000-8000-000000000042';
  today constant date := (now() at time zone 'Asia/Karachi')::date;
  to_wheat uuid;
  split uuid;
  spent uuid;
  source_allocation uuid;
  spend_allocation uuid;
begin
  assert not has_function_privilege('tazkiyah_app', 'app.reverse_donation(uuid, text, text)', 'EXECUTE');
  assert not has_function_privilege('tazkiyah_auth', 'app.reverse_donation(uuid, text, text)', 'EXECUTE');
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '95000000-0000-4000-8000-000000000011', true);
  select donation_id into to_wheat from app.record_donation(gen_random_uuid(), donor, wheat, 'general', 300000,
    today, bank, 'to-wheat', 'en');
  -- An all-needs donation split across two causes by hand.
  select donation_id into split from app.record_donation(gen_random_uuid(), donor, null, 'sadaqah', 200000,
    today, bank, 'split', 'en');
  insert into app.allocations (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa, created_by)
  values (tenant, 'to_cause', split, 'sadaqah', wheat, 50000, '95000000-0000-4000-8000-000000000011'),
         (tenant, 'to_cause', split, 'sadaqah', gas, 150000, '95000000-0000-4000-8000-000000000011');
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
    allocation_id, recorded_by)
  select tenant, a.donation_id, 'allocated', today, a.amount_paisa, a.cause_id, a.id, a.created_by
  from app.allocations a where a.donation_id = split;
  -- A donation with a spend against it.
  select donation_id into spent from app.record_donation(gen_random_uuid(), donor, wheat, 'general', 100000,
    today, bank, 'spent', 'en');
  select id into source_allocation from app.allocations where donation_id = spent;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
    spending_entry_id, amount_paisa, created_by)
  values (tenant, 'to_spending', spent, 'general', source_allocation, wheat,
    '95000000-0000-4000-8000-000000000071', 40000, '95000000-0000-4000-8000-000000000011')
  returning id into spend_allocation;
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
    allocation_id, spending_entry_id, recorded_by)
  values (tenant, spent, 'spent', today, 40000, wheat, spend_allocation,
    '95000000-0000-4000-8000-000000000071', '95000000-0000-4000-8000-000000000011');
  assert (select lifetime_raised_paisa from public_api.causes where id = wheat) = 450000;

  -- Who and why.
  perform set_config('app.user_id', '95000000-0000-4000-8000-000000000012', true);
  begin
    perform app.reverse_donation(to_wheat, 'recorded_twice');
    assert false, 'an editor reversed a donation';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', '95000000-0000-4000-8000-000000000011', true);
  begin
    perform app.reverse_donation(to_wheat, 'other');
    assert false, '"other" was accepted without a note';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform app.reverse_donation(to_wheat, 'typo');
    assert false, 'an unknown category was accepted';
  exception when invalid_parameter_value then null;
  end;

  -- A spent donation is refused until its spending is reversed.
  begin
    perform app.reverse_donation(spent, 'wrong_details');
    assert false, 'a spent donation was reversed';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- A donation to one cause: its received and allocated events are reversed.
  perform app.reverse_donation(to_wheat, 'recorded_twice', '  Same statement line entered twice  ');
  assert (select status from app.donations where id = to_wheat) = 'reversed';
  assert (select count(*) from app.allocations where donation_id = to_wheat and is_reversal
    and reason = 'recorded_twice' and amount_paisa = 300000 and cause_id = wheat) = 1;
  assert (select array_agg(o.event_type order by o.id) from app.trail_events r
    join app.trail_events o on o.id = r.reverses_event_id
    where r.donation_id = to_wheat and r.event_type = 'reversal' and r.reason = 'recorded_twice')
    = array['received', 'allocated'];
  assert (select count(*) from app.audit_log where entity_id = to_wheat::text and action = 'donations.reversed'
    and changes = '{"category":{"old":null,"new":"recorded_twice"}}' and reason = 'Same statement line entered twice') = 1;
  begin
    perform app.reverse_donation(to_wheat, 'recorded_twice');
    assert false, 'a donation was reversed twice';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- A split donation: every allocation is reversed.
  perform app.reverse_donation(split, 'wrong_type');
  assert (select count(*) from app.allocations where donation_id = split and is_reversal) = 2;
  assert (select count(*) from app.trail_events where donation_id = split and event_type = 'reversal') = 3;

  -- Totals drop back, and the same bank reference can be recorded again.
  assert (select lifetime_raised_paisa from public_api.causes where id = wheat) = 100000;
  assert (select lifetime_raised_paisa from public_api.causes where id = gas) = 0;
  perform app.record_donation(gen_random_uuid(), donor, wheat, 'general', 300000, today, bank, 'to-wheat', 'en');

  -- The guest trail gives the donor the category of a reversed donation only.
  insert into app.trail_links (institute_id, donor_id, token_hash, token_hint, created_by)
  values (tenant, donor, repeat('d', 64), 'dddd', '95000000-0000-4000-8000-000000000011');
  assert (select reversal_reason from identity.read_guest_trail(repeat('d', 64), null, null)
    where id = to_wheat) = 'recorded_twice';
  assert (select reversal_reason from identity.read_guest_trail(repeat('d', 64), null, null)
    where id = split) = 'wrong_type';
  assert (select count(*) from identity.read_guest_trail(repeat('d', 64), null, null)
    where reversal_reason is not null) = 2;
  assert not exists (select from identity.read_guest_trail(repeat('d', 64), null, null) t
    where t::text like '%Same statement line%');
end
$test$;
