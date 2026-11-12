begin;
set local plpgsql.check_asserts = on;

do $test$
begin
  assert exists (
    select 1 from pg_catalog.pg_roles
    where rolname = 'tazkiyah_auth' and not rolsuper and not rolbypassrls
      and not rolcreaterole and not rolcreatedb and not rolreplication
  ), 'Auth role has elevated attributes';
  assert not pg_has_role('tazkiyah_auth', 'tazkiyah_schema_owner', 'member'),
    'Auth role can assume the schema owner';
  assert not has_schema_privilege('tazkiyah_app', 'identity', 'USAGE'),
    'Application role can access the auth schema';
  assert not has_table_privilege('tazkiyah_auth', 'app.user_roles', 'SELECT, INSERT, UPDATE, DELETE'),
    'Auth role can read or modify app roles';
  -- Since D-118 the auth role adds a donor's first password and changes a
  -- password by email reset; the policies are tested below.
  assert not has_table_privilege('tazkiyah_auth', 'identity.accounts', 'DELETE'),
    'Auth endpoints can delete credentials';
  assert not exists (
    select from information_schema.column_privileges
    where grantee = 'tazkiyah_auth' and table_schema = 'identity' and table_name = 'accounts'
      and privilege_type = 'UPDATE' and column_name not in ('password', 'updated_at')
  ), 'Auth endpoints can move a credential to another user or provider';
  assert not exists (
    select from information_schema.column_privileges
    where grantee = 'tazkiyah_auth' and table_schema = 'app' and table_name = 'users'
      and privilege_type = 'UPDATE'
      and column_name not in ('email_verified', 'two_factor_enabled', 'updated_at')
  ), 'Auth endpoints can change a user''s status, username or profile';
  execute format('grant tazkiyah_auth to %I', current_user);
end
$test$;

set local role tazkiyah_schema_owner;
insert into app.institutes (id, slug) values
  ('00000000-0000-4000-8000-0000000000a1', 'auth-fixture-a'),
  ('00000000-0000-4000-8000-0000000000b1', 'auth-fixture-b');
insert into app.users (id, institute_id, email, username, full_name, status) values
  ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000a1',
    'auth-fixture@example.test', 'auth-fixture', 'Institute A user', 'active'),
  ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-4000-8000-0000000000b1',
    'auth-fixture@example.test', 'auth-fixture', 'Institute B user', 'active');
insert into identity.accounts (institute_id, user_id, provider_id, account_id)
select institute_id, id, 'credential', id::text from app.users
where id in ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000b2');

reset role;
set local role tazkiyah_auth;
do $test$
begin
  assert not exists (select from app.users), 'Auth users are visible without tenant context';
  assert not exists (select from identity.accounts), 'Credentials are visible without tenant context';

  perform set_config('app.institute_id', '00000000-0000-4000-8000-0000000000a1', true);
  assert (
    select array_agg(full_name) = array['Institute A user']::text[]
    from app.users where email = 'auth-fixture@example.test'
  ) is true, 'Shared email crosses institute boundaries';
  assert (
    select array_agg(account_id) = array['00000000-0000-4000-8000-0000000000a2']::text[]
    from identity.accounts
  ) is true, 'Auth role can read another institute’s credentials';

  begin
    insert into identity.sessions (user_id, token, expires_at)
    values ('00000000-0000-4000-8000-0000000000b2', 'fixture-token', now());
    raise exception 'Auth role can create a session for another institute';
  exception when foreign_key_violation then
    null;
  end;
end
$test$;

reset role;
set local role tazkiyah_schema_owner;

insert into identity.sessions (institute_id, user_id, token, expires_at)
values
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a2', 'auth-fixture-a', now() + interval '1 hour'),
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000b2', 'auth-fixture-b', now() + interval '1 hour');

insert into app.user_roles (institute_id, user_id, role)
values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a2', 'admin');

update app.users set two_factor_enabled = true
where id = '00000000-0000-4000-8000-0000000000b2';

do $test$
begin
  assert not exists (select from identity.sessions where token = 'auth-fixture-a'),
    'Role changes must revoke previously issued sessions';
  assert not exists (select from identity.sessions where token = 'auth-fixture-b'),
    'Enrolling two-factor must revoke previously issued sessions';
