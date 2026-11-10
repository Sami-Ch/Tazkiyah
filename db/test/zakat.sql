-- Zakat ring-fencing in data (04 §9.4, P2-E3-T40, REQ-TRL-006).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('9d000000-0000-4000-8000-000000000001', 'zakat-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('9d000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'ZAK');
insert into app.users (id, institute_id, email, full_name, status) values
  ('9d000000-0000-4000-8000-000000000011', '9d000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('9d000000-0000-4000-8000-000000000001', '9d000000-0000-4000-8000-000000000011', 'admin');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('9d000000-0000-4000-8000-000000000031', '9d000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values
  ('9d000000-0000-4000-8000-000000000041', '9d000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat"}', '{"en":"Wheat"}', 'monthly', 'active', true),
  ('9d000000-0000-4000-8000-000000000042', '9d000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
    '{"en":"Gas"}', '{"en":"Gas"}', 'monthly', 'active', false);
insert into app.donors (id, institute_id, preferred_language)
values ('9d000000-0000-4000-8000-000000000051', '9d000000-0000-4000-8000-000000000001', 'en');

set constraints all immediate;
do $test$
declare
  tenant constant uuid := '9d000000-0000-4000-8000-000000000001';
  admin constant uuid := '9d000000-0000-4000-8000-000000000011';
  donor constant uuid := '9d000000-0000-4000-8000-000000000051';
  bank constant uuid := '9d000000-0000-4000-8000-000000000031';
  wheat constant uuid := '9d000000-0000-4000-8000-000000000041';
  gas constant uuid := '9d000000-0000-4000-8000-000000000042';
  pooled uuid; given uuid; general uuid; source uuid; entry uuid; piece uuid;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);

  -- 1. A Zakat donation to a cause that does not accept Zakat.
  begin
    perform app.record_donation(gen_random_uuid(), donor, gas, 'zakat', 100000, date '2026-11-01', bank, 'Z0', 'en');
    assert false, 'a Zakat donation was recorded to a non-Zakat cause';
  exception when check_violation then null;
  end;

  -- 2. All-needs Zakat split later: only into a Zakat cause.
  select donation_id into pooled from app.record_donation(gen_random_uuid(), donor, null, 'zakat', 200000,
    date '2026-11-01', bank, 'Z1', 'en');
  begin
    insert into app.allocations (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa, created_by)
    values (tenant, 'to_cause', pooled, 'zakat', gas, 100000, admin);
    assert false, 'Zakat was split into a non-Zakat cause';
  exception when check_violation then null;
  end;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa, created_by)
  values (tenant, 'to_cause', pooled, 'zakat', wheat, 100000, admin) returning id into piece;
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
    allocation_id, recorded_by)
  values (tenant, pooled, 'allocated', date '2026-11-02', 100000, wheat, piece, admin);
  -- General money may go anywhere.
  select donation_id into general from app.record_donation(gen_random_uuid(), donor, gas, 'general', 50000,
    date '2026-11-02', bank, 'G1', 'en');

  -- 2. Matching: Zakat is spent only while its cause accepts Zakat. The
  -- switch-off guard (proposed REQ-TRL-015) is not built, so the flag is
  -- changed directly here to show the match-time check.
  select donation_id into given from app.record_donation(gen_random_uuid(), donor, wheat, 'zakat', 300000,
    date '2026-11-03', bank, 'Z2', 'en');
  select id into source from app.allocations where donation_id = given;
  update app.causes set accepts_zakat = false, zakat_approved_by = null where id = wheat;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
  values (tenant, wheat, 100000, date '2026-11-04', '{"en":"Wheat"}', 'recorded', admin) returning id into entry;
  begin
    perform app.match_spending(entry);
    assert false, 'Zakat money was matched in a cause that no longer accepts Zakat';
  exception when check_violation then null;
  end;
  begin
    insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
      spending_entry_id, amount_paisa, created_by)
    values (tenant, 'to_spending', given, 'zakat', source, wheat, entry, 100000, admin);
    assert false, 'a Zakat spend was written in a non-Zakat cause';
  exception when check_violation then null;
  end;

  -- A reversal only takes money back, so it is still allowed.
  perform app.reverse_donation(given, 'wrong_details', null);
  assert exists (select from app.allocations where reverses_allocation_id = source);

  -- With the flag back on, the same match goes through.
  update app.causes set accepts_zakat = true where id = wheat;
  perform app.match_spending(entry);
  assert (select donation_id from app.allocations where spending_entry_id = entry) = pooled;
end
$test$;
set constraints all deferred;
