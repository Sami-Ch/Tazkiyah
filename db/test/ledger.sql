-- 04 §9.2 and §9.6 (P1-E3-T42): allocation and trail event shapes, the
-- deferred sum checks, reversal rules and the append-only kit on both tables.
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug, kind) values
  ('92000000-0000-4000-8000-000000000001', 'ledger-fixture-a', 'institute'),
  ('92000000-0000-4000-8000-000000000002', 'ledger-fixture-fund', 'platform_fund');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('92000000-0000-4000-8000-000000000001', '{"en":"Institute A"}', '{"en":"A"}', '{}', 'LEDA');
insert into app.users (id, institute_id, email, full_name, status)
values ('92000000-0000-4000-8000-000000000011', '92000000-0000-4000-8000-000000000001',
  'ledger@example.test', 'Ledger', 'active');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('92000000-0000-4000-8000-000000000031', '92000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values
  ('92000000-0000-4000-8000-000000000041', '92000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat"}', '{"en":"Wheat"}', 'monthly', 'active', true),
  ('92000000-0000-4000-8000-000000000042', '92000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
    '{"en":"Gas"}', '{"en":"Gas"}', 'monthly', 'active', false);
insert into app.donors (id, institute_id, preferred_language)
values ('92000000-0000-4000-8000-000000000051', '92000000-0000-4000-8000-000000000001', 'en');
-- D1: Rs 1,000 to all needs, general. D2: Rs 500 Zakat to all needs.
insert into app.donations (id, institute_id, operation_id, bank_account_id, bank_reference, credited_on,
  amount_minor, amount_paisa, donation_type, donor_id, receipt_number, receipt_locale, recorded_by)
values
  ('92000000-0000-4000-8000-000000000061', '92000000-0000-4000-8000-000000000001', gen_random_uuid(),
    '92000000-0000-4000-8000-000000000031', 'd1', date '2026-11-01', 100000, 100000, 'general',
    '92000000-0000-4000-8000-000000000051', 'LEDA-2026-00001', 'en', '92000000-0000-4000-8000-000000000011'),
  ('92000000-0000-4000-8000-000000000062', '92000000-0000-4000-8000-000000000001', gen_random_uuid(),
    '92000000-0000-4000-8000-000000000031', 'd2', date '2026-11-02', 50000, 50000, 'zakat',
    '92000000-0000-4000-8000-000000000051', 'LEDA-2026-00002', 'en', '92000000-0000-4000-8000-000000000011');

insert into app.spending_entries (id, institute_id, cause_id, amount_paisa, spent_on, description, recorded_by, status)
values ('92000000-0000-4000-8000-000000000071', '92000000-0000-4000-8000-000000000001',
  '92000000-0000-4000-8000-000000000041', 100000, date '2026-11-05', '{"en":"Wheat"}',
  '92000000-0000-4000-8000-000000000011', 'recorded');

-- Shorthand for allocation and event inserts in the checks below.
create function pg_temp.place(p_donation uuid, p_kind text, p_type text, p_cause uuid, p_amount bigint,
  p_from uuid default null, p_spend uuid default null, p_reverses uuid default null)
returns uuid language sql as $$
  insert into app.allocations (institute_id, kind, donation_id, donation_type, cause_id, amount_paisa,
    from_allocation_id, spending_entry_id, is_reversal, reverses_allocation_id, reason, created_by)
  values ('92000000-0000-4000-8000-000000000001', p_kind, p_donation, p_type, p_cause, p_amount,
    p_from, p_spend, p_reverses is not null, p_reverses,
    case when p_reverses is not null then 'Correction' end, '92000000-0000-4000-8000-000000000011')
  returning id
$$;
create function pg_temp.event(p_donation uuid, p_type text, p_amount bigint, p_cause uuid default null,
  p_allocation uuid default null, p_spend uuid default null, p_reverses bigint default null)
returns bigint language sql as $$
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
    allocation_id, spending_entry_id, reverses_event_id, reason, recorded_by)
  values ('92000000-0000-4000-8000-000000000001', p_donation, p_type, date '2026-11-05', p_amount, p_cause,
    p_allocation, p_spend, p_reverses, case when p_type = 'reversal' then 'Correction' end,
    '92000000-0000-4000-8000-000000000011')
  returning id
$$;

set constraints all immediate;
do $test$
declare
  d1 constant uuid := '92000000-0000-4000-8000-000000000061';
  d2 constant uuid := '92000000-0000-4000-8000-000000000062';
  wheat constant uuid := '92000000-0000-4000-8000-000000000041';
  gas constant uuid := '92000000-0000-4000-8000-000000000042';
  spend constant uuid := '92000000-0000-4000-8000-000000000071';
  a_wheat uuid;
  a_gas uuid;
  a_spend uuid;
  a_spend_reversal uuid;
  a_wheat_reversal uuid;
  e_received bigint;
  e_wheat bigint;
  e_spent bigint;