end
$test$;

update app.users set status = 'invited'
where id = '00000000-0000-4000-8000-0000000000b2';
insert into app.user_roles (institute_id, user_id, role)
values ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000b2', 'teacher');
insert into identity.staff_invitations (institute_id, user_id, token_hash, expires_at)
values (
  '00000000-0000-4000-8000-0000000000b1',
  '00000000-0000-4000-8000-0000000000b2',
  repeat('b', 64), now() + interval '24 hours'
);

reset role;
set local role tazkiyah_auth;
do $test$
begin
  perform set_config('app.institute_id', '00000000-0000-4000-8000-0000000000a1', true);
  assert not exists (select from identity.staff_invitations),
    'The auth role can see an invitation from another institute';
  assert not identity.accept_staff_invitation(repeat('b', 64), repeat('x', 64)),
    'An invitation can be redeemed on another institute’s domain';

  perform set_config('app.institute_id', '00000000-0000-4000-8000-0000000000b1', true);
  assert exists (select from identity.staff_invitations where token_hash = repeat('b', 64)),
    'The cross-institute redemption consumed the real invitation';
end
$test$;

-- Self sign-up and credentials (P0-E5-T02, D-118).
reset role;
set local role tazkiyah_schema_owner;
insert into app.users (id, institute_id, username, full_name, status) values
  ('00000000-0000-4000-8000-0000000000a4', '00000000-0000-4000-8000-0000000000a1',
    'auth-student', 'Institute A student', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a4', 'student');
insert into identity.accounts (institute_id, user_id, provider_id, account_id, password)
values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a4',
  'credential', '00000000-0000-4000-8000-0000000000a4', 'student-hash');

reset role;
set local role tazkiyah_auth;
do $test$
declare
  donor app.users;
  changed integer;
begin
  perform set_config('app.institute_id', '00000000-0000-4000-8000-0000000000a1', true);

  insert into app.users (id, institute_id, email, full_name, status, must_change_password,
    email_verified, two_factor_enabled, is_orphan, public_name)
  values ('00000000-0000-4000-8000-0000000000a5', '00000000-0000-4000-8000-0000000000a1',
    'self-signup@example.test', 'Self sign-up',
    'suspended', true, true, true, true, 'Chosen name')
  returning * into donor;
  assert donor.status = 'active' and not donor.must_change_password and not donor.email_verified
    and not donor.two_factor_enabled and not donor.is_orphan and donor.public_name is null,
    'Self sign-up chose its own status, verification or profile';
  assert identity.is_donor_only(donor.id) and identity.needs_email_verification(donor.id),
    'A self-signed-up user is not an unverified donor';

  begin
    insert into app.users (institute_id, email, username, full_name)
    values ('00000000-0000-4000-8000-0000000000a1', 'self-username@example.test',
      'chosen-username', 'Chosen username');
    raise exception 'Self sign-up chose a username';
  exception when insufficient_privilege then null;
  end;

  insert into identity.accounts (user_id, provider_id, account_id, password)
  values (donor.id, 'credential', donor.id::text, 'donor-hash');
  begin
    insert into identity.accounts (user_id, provider_id, account_id, password)
    values (donor.id, 'credential', gen_random_uuid()::text, 'second-hash');
    raise exception 'Auth role added a second credential to a donor';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into identity.accounts (user_id, provider_id, account_id, password)
    values ('00000000-0000-4000-8000-0000000000a2', 'credential',
      '00000000-0000-4000-8000-0000000000a2', 'admin-hash');
    raise exception 'Auth role added a credential to a staff account';
  exception when insufficient_privilege then null;
  end;

  update identity.accounts set password = 'changed-hash'
  where user_id = '00000000-0000-4000-8000-0000000000a4';
  get diagnostics changed = row_count;
  assert changed = 0, 'A student password changed outside a teacher reset';
  assert identity.can_reset_by_email(donor.id)
    and not identity.can_reset_by_email('00000000-0000-4000-8000-0000000000a4'),
    'Email reset rules do not match 03 §6.2';
