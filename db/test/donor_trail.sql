-- app.donor_trail (P1-E4-T40): a donor's own events, through the account or a
-- trail token, under the donor's own RLS, with per-spend shares.
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('97000000-0000-4000-8000-000000000001', 'trail-view-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('97000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'DTV');
insert into app.users (id, institute_id, email, full_name, status) values
  ('97000000-0000-4000-8000-000000000011', '97000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active'),
  ('97000000-0000-4000-8000-000000000012', '97000000-0000-4000-8000-000000000001', 'giver@example.test', 'Giver', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000011', 'finance_officer'),
  ('97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000012', 'donor');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number, show_on_donate)
values ('97000000-0000-4000-8000-000000000031', '97000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number', true);
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status)
values ('97000000-0000-4000-8000-000000000041', '97000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
  '{"en":"Wheat","ur":"گندم"}', '{"en":"Wheat"}', 'monthly', 'active');
insert into app.donors (id, institute_id, email, user_id, preferred_language) values
  ('97000000-0000-4000-8000-000000000051', '97000000-0000-4000-8000-000000000001', 'guest@example.test', null, 'en'),
  ('97000000-0000-4000-8000-000000000052', '97000000-0000-4000-8000-000000000001', 'giver@example.test',
    '97000000-0000-4000-8000-000000000012', 'ur');

insert into app.spending_entries (id, institute_id, cause_id, amount_paisa, spent_on, description, recorded_by, status)
values ('97000000-0000-4000-8000-000000000071', '97000000-0000-4000-8000-000000000001',
  '97000000-0000-4000-8000-000000000041', 200000, date '2026-11-07', '{"en":"Wheat, 30 maunds"}',
  '97000000-0000-4000-8000-000000000011', 'recorded');

do $fixture$
declare
  tenant constant uuid := '97000000-0000-4000-8000-000000000001';
  bank constant uuid := '97000000-0000-4000-8000-000000000031';
  wheat constant uuid := '97000000-0000-4000-8000-000000000041';
  given uuid;
  source uuid;
  spend uuid;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '97000000-0000-4000-8000-000000000011', true);
  select donation_id into given from app.record_donation(gen_random_uuid(), '97000000-0000-4000-8000-000000000051',
    wheat, 'general', 300000, date '2026-11-01', bank, 'guest-wheat', 'en', true, 'Staff only note');
  select id into source from app.allocations where donation_id = given;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
    spending_entry_id, amount_paisa, created_by)
  values (tenant, 'to_spending', given, 'general', source, wheat, '97000000-0000-4000-8000-000000000071',
    120000, '97000000-0000-4000-8000-000000000011')
  returning id into spend;
  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa, cause_id,
    allocation_id, spending_entry_id, recorded_by)
  values (tenant, given, 'spent', date '2026-11-07', 120000, wheat, spend,
    '97000000-0000-4000-8000-000000000071', '97000000-0000-4000-8000-000000000011');
  perform app.record_donation(gen_random_uuid(), '97000000-0000-4000-8000-000000000051', null, 'zakat',
    50000, date '2026-11-02', bank, 'guest-all-needs', 'en');
  select donation_id into given from app.record_donation(gen_random_uuid(), '97000000-0000-4000-8000-000000000052',
    wheat, 'sadaqah', 70000, date '2026-11-03', bank, 'account-wheat', 'ur');
  perform app.reverse_donation(given, 'recorded_twice');
end
$fixture$;
insert into app.trail_links (institute_id, donor_id, token_hash, token_hint, created_by)
values ('97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000051',
  encode(sha256(convert_to(repeat('G', 43), 'UTF8')), 'hex'), 'GGGG', '97000000-0000-4000-8000-000000000011');

set local role tazkiyah_app;
do $test$
begin
  perform set_config('app.institute_id', '97000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.donor_trail), 'a visitor saw a trail';
  assert not exists (select from app.donations), 'a visitor saw donations';

  -- The guest, through their token: two donations, five events, one share.
  assert app.use_trail_token(repeat('G', 43)) = '97000000-0000-4000-8000-000000000051';
  assert (select count(distinct donation_id) from app.donor_trail) = 2;
  assert (select array_agg(event_type order by event_id) from app.donor_trail where receipt_number like 'DTV-%-00001')
    = array['received', 'allocated', 'spent'];
  assert (select share_paisa from app.donor_trail where event_type = 'spent') = 120000;
  assert (select count(*) from app.donor_trail where share_paisa is not null) = 1;
  assert (select cause_title ->> 'ur' from app.donor_trail where event_type = 'allocated') = 'گندم';
  assert (select array_agg(event_type) from app.donor_trail where given_to_cause_id is null) = array['received'];
  assert not exists (select from app.donor_trail where donation_status <> 'recorded');
  assert (select count(*) from app.donations) = 2;
  begin
    perform private_note from app.donations;
    assert false, 'the staff note was readable';
  exception when insufficient_privilege then null;
  end;
  begin
    perform bank_reference from app.donations;
    assert false, 'the bank reference was readable';
  exception when insufficient_privilege then null;
  end;
  begin
    perform recorded_by from app.trail_events;
    assert false, 'the recording staff member was readable';
  exception when insufficient_privilege then null;
  end;

  -- The account donor sees only their own, reversed, donation with its reversal events.
  perform app.use_trail_token('no token');
  perform set_config('app.user_id', '97000000-0000-4000-8000-000000000012', true);
  assert (select count(distinct donation_id) from app.donor_trail) = 1;
  assert (select bool_and(donation_status = 'reversed') from app.donor_trail);
  assert (select count(*) from app.donor_trail where event_type = 'reversal' and reason = 'recorded_twice') = 2;
  assert (select count(*) from app.donor_trail where event_type <> 'reversal' and is_reversed) = 2;
  assert (select count(*) from app.trail_events) = 4;

  -- A finance officer, a staff role, reads no donor trail through this view.
  perform set_config('app.user_id', '97000000-0000-4000-8000-000000000011', true);
  assert not exists (select from app.donor_trail);
  assert not exists (select from app.donations);
end
$test$;
