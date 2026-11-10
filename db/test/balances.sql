-- Balance views and the allocation-to-event reconciliation (04 §9.1, §9.2,
-- §9.7, P2-E2-T42).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('9c000000-0000-4000-8000-000000000001', 'balance-fixture'),
  ('9c000000-0000-4000-8000-000000000002', 'balance-other');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix) values
  ('9c000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'BAL'),
  ('9c000000-0000-4000-8000-000000000002', '{"en":"Other"}', '{"en":"B"}', '{}', 'BAO');
insert into app.users (id, institute_id, email, full_name, status) values
  ('9c000000-0000-4000-8000-000000000011', '9c000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('9c000000-0000-4000-8000-000000000001', '9c000000-0000-4000-8000-000000000011', 'admin');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('9c000000-0000-4000-8000-000000000031', '9c000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values
  ('9c000000-0000-4000-8000-000000000041', '9c000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat"}', '{"en":"Wheat"}', 'monthly', 'active', true),
  ('9c000000-0000-4000-8000-000000000042', '9c000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
    '{"en":"Gas"}', '{"en":"Gas"}', 'monthly', 'active', false),
  ('9c000000-0000-4000-8000-000000000043', '9c000000-0000-4000-8000-000000000002', 'other', 'ongoing',
    '{"en":"Other"}', '{"en":"Other"}', 'monthly', 'active', false);
insert into app.donors (id, institute_id, preferred_language)
values ('9c000000-0000-4000-8000-000000000051', '9c000000-0000-4000-8000-000000000001', 'en');

do $test$
declare
  tenant constant uuid := '9c000000-0000-4000-8000-000000000001';
  admin constant uuid := '9c000000-0000-4000-8000-000000000011';
  donor constant uuid := '9c000000-0000-4000-8000-000000000051';
  bank constant uuid := '9c000000-0000-4000-8000-000000000031';
  wheat constant uuid := '9c000000-0000-4000-8000-000000000041';
  gas constant uuid := '9c000000-0000-4000-8000-000000000042';
  zakat_gift uuid; general_gift uuid; wrong_gift uuid;
  zakat_source uuid; general_source uuid;
  entry uuid;
  stray uuid;
  view_name text;
begin
  foreach view_name in array array['app.allocations_effective', 'app.allocation_balances',
    'app.cause_balances', 'app.allocation_event_gaps']
  loop
    assert not has_table_privilege('tazkiyah_app', view_name, 'SELECT'), view_name || ' is readable by the app';
    assert not has_table_privilege('tazkiyah_auth', view_name, 'SELECT'), view_name || ' is readable by auth';
  end loop;

  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);
  select donation_id into zakat_gift from app.record_donation(gen_random_uuid(), donor, wheat, 'zakat',
    500000, date '2026-11-01', bank, 'Z1', 'en');
  select donation_id into general_gift from app.record_donation(gen_random_uuid(), donor, wheat, 'general',
    300000, date '2026-11-02', bank, 'G1', 'en');
  select donation_id into wrong_gift from app.record_donation(gen_random_uuid(), donor, gas, 'general',
    200000, date '2026-11-03', bank, 'W1', 'en');
  select id into zakat_source from app.allocations where donation_id = zakat_gift;
  select id into general_source from app.allocations where donation_id = general_gift;

  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
  values (tenant, wheat, 600000, date '2026-11-04', '{"en":"Wheat"}', 'recorded', admin) returning id into entry;
  perform app.match_spending(entry);
  perform app.reverse_donation(wrong_gift, 'recorded_twice', null);

  -- Effective rows leave out reversals and the rows they reverse.
  assert not exists (select from app.allocations_effective where donation_id = wrong_gift);
  assert (select count(*) from app.allocations_effective) = 4, 'expected two cause rows and two spends';

  -- Each cause row: Zakat fully spent, general 100,000 spent and 200,000 left.
  assert (select (spent_paisa, unspent_paisa) = (500000::bigint, 0::bigint)
    from app.allocation_balances where allocation_id = zakat_source);
  assert (select (spent_paisa, unspent_paisa) = (100000::bigint, 200000::bigint)
    from app.allocation_balances where allocation_id = general_source);

  -- Per cause and type; the reversed gas gift counts for nothing.
  assert (select array_agg(donation_type || ':' || raised_paisa || ':' || spent_paisa || ':' || unspent_paisa
      order by donation_type)
    from app.cause_balances where cause_id = wheat)
    = array['general:300000:100000:200000', 'sadaqah:0:0:0', 'zakat:500000:500000:0'];
  assert (select sum(raised_paisa) from app.cause_balances where cause_id = gas) = 0;
  assert not exists (select from app.cause_balances where cause_id = '9c000000-0000-4000-8000-000000000043'),
    'a balance of another institute was shown';

  -- Every allocation written by the functions has its one event.
  assert not exists (select from app.allocation_event_gaps), 'the functions left an allocation without its event';

  -- An allocation written without its event is reported.
  insert into app.allocations (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa, created_by)
  values (tenant, 'to_cause', general_gift, 'general', gas, 100, admin) returning id into stray;
  assert (select (expected_event, matching_events, all_events) = ('allocated', 0::bigint, 0::bigint)
    from app.allocation_event_gaps where allocation_id = stray);
  assert (select count(*) from app.allocation_event_gaps) = 1;

  -- Writing its event closes the gap. (An event of the wrong kind is refused
  -- by trail_events_rules, so it cannot be set up here.)
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
    allocation_id, recorded_by)
  values (tenant, general_gift, 'allocated', current_date, 100, gas, stray, admin);
  assert not exists (select from app.allocation_event_gaps);
end
$test$;