end
$test$;

reset role;
do $test$
begin
  assert (
    select array_agg(role) = array['donor']
    from app.user_roles where user_id = '00000000-0000-4000-8000-0000000000a5'
  ) is true, 'Self sign-up did not create exactly the donor role';
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('00000000-0000-4000-8000-0000000000a1', '{"en":"Institute A"}', '{"en":"A"}', '{}', 'AA');
update app.users set two_factor_enabled = true, must_change_password = false
where id = '00000000-0000-4000-8000-0000000000a2';
update app.users set status = 'active'
where id = '00000000-0000-4000-8000-0000000000b2';
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
values (
  '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a2',
  'fixture-secret', 'fixture-codes', true
);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, two_factor_verified_at)
values (
  '00000000-0000-4000-8000-0000000000a3', '00000000-0000-4000-8000-0000000000a1',
  '00000000-0000-4000-8000-0000000000a2', 'directory-fixture', now() + interval '1 hour', now()
);
insert into app.audit_log (institute_id, actor_kind, action, entity_table, entity_id, changes, reason)
values
  ('00000000-0000-4000-8000-0000000000a1', 'system', 'users.update', 'users',
    '00000000-0000-4000-8000-0000000000a2',
    '{"status":{"old":"active","new":"suspended"},"email":{"old":null,"new":"private@example.test"},"role":{"old":"teacher","new":"private@example.test"}}',
    'private@example.test'),
  ('00000000-0000-4000-8000-0000000000b1', 'system', 'users.update', 'users',
    '00000000-0000-4000-8000-0000000000b2', '{"status":{"old":"active","new":"left"}}', null);

reset role;
set local role tazkiyah_auth;
do $test$
declare
  admin_session uuid := '00000000-0000-4000-8000-0000000000a3';
  fixture_bank uuid;
begin
  perform set_config('app.institute_id', '00000000-0000-4000-8000-0000000000a1', true);
  perform set_config('app.user_id', '00000000-0000-4000-8000-0000000000a2', true);
  assert (
    select array_agg(name) = array['Institute A user']
    from identity.list_staff(admin_session, null, null, null, 0)
  ) is true, 'The directory includes staff from another institute';
  assert (
    select count(*) = 1 and bool_and(
      changes = '{"status":{"old":"active","new":"suspended"}}'::jsonb and hidden_fields = 2
      and entity_ref = '00000000-0000-4000-8000-0000000000a2'
      and row_to_json(event)::text not like '%private@example.test%'
    )
    from identity.read_audit_log(admin_session, 1, 'users.update', 'users', 0) as event
  ) is true, 'Audit reader exposed another institute or private values';
  assert not exists (
    select from identity.read_audit_log('00000000-0000-4000-8000-0000000000b2', null, null, null, 0)
  ), 'Audit reader accepts an unverified session';
  assert identity.create_bank_account(
    admin_session, '{"en":"Fixture account","ur":"آزمائشی اکاؤنٹ"}',
    'Fixture Bank', 'Fixture Institute', '000-123-456', null, null, array['general']
  ) = 'created', 'Verified administrator could not save a bank account';
  select id into strict fixture_bank from identity.read_bank_accounts(admin_session);
  assert not exists (
    select from public_api.institute_public where jsonb_array_length(bank_accounts) > 0
  ), 'Saving bank details made them public before confirmation';
  assert identity.create_bank_account(
    admin_session, '{"en":"Duplicate account","ur":"آزمائشی اکاؤنٹ"}',
    'fixture bank', 'Fixture Institute', '000123456', null, null, array['general']
  ) = 'duplicate', 'Duplicate account number passed validation';
  assert identity.set_bank_account_publication(admin_session, fixture_bank, true, false) = 'invalid',
    'Bank account can be published without confirmation';
  assert identity.set_bank_account_publication(admin_session, fixture_bank, true, true) = 'updated',
    'Verified administrator could not publish bank details';
  assert exists (
    select from public_api.institute_public where bank_accounts -> 0 ->> 'id' = fixture_bank::text
  ), 'Explicitly published account is missing from the public view';
  assert identity.set_bank_account_publication(admin_session, fixture_bank, false, false) = 'updated',
    'Verified administrator could not hide bank details';
  assert not exists (
    select from public_api.institute_public where jsonb_array_length(bank_accounts) > 0
  ), 'Hidden bank details are still public';
  assert not exists (
    select from identity.read_bank_accounts('00000000-0000-4000-8000-0000000000b2')
  ), 'Bank settings accept an unverified session';
  assert identity.update_staff_access(
    admin_session, '00000000-0000-4000-8000-0000000000b2',
    'active', array['teacher'], 'suspended', null
  ) = 'denied', 'An admin can suspend staff from another institute';
  assert identity.update_staff_access(
    admin_session, '00000000-0000-4000-8000-0000000000a2',
    'active', array['admin'], 'suspended', null
  ) = 'denied', 'The last admin can suspend their own account';