begin
  perform set_config('app.institute_id', '92000000-0000-4000-8000-000000000001', true);

  -- A received event carries the whole donation.
  begin
    perform pg_temp.event(d1, 'received', 99999);
    assert false, 'a received event carried part of the donation';
  exception when check_violation then null;
  end;
  e_received := pg_temp.event(d1, 'received', 100000);

  -- Split D1: Rs 600 to wheat and Rs 400 to gas. One paisa more is refused.
  a_wheat := pg_temp.place(d1, 'to_cause', 'general', wheat, 60000);
  a_gas := pg_temp.place(d1, 'to_cause', 'general', gas, 40000);
  begin
    perform pg_temp.place(d1, 'to_cause', 'general', gas, 1);
    assert false, 'a donation was allocated beyond its amount';
  exception when check_violation then null;
  end;
  e_wheat := pg_temp.event(d1, 'allocated', 60000, wheat, a_wheat);
  begin
    perform pg_temp.event(d1, 'allocated', 40000, wheat, a_gas);
    assert false, 'an allocated event named the wrong cause';
  exception when check_violation then null;
  end;
  begin
    perform pg_temp.event(d1, 'allocated', 39999, gas, a_gas);
    assert false, 'an allocated event carried the wrong amount';
  exception when check_violation then null;
  end;
  perform pg_temp.event(d1, 'allocated', 40000, gas, a_gas);

  -- The allocation type must equal the donation type.
  begin
    perform pg_temp.place(d2, 'to_cause', 'general', wheat, 100);
    assert false, 'Zakat money was allocated as general';
  exception when check_violation then null;
  end;

  -- Shapes: one check per kind.
  begin
    perform pg_temp.place(d2, 'to_cause', 'zakat', wheat, 100, a_wheat);
    assert false, 'a cause allocation named a source allocation';
  exception when check_violation then null;
  end;
  begin
    perform pg_temp.place(d1, 'to_spending', 'general', wheat, 100);
    assert false, 'a spend had no source or spending entry';
  exception when check_violation then null;
  end;
  begin
    insert into app.allocations (institute_id, kind, donation_id, donation_type, target_institute_id,
      amount_paisa, created_by)
    values ('92000000-0000-4000-8000-000000000001', 'to_institute', d2, 'zakat',
      '92000000-0000-4000-8000-000000000002', 100, '92000000-0000-4000-8000-000000000011');
    assert false, 'an ordinary institute transferred money to another institute';
  exception when check_violation then null;
  end;

  -- Spending draws on a cause allocation of the same cause, within its amount.
  begin
    perform pg_temp.place(d1, 'to_spending', 'general', gas, 100, a_wheat, spend);
    assert false, 'a spend drew on an allocation of another cause';
  exception when check_violation then null;
  end;
  begin
    perform pg_temp.place(d1, 'to_spending', 'general', wheat, 60001, a_wheat, spend);
    assert false, 'a spend took more than its source allocation';
  exception when check_violation then null;
  end;
  a_spend := pg_temp.place(d1, 'to_spending', 'general', wheat, 20000, a_wheat, spend);
  begin
    perform pg_temp.event(d1, 'allocated', 20000, wheat, a_spend);
    assert false, 'a spend was shown as allocated';
  exception when check_violation then null;
  end;
  e_spent := pg_temp.event(d1, 'spent', 20000, wheat, a_spend, spend);

  -- A cause allocation cannot be reversed while money spent from it remains.
  begin
    perform pg_temp.place(d1, 'to_cause', 'general', wheat, 60000, null, null, a_wheat);
    assert false, 'a cause allocation was reversed while a spend remained';
  exception when check_violation then null;
  end;

  -- A reversal mirrors its original, happens once, and is never reversed.
  begin
    perform pg_temp.place(d1, 'to_spending', 'general', wheat, 10000, a_wheat, spend, a_spend);
    assert false, 'a reversal had a different amount';
  exception when check_violation then null;
  end;
  a_spend_reversal := pg_temp.place(d1, 'to_spending', 'general', wheat, 20000, a_wheat, spend, a_spend);
  begin
    perform pg_temp.place(d1, 'to_spending', 'general', wheat, 20000, a_wheat, spend, a_spend);
    assert false, 'an allocation was reversed twice';
  exception when unique_violation then null;
  end;
  begin
    perform pg_temp.place(d1, 'to_spending', 'general', wheat, 20000, a_wheat, spend, a_spend_reversal);
    assert false, 'a reversal was reversed';
  exception when check_violation then null;
  end;

  -- Reversal events point at a non-reversal event of the same donation, with
  -- the allocation that reverses the original's allocation, once.
  begin
    perform pg_temp.event(d1, 'reversal', 20000, wheat, a_spend_reversal, spend, e_wheat);
    assert false, 'a reversal event pointed at the wrong event';
  exception when check_violation then null;
  end;
  begin
    perform pg_temp.event(d1, 'reversal', 20000, null, null, null, e_spent);
    assert false, 'a spend was reversed in the trail without its ledger reversal';
  exception when check_violation then null;
  end;
  e_spent := pg_temp.event(d1, 'reversal', 20000, wheat, a_spend_reversal, spend, e_spent);
  begin
    perform pg_temp.event(d1, 'reversal', 20000, wheat, a_spend_reversal, spend,
      (select reverses_event_id from app.trail_events where id = e_spent));
    assert false, 'an event was reversed twice';
  exception when unique_violation then null;
  end;
  begin
    perform pg_temp.event(d1, 'reversal', 20000, wheat, a_spend_reversal, spend, e_spent);
    assert false, 'a reversal event was reversed';
  exception when check_violation then null;
  end;
  begin
    perform pg_temp.event(d2, 'reversal', 100000, null, null, null, e_received);
    assert false, 'a reversal event pointed at another donation';
  exception when check_violation then null;
  end;

  -- With the spend reversed, the cause allocation can be reversed and placed
  -- again elsewhere: the effective total stays within the donation.
  a_wheat_reversal := pg_temp.place(d1, 'to_cause', 'general', wheat, 60000, null, null, a_wheat);
  perform pg_temp.event(d1, 'reversal', 60000, wheat, a_wheat_reversal, null, e_wheat);
  perform pg_temp.place(d1, 'to_cause', 'general', gas, 60000);
  begin
    perform pg_temp.place(d1, 'to_spending', 'general', wheat, 100, a_wheat, spend);
    assert false, 'a spend drew on a reversed allocation';
  exception when check_violation then null;
  end;

  -- The public totals count only allocations that stand.
  assert (select lifetime_raised_paisa from public_api.causes where id = gas) = 100000;
  assert (select lifetime_raised_paisa from public_api.causes where id = wheat) = 0;
