-- Staff institute settings, module switches, project causes and the
-- expected-pledge list (REQ-MIR-001, REQ-PUB-006, REQ-ROL-010, REQ-DON-013, REQ-DON-003).
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

do $draft$
begin
  assert exists (
    select from app.causes c
    join app.institutes i on i.id = c.institute_id
    where i.slug = 'markaz-al-azeem' and c.slug = 'platform-running-costs'
      and c.status = 'draft' and c.accepts_zakat = false
      and c.listed_as_project and c.category = 'technology'
      and c.why_it_matters is not null and c.cost_lines is not null
  ), 'the sample platform-cost cause is a Zakat-free draft';
end
$draft$;

insert into app.institutes (id, slug) values
  ('68000000-0000-4000-8000-000000000001', 'settings-fixture-a'),
  ('68000000-0000-4000-8000-000000000002', 'settings-fixture-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix) values
  ('68000000-0000-4000-8000-000000000001', '{"en":"A","ur":"ا"}', '{"en":"Address A","ur":"پت ا"}', '{}', 'SA'),
  ('68000000-0000-4000-8000-000000000002', '{"en":"B","ur":"ب"}', '{"en":"Address B","ur":"پتہ ب"}', '{}', 'SB');
insert into app.institute_domains (institute_id, domain, is_primary) values
  ('68000000-0000-4000-8000-000000000001', 'settings-a.example', true);
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('68100000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000001', 'admin-a@example.test', 'Admin A', 'active', true, false),
  ('68100000-0000-4000-8000-000000000002', '68000000-0000-4000-8000-000000000001', 'editor-a@example.test', 'Editor A', 'active', true, false),
  ('68100000-0000-4000-8000-000000000003', '68000000-0000-4000-8000-000000000001', 'finance-a@example.test', 'Finance A', 'active', true, false),
  ('68100000-0000-4000-8000-000000000004', '68000000-0000-4000-8000-000000000002', 'admin-b@example.test', 'Admin B', 'active', true, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000001', 'admin'),
  ('68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000002', 'editor'),
  ('68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000003', 'finance_officer'),
  ('68000000-0000-4000-8000-000000000002', '68100000-0000-4000-8000-000000000004', 'admin');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000001', 'secret', 'codes', true),
  ('68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000002', 'secret', 'codes', true),
  ('68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000003', 'secret', 'codes', true),
  ('68000000-0000-4000-8000-000000000002', '68100000-0000-4000-8000-000000000004', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, two_factor_verified_at) values
  ('68200000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000001', 'settings-admin', now() + interval '1 hour', now()),
  ('68200000-0000-4000-8000-000000000002', '68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000002', 'settings-editor', now() + interval '1 hour', now()),
  ('68200000-0000-4000-8000-000000000003', '68000000-0000-4000-8000-000000000001', '68100000-0000-4000-8000-000000000003', 'settings-finance', now() + interval '1 hour', now()),
  ('68200000-0000-4000-8000-000000000004', '68000000-0000-4000-8000-000000000002', '68100000-0000-4000-8000-000000000004', 'settings-admin-b', now() + interval '1 hour', now());
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number) values
  ('68300000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000001', '{"en":"Main"}', 'Bank', 'Title', 'settings-number');
insert into app.donors (id, institute_id, legal_name, email, preferred_language) values
  ('68400000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000001', 'Fixture donor', 'donor@example.test', 'en'),
  ('68400000-0000-4000-8000-000000000002', '68000000-0000-4000-8000-000000000002', 'Other donor', 'other@example.test', 'en');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status) values
  ('68500000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000001', 'kitchen', 'ongoing', '{"en":"Kitchen","ur":"باورچی خانہ"}', '{"en":"Gas","ur":"گیس"}', 'monthly', 'active');
insert into app.recurring_pledges (id, institute_id, donor_id, cause_id, donation_type, frequency, amount_paisa, starts_on) values
  ('68600000-0000-4000-8000-000000000001', '68000000-0000-4000-8000-000000000001', '68400000-0000-4000-8000-000000000001', '68500000-0000-4000-8000-000000000001', 'general', 'monthly', 500000, date_trunc('month', (now() at time zone 'Asia/Karachi'))::date),
  ('68600000-0000-4000-8000-000000000002', '68000000-0000-4000-8000-000000000001', '68400000-0000-4000-8000-000000000001', '68500000-0000-4000-8000-000000000001', 'sadaqah', 'monthly', 200000, ((now() at time zone 'Asia/Karachi')::date - interval '5 months')::date),
  ('68600000-0000-4000-8000-000000000003', '68000000-0000-4000-8000-000000000001', '68400000-0000-4000-8000-000000000001', null, 'general', 'monthly', 100000, ((now() at time zone 'Asia/Karachi')::date - interval '4 months')::date),
  ('68600000-0000-4000-8000-000000000004', '68000000-0000-4000-8000-000000000002', '68400000-0000-4000-8000-000000000002', null, 'general', 'monthly', 100000, date_trunc('month', (now() at time zone 'Asia/Karachi'))::date);