end
$test$;

do $test$
declare
  admin_session uuid := '00000000-0000-4000-8000-0000000000a3';
  saved_revision uuid;
  home_facts jsonb := '{
    "education":{"value":0,"label":{"en":"Students","ur":"طلبہ"}},
    "meals":{"value":140,"label":{"en":"Daily meals","ur":"روزانہ کھانے"}},
    "clinic":{"value":25,"label":{"en":"Daily patients","ur":"روزانہ مریض"}}
  }';
begin
  assert identity.save_site_page(
    admin_session, 'about', null, '{"en":"Fixture title","ur":"عنوان"}', '{"en":"Private draft","ur":"مسودہ"}'
  ) = 'saved', 'Admin could not save a draft for their institute';
  assert not exists (select from public_api.site_pages where slug = 'about'),
    'An unpublished draft is visible through the public view';
  select revision into saved_revision from identity.read_site_pages(admin_session) where slug = 'about';
  assert identity.publish_site_page(admin_session, 'about', saved_revision) = 'published',
    'Admin could not publish the saved draft';
  assert (
    select body ->> 'en' from public_api.site_pages where slug = 'about'
  ) = 'Private draft', 'Published content is missing from the public view';
  assert identity.publish_site_page(admin_session, 'about', saved_revision) = 'stale',
    'A superseded draft revision can be published again';

  assert identity.save_home_page(
    admin_session, null, '{"en":"Home","ur":"سرورق"}', '{"en":"Welcome","ur":"خوش آمدید"}',
    jsonb_set(home_facts, '{meals,value}', '2.5')
  ) = 'invalid', 'A fractional figure was accepted';
  assert identity.save_home_page(
    admin_session, null, '{"en":"Home","ur":"سرورق"}', '{"en":"Welcome","ur":"خوش آمدید"}', home_facts
  ) = 'saved', 'A valid fact draft was rejected';
  assert not exists (select from public_api.site_pages where slug = 'home'),
    'Unpublished homepage figures are visible';
  select revision into saved_revision from identity.read_site_pages(admin_session) where slug = 'home';
  assert identity.publish_site_page(admin_session, 'home', saved_revision) = 'published',
    'Homepage figures did not publish';
  select revision into saved_revision from identity.read_site_pages(admin_session) where slug = 'home';
  assert identity.save_site_page(
    admin_session, 'home', saved_revision, '{"en":"Updated Home","ur":"سرورق"}', '{"en":"Welcome","ur":"خوش آمدید"}'
  ) = 'saved', 'The text-only save stopped working';
  select revision into saved_revision from identity.read_site_pages(admin_session) where slug = 'home';
  assert identity.publish_site_page(admin_session, 'home', saved_revision) = 'published',
    'The text-only draft did not publish';
  assert (
    select facts from public_api.site_pages where slug = 'home'
  ) = home_facts, 'A text-only save lost the published figures';

  perform set_config('app.institute_id', '00000000-0000-4000-8000-0000000000b1', true);
  assert not exists (select from identity.read_site_pages(admin_session)),
    'Admin can read draft content from a different institute';
  assert not exists (select from public_api.site_pages where slug = 'about'),
    'Published content is visible under a different institute';
end
$test$;

rollback;
