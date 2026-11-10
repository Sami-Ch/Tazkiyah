-- public_api.cause_summary (P1-E1-T40): target, raised, spent, unspent and
-- the Zakat flag per cause, with no donor field.
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('98000000-0000-4000-8000-000000000001', 'summary-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('98000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SUM');
insert into app.users (id, institute_id, email, full_name, status) values
  ('98000000-0000-4000-8000-000000000011', '98000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('98000000-0000-4000-8000-000000000001', '98000000-0000-4000-8000-000000000011', 'finance_officer');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number, show_on_donate)
values ('98000000-0000-4000-8000-000000000031', '98000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number', true);
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_paisa, target_period,
  status, accepts_zakat, zakat_approved_by)
values
  ('98000000-0000-4000-8000-000000000041', '98000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat stock"}', '{"en":"Wheat"}', 2500000, 'monthly', 'active', true, '{"en":"Mufti A"}'),
  ('98000000-0000-4000-8000-000000000042', '98000000-0000-4000-8000-000000000001', 'draft', 'ongoing',
    '{"en":"Draft"}', '{"en":"Draft"}', null, 'monthly', 'draft', false, null);
insert into app.donors (id, institute_id, email, legal_name, display_name, preferred_language)
values ('98000000-0000-4000-8000-000000000051', '98000000-0000-4000-8000-000000000001',
  'secret-donor@example.test', 'Secret Legal Name', 'Secret Display', 'en');

do $fixture$
declare
  tenant constant uuid := '98000000-0000-4000-8000-000000000001';
  given uuid;
  source uuid;
  spend uuid;
  today constant date := (now() at time zone 'Asia/Karachi')::date;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '98000000-0000-4000-8000-000000000011', true);
  select donation_id into given from app.record_donation(gen_random_uuid(), '98000000-0000-4000-8000-000000000051',
    '98000000-0000-4000-8000-000000000041', 'zakat', 1000000, today, '98000000-0000-4000-8000-000000000031',
    'Secret Bank Reference', 'en');
  select id into source from app.allocations where donation_id = given;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
    spending_entry_id, amount_paisa, created_by)
  values (tenant, 'to_spending', given, 'zakat', source, '98000000-0000-4000-8000-000000000041',
    '98000000-0000-4000-8000-000000000071', 400000, '98000000-0000-4000-8000-000000000011')
  returning id into spend;
  -- A spend that was reversed counts for nothing.
  insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
    spending_entry_id, amount_paisa, created_by)
  values (tenant, 'to_spending', given, 'zakat', source, '98000000-0000-4000-8000-000000000041',
    '98000000-0000-4000-8000-000000000072', 100000, '98000000-0000-4000-8000-000000000011')
  returning id into spend;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
    spending_entry_id, amount_paisa, is_reversal, reverses_allocation_id, reason, created_by)
  values (tenant, 'to_spending', given, 'zakat', source, '98000000-0000-4000-8000-000000000041',
    '98000000-0000-4000-8000-000000000072', 100000, true, spend, 'wrong_details',
    '98000000-0000-4000-8000-000000000011');
  perform app.record_donation(gen_random_uuid(), '98000000-0000-4000-8000-000000000051', null, 'general',
    300000, today, '98000000-0000-4000-8000-000000000031', 'all-needs', 'en');
end
$fixture$;

set local role tazkiyah_app;
do $test$
declare
  summary record;
begin
  perform set_config('app.institute_id', '98000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '', true);
  select * into strict summary from public_api.cause_summary;
  assert summary.slug = 'wheat' and summary.target_paisa = 2500000 and summary.accepts_zakat
    and summary.zakat_approved_by ->> 'en' = 'Mufti A';
  assert summary.raised_paisa = 1000000 and summary.lifetime_raised_paisa = 1000000;
  assert summary.spent_paisa = 400000 and summary.unspent_paisa = 600000;
  -- No donor field, and no donor data in any column.
  assert not exists (
    select from information_schema.columns
    where table_schema = 'public_api' and table_name = 'cause_summary'
      and column_name ~ '(donor|email|name|reference|receipt)'
  );
  assert not exists (select from public_api.cause_summary t
    where t::text ~ '(Secret|secret-donor)');
  perform set_config('app.institute_id', '', true);
  assert not exists (select from public_api.cause_summary);
end
$test$;
