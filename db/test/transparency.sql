-- Public trails, donor profiles, all-needs split and published reports.
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('c7000000-0000-4000-8000-000000000001', 'transparency'),
  ('c7000000-0000-4000-8000-000000000002', 'transparency-other');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix) values
  ('c7000000-0000-4000-8000-000000000001', '{"en":"Institute","ur":"ادارہ"}', '{"en":"A"}', '{}', 'TRN'),
  ('c7000000-0000-4000-8000-000000000002', '{"en":"Other"}', '{"en":"B"}', '{}', 'OTH');
insert into app.users (id, institute_id, email, full_name, status, email_verified, two_factor_enabled, must_change_password) values
  ('c7000000-0000-4000-8000-000000000011', 'c7000000-0000-4000-8000-000000000001', 'admin@transparency.test', 'Admin', 'active', true, true, false),
  ('c7000000-0000-4000-8000-000000000012', 'c7000000-0000-4000-8000-000000000001', 'finance@transparency.test', 'Finance', 'active', true, true, false),
  ('c7000000-0000-4000-8000-000000000013', 'c7000000-0000-4000-8000-000000000001', 'editor@transparency.test', 'Editor', 'active', true, false, false),
  ('c7000000-0000-4000-8000-000000000014', 'c7000000-0000-4000-8000-000000000001', 'donor@transparency.test', 'Donor Legal', 'active', true, false, false),
  ('c7000000-0000-4000-8000-000000000015', 'c7000000-0000-4000-8000-000000000001', 'other-donor@transparency.test', 'Other Donor', 'active', true, false, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000011', 'admin'),
  ('c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000012', 'finance_officer'),
  ('c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000013', 'editor'),
  ('c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000014', 'donor'),
  ('c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000015', 'donor');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000011', 'secret', 'codes', true),
  ('c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000012', 'secret', 'codes', true);
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number) values
  ('c7000000-0000-4000-8000-000000000031', 'c7000000-0000-4000-8000-000000000001', '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat) values
  ('c7000000-0000-4000-8000-000000000041', 'c7000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat","ur":"گندم"}', '{"en":"Wheat"}', 'monthly', 'active', false),
  ('c7000000-0000-4000-8000-000000000042', 'c7000000-0000-4000-8000-000000000001', 'zakat-cause', 'ongoing',
    '{"en":"Zakat cause","ur":"زکوٰۃ"}', '{"en":"Zakat"}', 'monthly', 'active', true);
insert into app.donors (id, institute_id, user_id, email, preferred_language, legal_name, phone) values
  ('c7000000-0000-4000-8000-000000000051', 'c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000014',
    'donor@transparency.test', 'en', 'Donor Legal', '+92 300 0000000'),
  ('c7000000-0000-4000-8000-000000000052', 'c7000000-0000-4000-8000-000000000001', null, null, 'en', 'Guest Legal', null),
  ('c7000000-0000-4000-8000-000000000053', 'c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000015',
    'other-donor@transparency.test', 'en', null, null);

select set_config('app.institute_id', 'c7000000-0000-4000-8000-000000000001', true);
select set_config('app.user_id', 'c7000000-0000-4000-8000-000000000012', true);
select donation_id from app.record_donation(
  'c7000000-0000-4000-8000-000000000071', 'c7000000-0000-4000-8000-000000000051', null,
  'general', 200000, current_date, 'c7000000-0000-4000-8000-000000000031', 'pool-gift', 'en', true);
select donation_id from app.record_donation(
  'c7000000-0000-4000-8000-000000000072', 'c7000000-0000-4000-8000-000000000051', null,
  'zakat', 100000, current_date, 'c7000000-0000-4000-8000-000000000031', 'zakat-pool', 'en', true);
select donation_id from app.record_donation(
  'c7000000-0000-4000-8000-000000000073', 'c7000000-0000-4000-8000-000000000051',
  'c7000000-0000-4000-8000-000000000041', 'general', 150000, current_date,
  'c7000000-0000-4000-8000-000000000031', 'wheat-gift', 'en', false);
select donation_id from app.record_donation(
  'c7000000-0000-4000-8000-000000000074', 'c7000000-0000-4000-8000-000000000052',
  'c7000000-0000-4000-8000-000000000041', 'sadaqah', 50000, current_date,
  'c7000000-0000-4000-8000-000000000031', 'guest-gift', 'en', true);

insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('c7000000-0000-4000-8000-000000000061', 'c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000011', 'admin-session', now() + interval '1 hour', now(), now()),
  ('c7000000-0000-4000-8000-000000000062', 'c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000012', 'finance-session', now() + interval '1 hour', now(), now()),
  ('c7000000-0000-4000-8000-000000000063', 'c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000013', 'editor-session', now() + interval '1 hour', now(), null),
  ('c7000000-0000-4000-8000-000000000064', 'c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000014', 'donor-session', now() + interval '1 hour', now(), null),
  ('c7000000-0000-4000-8000-000000000065', 'c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000015', 'other-donor-session', now() + interval '1 hour', now(), null);
insert into app.trail_links (institute_id, donor_id, token_hash, token_hint, created_by) values
  ('c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000052', repeat('ab', 32), 'hint', 'c7000000-0000-4000-8000-000000000012');
select set_config('test.named_ref', public_ref, false),
  set_config('test.named_receipt', receipt_number, false)
from app.donations where bank_reference = 'wheat-gift';
select set_config('test.guest_ref', public_ref, false)
from app.donations where bank_reference = 'guest-gift';
select set_config('test.pool_ref', public_ref, false)
from app.donations where bank_reference = 'pool-gift';

reset role;
set local role tazkiyah_auth;
select set_config('app.institute_id', 'c7000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'c7000000-0000-4000-8000-000000000012', true);

do $test$
declare
  admin_session constant uuid := 'c7000000-0000-4000-8000-000000000061';
  finance constant uuid := 'c7000000-0000-4000-8000-000000000062';
  editor constant uuid := 'c7000000-0000-4000-8000-000000000063';
  donor_session constant uuid := 'c7000000-0000-4000-8000-000000000064';
  other_session constant uuid := 'c7000000-0000-4000-8000-000000000065';
  admin_user constant uuid := 'c7000000-0000-4000-8000-000000000011';
  finance_user constant uuid := 'c7000000-0000-4000-8000-000000000012';
  donor_user constant uuid := 'c7000000-0000-4000-8000-000000000014';
  wheat constant uuid := 'c7000000-0000-4000-8000-000000000041';
  zakat_cause constant uuid := 'c7000000-0000-4000-8000-000000000042';
  named_ref text;
  guest_ref text;
  preview jsonb;
  applied jsonb;
  saved_code text;
  draft_id uuid;
  report uuid;
  published record;
  seen text;
begin
  perform set_config('app.user_id', finance_user::text, true);
  assert identity.all_needs_workspace(finance) ->> 'allowed' = 'false', 'finance split the pool';
  perform set_config('app.user_id', admin_user::text, true);
  assert (identity.all_needs_workspace(admin_session) ->> 'allowed')::boolean, 'admin workspace hidden';
  assert identity.preview_all_needs_split(admin_session, 'zakat', jsonb_build_array(jsonb_build_object(
    'cause_id', wheat, 'amount_paisa', 100000
  ))) ->> 'code' = 'cause', 'zakat entered a general cause';
  preview := identity.preview_all_needs_split(admin_session, 'general', jsonb_build_array(jsonb_build_object(
    'cause_id', wheat, 'amount_paisa', 100000
  )));
  assert preview ->> 'code' = 'preview', preview ->> 'code';
  assert jsonb_array_length(preview -> 'draws') = 1, 'preview did not draw one gift';
  applied := identity.apply_all_needs_split(admin_session, 'general', jsonb_build_array(jsonb_build_object(
    'cause_id', wheat, 'amount_paisa', 100000
  )));
  assert applied ->> 'code' = 'split', applied ->> 'code';
  assert identity.preview_all_needs_split(admin_session, 'general', jsonb_build_array(jsonb_build_object(
    'cause_id', wheat, 'amount_paisa', 100000000
  ))) ->> 'code' = 'over', 'over-pool split was accepted';
  perform set_config('app.user_id', finance_user::text, true);
  assert identity.apply_all_needs_split(finance, 'general', jsonb_build_array(jsonb_build_object(
    'cause_id', zakat_cause, 'amount_paisa', 10000
  ))) ->> 'code' = 'denied', 'finance applied a split';

  select code, entry_id into saved_code, draft_id from identity.save_spending_draft(
    finance, wheat, 40000, current_date, '{"en":"Flour","ur":"آٹا"}'::jsonb, true);
  assert saved_code = 'saved', saved_code;
  select code into saved_code from identity.record_spending_batch(finance, draft_id);
  assert saved_code = 'recorded', saved_code;
  select code, report_id into saved_code, report from identity.save_spending_report(
    editor, 'daily', current_date, current_date, '{"en":"Day"}'::jsonb, null, array[draft_id]);
  assert saved_code = 'denied', saved_code;
  select code, report_id into saved_code, report from identity.save_spending_report(
    finance, 'weekly', current_date, current_date, '{"en":"Week"}'::jsonb, null, array[draft_id]);
  assert saved_code = 'invalid', 'weekly dates were not seven days';
  select code, report_id into saved_code, report from identity.save_spending_report(
    finance, 'daily', current_date, current_date, '{"en":"Day","ur":"دن"}'::jsonb, null, array[draft_id]);
  assert saved_code = 'saved', saved_code;
  perform set_config('app.user_id', 'c7000000-0000-4000-8000-000000000013', true);
  select * into published from identity.publish_staff_report(editor, report);
  assert published.code = 'denied', published.code;
  perform set_config('app.user_id', finance_user::text, true);
  select * into published from identity.publish_staff_report(finance, report);
  assert published.code = 'published' and published.events >= 1, published.code;
  assert exists (
    select from jsonb_array_elements(identity.spending_reports_workspace(finance) -> 'reports') item
    where item ->> 'id' = report::text and item ->> 'status' = 'published'
  ), 'published report missing from the workspace';

  named_ref := current_setting('test.named_ref');
  guest_ref := current_setting('test.guest_ref');
  perform set_config('app.user_id', donor_user::text, true);
  assert identity.set_donation_visibility(donor_session, null, named_ref, null, false, true) = 'saved';
  perform set_config('app.user_id', 'c7000000-0000-4000-8000-000000000015', true);
  assert identity.set_donation_visibility(other_session, null, named_ref, null, true, false) = 'not_found',
    'another donor changed this gift';
  perform set_config('app.user_id', finance_user::text, true);
  assert identity.set_donation_visibility(finance, null, named_ref, null, false, true) = 'denied',
    'staff named a gift';
  assert identity.set_donation_visibility(
    finance, null, null, current_setting('test.named_receipt'), true, false
  ) = 'saved';
  assert exists (
    select from jsonb_array_elements(identity.spending_reports_workspace(finance) -> 'reports') item
    where item ->> 'status' = 'published'
  ), 'finance lost the published report';
  perform set_config('app.user_id', donor_user::text, true);
  assert identity.set_donation_visibility(donor_session, null, named_ref, null, false, true) = 'saved';
  assert identity.save_donor_profile(donor_session, '', true, '[]'::jsonb) = 'name';
  assert identity.save_donor_profile(
    donor_session, 'Sample Donor', true,
    '[{"label":"Site","url":"https://example.test/sample"}]'::jsonb
  ) = 'saved';
  assert identity.save_guest_display_name(repeat('ab', 32), 'Guest Sample') = 'saved';
  assert identity.set_donation_visibility(null, repeat('ab', 32), guest_ref, null, false, true) = 'saved';

  assert exists (
    select from public_api.public_trails t where t.public_ref = named_ref and t.donor_label = 'Sample Donor'
  ), 'public trail hid a chosen name';
  assert not exists (
    select from public_api.public_trails t where t.public_ref = (
      current_setting('test.pool_ref')
    )
  ), 'a private trail was public';
  assert exists (
    select from public_api.donor_profiles p where p.display_name = 'Sample Donor'
  );
  assert exists (
    select from public_api.donor_profile_gifts g where g.public_ref = named_ref
  );
  assert not exists (
    select from public_api.donor_profile_gifts g where g.public_ref = (
      current_setting('test.pool_ref')
    )
  ), 'an anonymous gift joined the profile';
  select string_agg(v::text, ' ') into seen from (
    select to_jsonb(p) as v from public_api.donor_profiles p
    union all select to_jsonb(g) from public_api.donor_profile_gifts g
    union all select to_jsonb(w) from public_api.donor_wall w
    union all select to_jsonb(t) from public_api.public_trails t
  ) rows;
  assert seen !~* 'donor legal|guest legal|\+92|zakat|sadaqah', seen;

  perform set_config('app.institute_id', 'c7000000-0000-4000-8000-000000000002', true);
  assert not exists (select from public_api.public_trails), 'public trail crossed institutes';
  assert not exists (select from public_api.donor_profiles), 'profile crossed institutes';
  perform set_config('app.institute_id', 'c7000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', donor_user::text, true);
  assert identity.set_donation_visibility(donor_session, null, named_ref, null, null, null) = 'invalid';
end
$test$;
