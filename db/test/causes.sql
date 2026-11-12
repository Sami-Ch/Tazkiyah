begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('70000000-0000-0000-0000-000000000001', 'cause-fixture-a'),
  ('70000000-0000-0000-0000-000000000002', 'cause-fixture-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix) values
  ('70000000-0000-0000-0000-000000000001', '{"en":"Institute A"}', '{"en":"A"}', '{}', 'CA'),
  ('70000000-0000-0000-0000-000000000002', '{"en":"Institute B"}', '{"en":"B"}', '{}', 'CB');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('71000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001',
    'admin@example.test', 'Cause admin', 'active', true, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('70000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'admin');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('70000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001',
    'fixture-secret', 'fixture-codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, two_factor_verified_at) values
  ('72000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001', 'cause-fixture', now() + interval '1 hour', now()),
  ('72000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001', 'cause-fixture-no-mfa', now() + interval '1 hour', null);
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('74000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001',
  '{"en":"Bank"}', 'Bank', 'Institute A', 'fixture-causes');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, status, target_paisa, ends_on) values
  ('73000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001',
    'expired', 'campaign', '{"en":"Expired"}', '{"en":"Expired"}', 'active', 100,
    (now() at time zone 'Asia/Karachi')::date - 1),
  ('73000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000002',
    'other-institute', 'campaign', '{"en":"Other"}', '{"en":"Other"}', 'active', 100,
    (now() at time zone 'Asia/Karachi')::date + 1);

reset role;
set local role tazkiyah_auth;
do $test$
declare
  tenant constant uuid := '70000000-0000-0000-0000-000000000001';
  other_tenant constant uuid := '70000000-0000-0000-0000-000000000002';
  admin_session constant uuid := '72000000-0000-0000-0000-000000000001';
  unverified_session constant uuid := '72000000-0000-0000-0000-000000000002';
  copy constant jsonb := '{"en":"Campaign","ur":"مہم"}';
  today constant date := (now() at time zone 'Asia/Karachi')::date;
  draft uuid;
  draft_revision uuid;
  previous_revision uuid;
  scheduled uuid;
  scheduled_revision uuid;
  expired uuid;
  expired_revision uuid;
begin
  assert not exists (select from public_api.causes), 'Causes are visible without a tenant';
  assert not has_table_privilege(current_user, 'app.causes', 'SELECT, INSERT, UPDATE, DELETE'),
    'Auth role has direct access to cause records';
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '71000000-0000-0000-0000-000000000001', true);

  assert identity.create_cause(unverified_session, 'school-supplies', 'campaign', copy, copy,
    null, 75025, null, null, null, today, false) = 'denied', 'MFA is required';
  assert identity.create_cause(admin_session, 'school-supplies', 'campaign', '{"en":"Campaign"}',
    copy, null, 75025, null, null, null, today, false) = 'invalid', 'Missing Urdu accepted';
  assert identity.create_cause(admin_session, 'school-supplies', 'campaign', copy, copy,
    null, 75025, null, null, null, null, false) = 'invalid', 'Campaign needs an end date';
  assert identity.create_cause(admin_session, 'school-supplies', 'campaign', copy, copy,
    null, 75025, null, null, null, today, false) = 'created';
  assert identity.create_cause(admin_session, 'school-supplies', 'campaign', copy, copy,
    null, 75025, null, null, null, today, false) = 'duplicate';
  select id, revision into strict draft, draft_revision
  from identity.read_causes(admin_session) where slug = 'school-supplies';
  assert not exists (select from identity.read_causes(unverified_session)), 'Unverified session can read drafts';
  assert not exists (select from public_api.causes where slug = 'school-supplies'), 'Draft is public';
  assert identity.edit_cause(unverified_session, draft, draft_revision, 'campaign', copy, copy,
    null, 75025, null, null, null, today, false) = 'denied', 'Editing bypassed MFA';
  assert identity.edit_cause(admin_session, draft, draft_revision, 'ongoing', copy, copy,
    null, 75025, 'monthly', null, null, null, false) = 'invalid', 'Cause type was changed';
  assert identity.edit_cause(admin_session, draft, draft_revision, 'campaign',
    '{"en":"School supplies","ur":"درسی کتب"}', copy, null, 75025, null, null, null, today, false) = 'updated';
  previous_revision := draft_revision;
  select revision into strict draft_revision from identity.read_causes(admin_session) where id = draft;
  assert draft_revision <> previous_revision, 'Editing did not rotate the revision';
  assert identity.edit_cause(admin_session, draft, previous_revision, 'campaign', copy, copy,
    null, 75025, null, null, null, today, false) = 'stale', 'Stale edits were accepted';
  assert identity.transition_cause(admin_session, draft, previous_revision, 'active') = 'stale',
    'A stale browser can publish unseen content';
  assert identity.transition_cause(admin_session, draft, draft_revision, 'active') = 'updated';
  assert identity.transition_cause(admin_session, draft, draft_revision, 'active') = 'stale';
  assert exists (select from public_api.causes
    where slug = 'school-supplies' and status = 'active' and title ->> 'en' = 'School supplies'
      and target_paisa = 75025 and not accepts_zakat),
    'Published campaign is missing or ended early';
  select revision into strict draft_revision from identity.read_causes(admin_session) where id = draft;
  assert identity.transition_cause(admin_session, draft, draft_revision, 'archived') = 'stale',
    'A live campaign can be archived';
  assert (select code from identity.record_manual_donation(
    admin_session, '75000000-0000-0000-0000-000000000001', '74000000-0000-0000-0000-000000000001',
    'recorded-cause-credit', today, 10000, 'general', draft, null, 'en', true, false, false
  )) = 'recorded';
  assert identity.edit_cause(admin_session, draft, draft_revision, 'campaign', copy, copy,
    null, 75025, null, null, null, today - 1, false) = 'settings_locked',
    'End date may exclude a recorded credit';
  assert identity.edit_cause(admin_session, draft, draft_revision, 'campaign', copy, copy,
    null, 75025, null, null, null, today, true) = 'settings_locked',
    'Eligibility of a funded cause changed';
  assert identity.edit_cause(admin_session, draft, draft_revision, 'campaign', copy, copy,
    null, 90000, null, null, null, today, false) = 'updated',
    'A funded cause could not update its copy and target';
  assert (select raised_paisa from public_api.causes where id = draft) = 10000,
    'A content edit changed recorded progress';
  select revision into strict draft_revision from identity.read_causes(admin_session) where id = draft;
  assert identity.transition_cause(admin_session, draft, draft_revision, 'closed') = 'updated';
  assert (select status from public_api.causes where slug = 'school-supplies') = 'closed';
  select revision into strict draft_revision from identity.read_causes(admin_session) where id = draft;
  assert identity.transition_cause(admin_session, draft, draft_revision, 'archived') = 'archive_blocked',
    'A cause with retained recorded funds can be archived';

  assert identity.create_cause(admin_session, 'scheduled', 'ongoing', copy, copy,
    null, null, 'monthly', null, today + 1, null, true) = 'created';
  select id, revision into strict scheduled, scheduled_revision
  from identity.read_causes(admin_session) where slug = 'scheduled';
  assert identity.transition_cause(admin_session, scheduled, scheduled_revision, 'active') = 'updated';
  assert not exists (select from public_api.causes where slug = 'scheduled'), 'Future cause is public';
  assert (select status from public_api.causes where slug = 'expired') = 'closed', 'Expired campaign is still open';
  select id, revision into strict expired, expired_revision
  from identity.read_causes(admin_session) where slug = 'expired';
  assert identity.edit_cause(admin_session, expired, expired_revision, 'campaign', copy, copy,
    null, 100, null, null, null, today + 1, false) = 'settings_locked', 'An expired campaign can be reopened';
  assert identity.transition_cause(admin_session, expired, expired_revision, 'archived') = 'updated',
    'A date-expired campaign without funds could not archive';
  assert (select status from public_api.causes where slug = 'expired') = 'archived',
    'Archived cause disappeared or lost its status';
  assert (select code from identity.record_manual_donation(
    admin_session, '75000000-0000-0000-0000-000000000002', '74000000-0000-0000-0000-000000000001',
    'archived-cause-credit', today - 1, 10000, 'general', expired, null, 'en', true, false, true
  )) = 'cause_unavailable', 'Archived cause can accept new funds';
  assert not exists (select from public_api.causes where slug = 'other-institute'), 'Another institute is visible';
  assert identity.transition_cause(admin_session, '73000000-0000-0000-0000-000000000002', expired_revision, 'closed') = 'stale',
    'Admin can close a cause in another institute';

  perform set_config('app.institute_id', other_tenant::text, true);
  assert not exists (select from identity.read_causes(admin_session)), 'Session crosses institute boundary';
  assert (select array_agg(slug) from public_api.causes) = array['other-institute'];
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
do $test$
begin
  assert exists (
    select from app.audit_log where action = 'causes.update'
      and actor_user_id = '71000000-0000-0000-0000-000000000001'
      and changes - 'revision' = '{"status":{"old":"active","new":"closed"}}'
  ), 'Cause closure is not audited';
end
$test$;
rollback;
