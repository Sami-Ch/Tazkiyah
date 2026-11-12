-- app.match_spending() (04 §9.3, P2-E2-T40): the worked example, the 06-P02
-- queue order, partial matches, reruns and who may match.
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('9b000000-0000-4000-8000-000000000001', 'match-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('9b000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'MAT');
insert into app.users (id, institute_id, email, full_name, status) values
  ('9b000000-0000-4000-8000-000000000011', '9b000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active'),
  ('9b000000-0000-4000-8000-000000000012', '9b000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('9b000000-0000-4000-8000-000000000001', '9b000000-0000-4000-8000-000000000011', 'admin'),
  ('9b000000-0000-4000-8000-000000000001', '9b000000-0000-4000-8000-000000000012', 'editor');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('9b000000-0000-4000-8000-000000000031', '9b000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values
  ('9b000000-0000-4000-8000-000000000041', '9b000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat stock"}', '{"en":"Wheat"}', 'monthly', 'active', true),
  ('9b000000-0000-4000-8000-000000000042', '9b000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
    '{"en":"Kitchen gas"}', '{"en":"Gas"}', 'monthly', 'active', false);
insert into app.donors (id, institute_id, preferred_language) values
  ('9b000000-0000-4000-8000-000000000051', '9b000000-0000-4000-8000-000000000001', 'en'),
  ('9b000000-0000-4000-8000-000000000052', '9b000000-0000-4000-8000-000000000001', 'en'),
  ('9b000000-0000-4000-8000-000000000053', '9b000000-0000-4000-8000-000000000001', 'en'),
  ('9b000000-0000-4000-8000-000000000054', '9b000000-0000-4000-8000-000000000001', 'en');

do $test$
declare
  tenant constant uuid := '9b000000-0000-4000-8000-000000000001';
  admin constant uuid := '9b000000-0000-4000-8000-000000000011';
  bank constant uuid := '9b000000-0000-4000-8000-000000000031';
  wheat constant uuid := '9b000000-0000-4000-8000-000000000041';
  gas constant uuid := '9b000000-0000-4000-8000-000000000042';
  d1 uuid; d2 uuid; d3 uuid; d5 uuid;
  a1 uuid; a2 uuid; a3 uuid; a4 uuid;
  s1 uuid; s2 uuid; g1 uuid; draft uuid;
  result record;
  trail text;
begin
  assert not has_function_privilege('tazkiyah_app', 'app.match_spending(uuid)', 'EXECUTE');
  assert not has_function_privilege('tazkiyah_auth', 'app.match_spending(uuid)', 'EXECUTE');
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);

  -- 04 §9.3: D1 and D2 to Wheat stock, D3 to all needs, split on 6 Nov.
  select donation_id into d1 from app.record_donation(gen_random_uuid(), '9b000000-0000-4000-8000-000000000051',
    wheat, 'general', 1000000, date '2026-11-01', bank, 'D1', 'en');
  select donation_id into d2 from app.record_donation(gen_random_uuid(), '9b000000-0000-4000-8000-000000000052',
    wheat, 'zakat', 500000, date '2026-11-03', bank, 'D2', 'en');
  select donation_id into d3 from app.record_donation(gen_random_uuid(), '9b000000-0000-4000-8000-000000000053',
    null, 'sadaqah', 2000000, date '2026-11-05', bank, 'D3', 'en');
  select id into a1 from app.allocations where donation_id = d1;
  select id into a2 from app.allocations where donation_id = d2;
  -- The split function arrives in P2-E4-T40; its rows are written here directly.
  insert into app.allocations (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa, created_by)
  values (tenant, 'to_cause', d3, 'sadaqah', wheat, 800000, admin) returning id into a3;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa, created_by)
  values (tenant, 'to_cause', d3, 'sadaqah', gas, 1200000, admin) returning id into a4;
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
    allocation_id, recorded_by) values
    (tenant, d3, 'allocated', date '2026-11-06', 800000, wheat, a3, admin),
    (tenant, d3, 'allocated', date '2026-11-06', 1200000, gas, a4, admin);

  -- Only recorded entries are matched, and only by an admin or finance officer.
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, recorded_by)
  values (tenant, wheat, 100000, date '2026-11-07', '{"en":"Draft"}', admin) returning id into draft;
  begin
    perform app.match_spending(draft);
    assert false, 'a draft entry was matched';
  exception when object_not_in_prerequisite_state then null;
  end;
  delete from app.spending_entries where id = draft;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
  values (tenant, wheat, 1200000, date '2026-11-07', '{"en":"Wheat"}', 'recorded', admin) returning id into s1;
  perform set_config('app.user_id', '9b000000-0000-4000-8000-000000000012', true);
  begin
    perform app.match_spending(s1);
    assert false, 'an editor matched spending';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', admin::text, true);

  -- S1 takes all of D1, then 200,000 of D2.
  select * into result from app.match_spending(s1);
  assert result.matched_paisa = 1200000 and result.unmatched_paisa = 0, 'S1 was not fully matched';
  assert (select array_agg(from_allocation_id || ':' || amount_paisa order by created_at, amount_paisa desc)
    from app.allocations where spending_entry_id = s1) = array[a1 || ':1000000', a2 || ':200000'],
    'S1 did not take D1 then D2';
  assert exists (select from app.audit_log where action = 'spending_entries.matched' and entity_id = s1::text);

  -- A rerun adds nothing.
  select * into result from app.match_spending(s1);
  assert result.matched_paisa = 1200000 and result.unmatched_paisa = 0;
  assert (select count(*) from app.allocations where spending_entry_id = s1) = 2, 'a rerun matched again';

  -- S2 takes the rest of D2, then 600,000 of D3's wheat piece.
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
  values (tenant, wheat, 900000, date '2026-11-10', '{"en":"Wheat"}', 'recorded', admin) returning id into s2;
  select * into result from app.match_spending(s2);
  assert result.matched_paisa = 900000 and result.unmatched_paisa = 0;
  assert (select array_agg(from_allocation_id || ':' || amount_paisa order by amount_paisa)
    from app.allocations where spending_entry_id = s2) = array[a2 || ':300000', a3 || ':600000'],
    'S2 did not take D2 then D3';

  -- Wheat stock has 200,000 left, all from D3; Kitchen gas is untouched.
  assert (select sum(case when kind = 'to_cause' then amount_paisa else -amount_paisa end)
    from app.allocations where cause_id = wheat) = 200000;
  assert not exists (select from app.allocations where kind = 'to_spending' and cause_id = gas);

  -- D2's trail: received, allocated, spent on S1, spent on S2.
  select string_agg(event_type || ':' || amount_paisa || ':' || coalesce(spending_entry_id::text, '-'), ' ' order by id)
  into trail from app.trail_events where donation_id = d2;
  assert trail = 'received:500000:- allocated:500000:- spent:200000:' || s1 || ' spent:300000:' || s2,
    'unexpected trail for D2: ' || trail;

  -- 06-P02: money enters the queue on the day it entered the cause. D5 was
  -- given after D3, but reached Kitchen gas before D3's split piece did.
  select donation_id into d5 from app.record_donation(gen_random_uuid(), '9b000000-0000-4000-8000-000000000054',
    gas, 'general', 300000, date '2026-11-06', bank, 'D5', 'en');
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
  values (tenant, gas, 1800000, date '2026-11-01', '{"en":"Gas cylinders"}', 'recorded', admin) returning id into g1;
  select * into result from app.match_spending(g1);
  -- Both entered on 6 Nov; D3 has the lower receipt number, so it goes first.
  assert (select array_agg(donation_id || ':' || amount_paisa order by id)
    from app.trail_events where spending_entry_id = g1) = array[d3 || ':1200000', d5 || ':300000'],
    'G1 did not take D3 then D5';

  -- Money ran out: the entry stays partly matched, and the spent date is the
  -- day the money entered the cause, since the purchase came first.
  assert result.matched_paisa = 1500000 and result.unmatched_paisa = 300000, 'G1 was not left partly matched';
  assert (select array_agg(occurred_on order by id) from app.trail_events where spending_entry_id = g1)
    = array[date '2026-11-06', date '2026-11-06'];
  assert (select occurred_on from app.trail_events where spending_entry_id = s1 limit 1) = date '2026-11-07';
