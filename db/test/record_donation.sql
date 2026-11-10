-- app.record_donation() (04 §8.3, P1-E3-T43): one transaction writes the
-- donation, received event, cause allocation and allocated event, or nothing.
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('93000000-0000-4000-8000-000000000001', 'record-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('93000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'REC');
insert into app.users (id, institute_id, email, full_name, status) values
  ('93000000-0000-4000-8000-000000000011', '93000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active'),
  ('93000000-0000-4000-8000-000000000012', '93000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active'),
  ('93000000-0000-4000-8000-000000000013', '93000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('93000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000011', 'admin'),
  ('93000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000012', 'finance_officer'),
  ('93000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000013', 'editor');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('93000000-0000-4000-8000-000000000031', '93000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values ('93000000-0000-4000-8000-000000000041', '93000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
  '{"en":"Gas"}', '{"en":"Gas"}', 'monthly', 'active', false);
insert into app.donors (id, institute_id, preferred_language)
values ('93000000-0000-4000-8000-000000000051', '93000000-0000-4000-8000-000000000001', 'ur');

do $test$
declare
  tenant constant uuid := '93000000-0000-4000-8000-000000000001';
  donor constant uuid := '93000000-0000-4000-8000-000000000051';
  bank constant uuid := '93000000-0000-4000-8000-000000000031';
  gas constant uuid := '93000000-0000-4000-8000-000000000041';
  year_text constant text := extract(year from (now() at time zone 'Asia/Karachi'))::text;
  given record;
  allocation app.allocations%rowtype;
begin
  assert not has_function_privilege('tazkiyah_app',
    'app.record_donation(uuid, uuid, uuid, text, bigint, date, uuid, text, text, boolean, text)', 'EXECUTE');
  assert not has_function_privilege('tazkiyah_auth',
    'app.record_donation(uuid, uuid, uuid, text, bigint, date, uuid, text, text, boolean, text)', 'EXECUTE');
  perform set_config('app.institute_id', tenant::text, true);

  -- An editor, or nobody, cannot record.
  perform set_config('app.user_id', '93000000-0000-4000-8000-000000000013', true);
  begin
    perform app.record_donation(gen_random_uuid(), donor, null, 'general', 10000, date '2026-11-01',
      bank, 'editor', 'en');
    assert false, 'an editor recorded a donation';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', '', true);
  begin
    perform app.record_donation(gen_random_uuid(), donor, null, 'general', 10000, date '2026-11-01',
      bank, 'nobody', 'en');
    assert false, 'a donation was recorded with no user';
  exception when insufficient_privilege then null;
  end;

  -- To a cause: four rows that agree, and an audit row.
  perform set_config('app.user_id', '93000000-0000-4000-8000-000000000012', true);
  select * into strict given from app.record_donation(gen_random_uuid(), donor, gas, 'sadaqah', 250000,
    date '2026-11-01', bank, 'to-gas', 'ur', true, 'Matched on statement line 4');
  assert given.receipt_number = 'REC-' || year_text || '-00001';
  assert (select count(*) from app.donations d where d.id = given.donation_id and d.amount_paisa = 250000
    and d.amount_minor = 250000 and d.cause_id = gas and d.donor_id = donor and d.is_anonymous
    and d.private_note = 'Matched on statement line 4'
    and d.recorded_by = '93000000-0000-4000-8000-000000000012') = 1;
  select * into strict allocation from app.allocations a where a.donation_id = given.donation_id;
  assert allocation.kind = 'to_cause' and allocation.cause_id = gas and allocation.amount_paisa = 250000
    and allocation.donation_type = 'sadaqah' and not allocation.is_reversal;
  assert (select array_agg(event_type order by id) from app.trail_events where donation_id = given.donation_id)
    = array['received', 'allocated'];
  assert (select count(*) from app.trail_events where donation_id = given.donation_id and event_type = 'allocated'
    and allocation_id = allocation.id and cause_id = gas and amount_paisa = 250000
    and occurred_on = date '2026-11-01') = 1;
  assert (select count(*) from app.audit_log where entity_id = given.donation_id::text
    and action = 'donations.recorded' and actor_roles = array['finance_officer']) = 1;

  -- To all needs: only the received event, no allocation.
  perform set_config('app.user_id', '93000000-0000-4000-8000-000000000011', true);
  select * into strict given from app.record_donation(gen_random_uuid(), donor, null, 'zakat', 50000,
    date '2026-11-02', bank, 'all-needs', 'en');
  assert given.receipt_number = 'REC-' || year_text || '-00002';
  assert not exists (select from app.allocations where donation_id = given.donation_id);
  assert (select array_agg(event_type) from app.trail_events where donation_id = given.donation_id)
    = array['received'];

  -- A refused donation leaves nothing behind, not even a used receipt number.
  begin
    perform app.record_donation(gen_random_uuid(), donor, gas, 'zakat', 50000, date '2026-11-03',
      bank, 'zakat-to-gas', 'en');
    assert false, 'Zakat was recorded to a cause that does not accept it';
  exception when check_violation then null;
  end;
  assert not exists (select from app.donations where bank_reference = 'zakat-to-gas');
  select * into strict given from app.record_donation(gen_random_uuid(), donor, null, 'general', 10000,
    date '2026-11-03', bank, 'after-refusal', 'en');
  assert given.receipt_number = 'REC-' || year_text || '-00003';
  assert (select count(*) from app.donations where institute_id = tenant) = 3;
  assert (select count(*) from app.trail_events where institute_id = tenant and event_type = 'received') = 3;
end
$test$;