insert into app.donations (
  institute_id, operation_id, bank_account_id, bank_reference, credited_on,
  amount_minor, amount_paisa, donation_type, donor_id, cause_id, pledge_id,
  receipt_number, receipt_locale, recorded_by
) values (
  '68000000-0000-4000-8000-000000000001', '68700000-0000-4000-8000-000000000001',
  '68300000-0000-4000-8000-000000000001', 'paid-this-month',
  (now() at time zone 'Asia/Karachi')::date, 500000, 500000, 'general',
  '68400000-0000-4000-8000-000000000001', '68500000-0000-4000-8000-000000000001',
  '68600000-0000-4000-8000-000000000001', 'SA-T-1', 'en',
  '68100000-0000-4000-8000-000000000001'
), (
  '68000000-0000-4000-8000-000000000001', '68700000-0000-4000-8000-000000000002',
  '68300000-0000-4000-8000-000000000001', 'paid-last-month',
  (date_trunc('month', (now() at time zone 'Asia/Karachi'))::date - interval '1 day')::date,
  200000, 200000, 'sadaqah',
  '68400000-0000-4000-8000-000000000001', '68500000-0000-4000-8000-000000000001',
  '68600000-0000-4000-8000-000000000002', 'SA-T-2', 'en',
  '68100000-0000-4000-8000-000000000001'
);

reset role;
set local role tazkiyah_auth;

do $test$
declare
  tenant constant uuid := '68000000-0000-4000-8000-000000000001';
  other constant uuid := '68000000-0000-4000-8000-000000000002';
  admin_session constant uuid := '68200000-0000-4000-8000-000000000001';
  editor_session constant uuid := '68200000-0000-4000-8000-000000000002';
  finance_session constant uuid := '68200000-0000-4000-8000-000000000003';
  other_session constant uuid := '68200000-0000-4000-8000-000000000004';
  copy constant jsonb := '{"en":"Room","ur":"کمرہ"}';
  cause_id uuid;
  cause_revision uuid;
  expected_count integer;
