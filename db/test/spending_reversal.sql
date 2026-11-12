-- Reported events, spending reversal and re-matching (04 §9.3, 06 §9.3,
-- §15.3, P2-E2-T41).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a1000000-0000-4000-8000-000000000001', 'reversal-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('a1000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'REV');
insert into app.users (id, institute_id, email, full_name, status) values
  ('a1000000-0000-4000-8000-000000000011', 'a1000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active'),
  ('a1000000-0000-4000-8000-000000000012', 'a1000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('a1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000011', 'admin'),
  ('a1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000012', 'editor');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('a1000000-0000-4000-8000-000000000031', 'a1000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values ('a1000000-0000-4000-8000-000000000041', 'a1000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
  '{"en":"Wheat stock"}', '{"en":"Wheat"}', 'monthly', 'active', true);
insert into app.donors (id, institute_id, preferred_language)
values ('a1000000-0000-4000-8000-000000000051', 'a1000000-0000-4000-8000-000000000001', 'en');

do $test$
declare
  tenant constant uuid := 'a1000000-0000-4000-8000-000000000001';
  admin constant uuid := 'a1000000-0000-4000-8000-000000000011';
  donor constant uuid := 'a1000000-0000-4000-8000-000000000051';
  bank constant uuid := 'a1000000-0000-4000-8000-000000000031';
  wheat constant uuid := 'a1000000-0000-4000-8000-000000000041';
  d1 uuid; d2 uuid; d3 uuid; d4 uuid; d5 uuid;
  s1 uuid; s2 uuid; s2b uuid; s3 uuid;
  r1 uuid; r2 uuid; empty uuid;
  trail text;
begin
  foreach trail in array array['app.reverse_spending(uuid, text, text)', 'app.publish_spending_report(uuid)',
    'app.reverse_matches(uuid, uuid, text)']
  loop
    assert not has_function_privilege('tazkiyah_app', trail, 'EXECUTE'), trail || ' is granted to the app';
    assert not has_function_privilege('tazkiyah_auth', trail, 'EXECUTE'), trail || ' is granted to auth';
  end loop;
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);

  -- 04 §9.3: D1, D2 (Zakat) and D3 in Wheat stock; S1 and S2 in report R1.
  select donation_id into d1 from app.record_donation(gen_random_uuid(), donor, wheat, 'general', 1000000,
    date '2026-11-01', bank, 'D1', 'en');
  select donation_id into d2 from app.record_donation(gen_random_uuid(), donor, wheat, 'zakat', 500000,
    date '2026-11-03', bank, 'D2', 'en');
  select donation_id into d3 from app.record_donation(gen_random_uuid(), donor, wheat, 'sadaqah', 800000,
    date '2026-11-05', bank, 'D3', 'en');
  insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
  values (tenant, 'weekly', date '2026-11-04', date '2026-11-10', '{"en":"R1"}', admin) returning id into r1;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, report_id, status,
    recorded_by)
  values (tenant, wheat, 1200000, date '2026-11-07', '{"en":"S1"}', r1, 'recorded', admin) returning id into s1;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, report_id, status,
    recorded_by)
  values (tenant, wheat, 900000, date '2026-11-10', '{"en":"S2"}', r1, 'recorded', admin) returning id into s2;
  perform app.match_spending(s1);
  perform app.match_spending(s2);

  -- Publishing writes one reported event per donation, for its total in the report.
  insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
  values (tenant, 'daily', date '2026-11-11', date '2026-11-11', '{"en":"Empty"}', admin) returning id into empty;
  begin
    perform app.publish_spending_report(empty);
    assert false, 'an empty report was published';
  exception when object_not_in_prerequisite_state then null;
  end;
  perform set_config('app.user_id', 'a1000000-0000-4000-8000-000000000012', true);
  begin
    perform app.publish_spending_report(r1);
    assert false, 'an editor published a report';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', admin::text, true);
  assert app.publish_spending_report(r1) = 3;
  assert (select (status, published_by) = ('published', admin) from app.spending_reports where id = r1);
  begin
    perform app.publish_spending_report(r1);
    assert false, 'a report was published twice';
  exception when object_not_in_prerequisite_state then null;
  end;
  select string_agg(event_type || ':' || amount_paisa, ' ' order by id) into trail
  from app.trail_events where donation_id = d2;
  assert trail = 'received:500000 allocated:500000 spent:200000 spent:300000 reported:500000',
    'unexpected trail for D2: ' || trail;

  -- Correction: S2 should have been Rs 8,000. Reversing it reverses its two
  -- matches; the reported events stay as history.
  perform set_config('app.user_id', 'a1000000-0000-4000-8000-000000000012', true);
  begin
    perform app.reverse_spending(s2, 'wrong_details');
    assert false, 'an editor reversed spending';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', admin::text, true);
  begin
    perform app.reverse_spending(s2, 'other');
    assert false, '"other" was accepted without a note';
  exception when invalid_parameter_value then null;
  end;
  perform app.reverse_spending(s2, 'wrong_details', 'Typed 9,000 for 8,000');
  assert (select status from app.spending_entries where id = s2) = 'reversed';
  assert (select array_agg(o.event_type || ':' || o.amount_paisa order by o.id) from app.trail_events r
    join app.trail_events o on o.id = r.reverses_event_id
    where r.spending_entry_id = s2 and r.event_type = 'reversal' and r.reason = 'wrong_details')
    = array['spent:300000', 'spent:600000'];
  assert (select count(*) from app.trail_events where event_type = 'reversal' and reverses_event_id in
    (select id from app.trail_events where event_type = 'reported')) = 0;
  assert (select reason from app.audit_log where action = 'spending_entries.reversed' and entity_id = s2::text)
    = 'Typed 9,000 for 8,000';
  begin
    perform app.reverse_spending(s2, 'wrong_details');
    assert false, 'an entry was reversed twice';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- S2' of Rs 8,000 is matched again: 300,000 from D2 and 500,000 from D3.
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
  values (tenant, wheat, 800000, date '2026-11-10', '{"en":"S2 corrected"}', 'recorded', admin) returning id into s2b;
  perform app.match_spending(s2b);
  assert (select array_agg(donation_id || ':' || amount_paisa order by amount_paisa)
    from app.allocations where spending_entry_id = s2b) = array[d2 || ':300000', d3 || ':500000'];

  -- Money matched into an already reported entry is reported at once (06 §8.1).
  insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
  values (tenant, 'daily', date '2026-11-12', date '2026-11-12', '{"en":"R2"}', admin) returning id into r2;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, report_id, status,
    recorded_by)
  values (tenant, wheat, 1000000, date '2026-11-12', '{"en":"S3 on credit"}', r2, 'recorded', admin)
  returning id into s3;
  perform app.match_spending(s3);
  assert app.publish_spending_report(r2) = 1;
  select donation_id into d4 from app.record_donation(gen_random_uuid(), donor, wheat, 'general', 400000,
    date '2026-11-13', bank, 'D4', 'en');
  perform app.match_spending(s3);
  select string_agg(event_type || ':' || amount_paisa || ':' || occurred_on, ' ' order by id) into trail
  from app.trail_events where donation_id = d4;
  assert trail = 'received:400000:2026-11-13 allocated:400000:2026-11-13 spent:400000:2026-11-13 reported:400000:2026-11-13',
    'unexpected trail for D4: ' || trail;

  -- Reversing a spent donation reverses its matches and reported events, then
  -- other unspent money covers the entries it paid for, oldest entry first.
  select donation_id into d5 from app.record_donation(gen_random_uuid(), donor, wheat, 'general', 200000,
    date '2026-11-14', bank, 'D5', 'en');
  perform app.reverse_donation(d3, 'recorded_twice');
  assert (select status from app.donations where id = d3) = 'reversed';
  assert not exists (select from app.allocations_effective where donation_id = d3);
  assert not exists (select from app.trail_events e where e.donation_id = d3 and e.event_type <> 'reversal'
    and not exists (select from app.trail_events r where r.reverses_event_id = e.id)),
    'an event of the reversed donation was left standing';
  assert (select array_agg(spending_entry_id || ':' || amount_paisa) from app.allocations_effective
    where donation_id = d5 and kind = 'to_spending') = array[s2b || ':200000'],
    'D5 did not cover the oldest shortfall';
  assert not exists (select from app.allocation_event_gaps), 'an allocation lacks its one event';
end
$test$;