end
$test$;
set constraints all deferred;

-- Platform-fund shape (REQ-TRL-014): accepted only from a platform fund.
do $test$
declare
  fund constant uuid := '92000000-0000-4000-8000-000000000002';
  fund_user constant uuid := '92000000-0000-4000-8000-000000000012';
  gift uuid;
begin
  insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
  values (fund, '{"en":"Fund"}', '{"en":"F"}', '{}', 'FUND');
  insert into app.users (id, institute_id, email, full_name, status)
  values (fund_user, fund, 'fund@example.test', 'Fund', 'active');
  insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
  values ('92000000-0000-4000-8000-000000000032', fund, '{"en":"Fund"}', 'Bank', 'Title', 'fund-number');
  insert into app.donors (id, institute_id, preferred_language)
  values ('92000000-0000-4000-8000-000000000052', fund, 'en');
  insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
    amount_minor, amount_paisa, donation_type, donor_id, receipt_number, receipt_locale, recorded_by)
  values (fund, gen_random_uuid(), '92000000-0000-4000-8000-000000000032', 'fund-gift', date '2026-11-01',
    100000, 100000, 'general', '92000000-0000-4000-8000-000000000052', 'FUND-2026-00001', 'en', fund_user)
  returning id into gift;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, target_institute_id,
    amount_paisa, created_by)
  values (fund, 'to_institute', gift, 'general', '92000000-0000-4000-8000-000000000001', 100000, fund_user);
  begin
    insert into app.allocations (institute_id, kind, donation_id, donation_type, target_institute_id,
      amount_paisa, created_by)
    values (fund, 'to_institute', gift, 'general', fund, 1, fund_user);
    assert false, 'the fund transferred money to itself';
  exception when check_violation then null;
  end;
end
$test$;

-- Append-only kit (§9.6): the runtime roles hold no write rights, and the
-- owner is stopped by the triggers.
do $test$
declare
  runtime text;
  ledger text;
begin
  foreach runtime in array array['tazkiyah_app', 'tazkiyah_auth'] loop
    foreach ledger in array array['app.allocations', 'app.trail_events', 'app.audit_log'] loop
      assert not has_table_privilege(runtime, ledger, 'UPDATE'), runtime || ' can update ' || ledger;
      assert not has_table_privilege(runtime, ledger, 'DELETE'), runtime || ' can delete ' || ledger;
      assert not has_table_privilege(runtime, ledger, 'TRUNCATE'), runtime || ' can truncate ' || ledger;
    end loop;
  end loop;
  foreach ledger in array array['app.allocations', 'app.trail_events'] loop
    begin
      execute format('update %s set amount_paisa = amount_paisa where institute_id = $1', ledger)
        using '92000000-0000-4000-8000-000000000001'::uuid;
      assert false, 'the owner updated ' || ledger;
    exception when object_not_in_prerequisite_state then null;
    end;
    begin
      execute format('delete from %s where institute_id = $1', ledger)
        using '92000000-0000-4000-8000-000000000001'::uuid;
      assert false, 'the owner deleted from ' || ledger;
    exception when object_not_in_prerequisite_state then null;
    end;
    begin
      execute format('truncate %s cascade', ledger);
      assert false, 'the owner truncated ' || ledger;
    exception when object_not_in_prerequisite_state then null;
    end;
  end loop;
end
$test$;

set local role tazkiyah_app;
do $test$
begin
  perform set_config('app.institute_id', '92000000-0000-4000-8000-000000000001', true);
  begin
    update app.allocations set amount_paisa = 1;
    assert false, 'the runtime role updated allocations';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from app.trail_events;
    assert false, 'the runtime role deleted trail events';
  exception when insufficient_privilege then null;
  end;
end
$test$;