begin
  assert not has_table_privilege(current_user, 'app.institute_settings', 'UPDATE'),
    'Auth role can update institute settings directly';
  assert not has_table_privilege(current_user, 'app.recurring_pledges', 'SELECT'),
    'Auth role can read pledges directly';
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '68100000-0000-4000-8000-000000000001', true);

  assert identity.save_institute_settings(editor_session, copy, null::jsonb, null::jsonb, copy, '{}'::jsonb,
    'night-and-paper', null::smallint, 'weekly', null::uuid) = 'denied', 'An editor saved settings';
  assert identity.save_institute_settings(admin_session, '{"en":"A"}'::jsonb, null::jsonb, null::jsonb, copy, '{}'::jsonb,
    'night-and-paper', null::smallint, 'weekly', null::uuid) = 'invalid', 'A name without Urdu was saved';
  assert identity.save_institute_settings(admin_session, copy, null::jsonb, null::jsonb, copy,
    '{"email":"not-an-email"}'::jsonb, 'night-and-paper', null::smallint, 'weekly', null::uuid) = 'invalid',
    'A bad email was saved';
  assert identity.save_institute_settings(admin_session, '{"en":"Institute A","ur":"ادارہ ا"}'::jsonb,
    null::jsonb, null::jsonb, '{"en":"Road A","ur":"سڑک ا"}'::jsonb,
    '{"phone":"+92 300 1234567","email":"office@example.test","visiting":{"en":"After Fajr","ur":"فجر کے بعد"}}'::jsonb,
    'garden-and-clay', 2019::smallint, 'daily', '68100000-0000-4000-8000-000000000001'::uuid) = 'updated';
  assert (select theme_direction = 'garden-and-clay' and spending_batch_mode = 'daily'
    and principal_user_id = '68100000-0000-4000-8000-000000000001'
    and contact ->> 'email' = 'office@example.test' and primary_domain = 'settings-a.example'
    from identity.read_institute_settings(admin_session));
  assert not exists (select from identity.read_institute_settings(editor_session)),
    'An editor read institute settings';

  perform set_config('app.institute_id', other::text, true);
  perform set_config('app.user_id', '68100000-0000-4000-8000-000000000004', true);
  assert (select contact = '{}'::jsonb from identity.read_institute_settings(other_session)),
    'Saving institute A changed institute B';
  assert identity.save_institute_settings(admin_session, copy, null::jsonb, null::jsonb, copy, '{}'::jsonb,
    'night-and-paper', null::smallint, 'weekly', null::uuid) = 'denied', 'A session crossed institutes';

  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '68100000-0000-4000-8000-000000000001', true);
  assert (select count(*) from identity.read_module_switches(admin_session)) = 3;
  assert identity.set_enabled_modules(editor_session, array['new_projects'], false) = 'denied';
  assert identity.set_enabled_modules(admin_session, array['new_projects', 'made_up'], false) = 'invalid';
  assert identity.set_enabled_modules(admin_session, array['student_hub', 'new_projects'], false) = 'updated';
  assert identity.set_enabled_modules(admin_session, array['new_projects'], false) = 'confirm',
    'Switching a module off skipped confirmation';
  assert (select enabled from identity.read_module_switches(admin_session) where module_name = 'student_hub'),
    'A refused switch changed the module';
  assert identity.set_enabled_modules(admin_session, array['new_projects'], true) = 'updated';
  assert not (select enabled from identity.read_module_switches(admin_session) where module_name = 'student_hub');

  assert identity.create_cause(admin_session, 'new-room', 'ongoing', copy, copy,
    null, null, 'monthly', null, null, null, false) = 'created';
  select id, revision into strict cause_id, cause_revision
  from identity.read_causes(admin_session) where slug = 'new-room';
  assert identity.set_cause_project(editor_session, cause_id, cause_revision, true, 'facilities',
    null::date, null::jsonb, null::jsonb) = 'denied';
  assert identity.set_cause_project(admin_session, cause_id, cause_revision, true, null::text,
    null::date, null::jsonb, null::jsonb) = 'invalid', 'A project was listed without a category';
  assert identity.set_cause_project(admin_session, cause_id, cause_revision, true, 'facilities',
    date '2026-11-02', copy, copy) = 'invalid', 'A planned start was not the first of a month';
  assert identity.set_cause_project(admin_session, cause_id, cause_revision, true, 'facilities',
    date '2026-12-01', copy, copy) = 'updated';
  select revision into strict cause_revision from identity.read_causes(admin_session) where id = cause_id;
  assert not exists (select from public_api.projects where slug = 'new-room'),
    'A draft project was public';
  assert identity.transition_cause(admin_session, cause_id, cause_revision, 'active') = 'updated';
  assert exists (select from public_api.projects where slug = 'new-room' and category = 'facilities');
  assert exists (select from public_api.causes where slug = 'new-room'),
    'A project disappeared from the causes list';
  assert identity.set_enabled_modules(admin_session, array[]::text[], true) = 'updated';
  assert not exists (select from public_api.projects where slug = 'new-room'),
    'Projects stayed public with the module off';
  assert exists (select from public_api.causes where slug = 'new-room'),
    'Switching the module off removed the cause';
  assert exists (select from identity.read_causes(admin_session) where id = cause_id and listed_as_project);

  perform set_config('app.user_id', '68100000-0000-4000-8000-000000000003', true);
  assert not exists (select from identity.refresh_expected_pledges(editor_session)),
    'An editor read expected pledges';
  select count(*) into expected_count from identity.refresh_expected_pledges(finance_session);
  assert expected_count = 1, 'expected one unpaid pledge';
  assert exists (
    select from identity.refresh_expected_pledges(finance_session) pledge
    where pledge.id = '68600000-0000-4000-8000-000000000002'
      and pledge.donor_label = 'Fixture donor' and pledge.cause_title ->> 'en' = 'Kitchen'
  ), 'The unpaid pledge was missing, or the paid one was listed';
  assert not exists (
    select from identity.refresh_expected_pledges(finance_session)
    where id in (
      '68600000-0000-4000-8000-000000000001',
      '68600000-0000-4000-8000-000000000003',
      '68600000-0000-4000-8000-000000000004'
    )
  ), 'A paid, lapsed or other-institute pledge stayed on the list';
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
do $lapsed$
begin
  assert (select status from app.recurring_pledges where id = '68600000-0000-4000-8000-000000000003') = 'lapsed',
    'Three missed months did not lapse the pledge';
  assert (select status from app.recurring_pledges where id = '68600000-0000-4000-8000-000000000002') = 'active',
    'A pledge with last month paid was lapsed';
  assert (select contact ->> 'email' from app.institute_settings
    where institute_id = '68000000-0000-4000-8000-000000000002') is null,
    'Institute B contact was overwritten';
end
$lapsed$;