end
$test$;

-- 06-P02 apart from 04-D10: an all-needs gift given early but split late
-- waits behind a later gift that went straight to the cause.
set local role tazkiyah_schema_owner;
do $test$
declare
  tenant constant uuid := '9b000000-0000-4000-8000-000000000001';
  admin constant uuid := '9b000000-0000-4000-8000-000000000011';
  bank constant uuid := '9b000000-0000-4000-8000-000000000031';
  gas constant uuid := '9b000000-0000-4000-8000-000000000042';
  early uuid; late uuid; piece uuid; entry uuid;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);
  select donation_id into early from app.record_donation(gen_random_uuid(), '9b000000-0000-4000-8000-000000000051',
    null, 'general', 100000, date '2026-11-02', bank, 'E1', 'en');
  select donation_id into late from app.record_donation(gen_random_uuid(), '9b000000-0000-4000-8000-000000000052',
    gas, 'general', 100000, date '2026-11-04', bank, 'L1', 'en');
  insert into app.allocations (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa, created_by)
  values (tenant, 'to_cause', early, 'general', gas, 100000, admin) returning id into piece;
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
    allocation_id, recorded_by)
  values (tenant, early, 'allocated', date '2026-11-08', 100000, gas, piece, admin);
  -- G1's 300,000 shortfall is still open; a new entry is matched on its own.
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
  values (tenant, gas, 100000, date '2026-11-09', '{"en":"Gas"}', 'recorded', admin) returning id into entry;
  perform app.match_spending(entry);
  assert (select donation_id from app.allocations where spending_entry_id = entry) = late,
    'the early gift split late was matched before the later direct gift';
  assert not exists (select from app.allocation_event_gaps), 'an allocation lacks its one event';
end
$test$;
