-- 04 §8.6 trail links (P1-E3-T44): token hint, revocation reason, the
-- set-once guard, app.use_trail_token(), app.my_donor_ids() and the donor's
-- own-row read policy.
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('94000000-0000-4000-8000-000000000001', 'links-fixture-a'),
  ('94000000-0000-4000-8000-000000000002', 'links-fixture-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix) values
  ('94000000-0000-4000-8000-000000000001', '{"en":"A"}', '{"en":"A"}', '{}', 'LNKA'),
  ('94000000-0000-4000-8000-000000000002', '{"en":"B"}', '{"en":"B"}', '{}', 'LNKB');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('94000000-0000-4000-8000-000000000011', '94000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active', true, false),
  ('94000000-0000-4000-8000-000000000012', '94000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active', true, false),
  ('94000000-0000-4000-8000-000000000013', '94000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active', true, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('94000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000011', 'admin'),
  ('94000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000012', 'editor'),
  ('94000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000013', 'finance_officer');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
values ('94000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000011', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at)
values ('94000000-0000-4000-8000-000000000021', '94000000-0000-4000-8000-000000000001',
  '94000000-0000-4000-8000-000000000011', 'links-admin', now() + interval '1 hour', now(), now());
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('94000000-0000-4000-8000-000000000031', '94000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.donors (id, institute_id, email, preferred_language) values
  ('94000000-0000-4000-8000-000000000051', '94000000-0000-4000-8000-000000000001', 'one@example.test', 'en'),
  ('94000000-0000-4000-8000-000000000052', '94000000-0000-4000-8000-000000000001', 'two@example.test', 'en'),
  ('94000000-0000-4000-8000-000000000053', '94000000-0000-4000-8000-000000000002', 'one@example.test', 'en');
insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
  amount_minor, amount_paisa, donation_type, donor_id, receipt_number, receipt_locale, recorded_by)
values ('94000000-0000-4000-8000-000000000001', gen_random_uuid(), '94000000-0000-4000-8000-000000000031',
  'one', date '2026-11-01', 10000, 10000, 'general', '94000000-0000-4000-8000-000000000051',
  'LNKA-2026-00001', 'en', '94000000-0000-4000-8000-000000000011');
-- Donor two holds a live link, and donor B in the other institute holds a
-- link whose token is the same as donor one's will be.
insert into app.trail_links (institute_id, donor_id, token_hash, token_hint, created_by) values
  ('94000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000052',
    encode(sha256(convert_to(repeat('T', 43), 'UTF8')), 'hex'), 'TTTT', '94000000-0000-4000-8000-000000000011');

-- Issue and revoke through the admin functions: hint and reason are stored.
reset role;
set local role tazkiyah_auth;
do $test$
declare
  token constant text := repeat('O', 39) || 'Ab-_';
  admin_session constant uuid := '94000000-0000-4000-8000-000000000021';
begin
  perform set_config('app.institute_id', '94000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '94000000-0000-4000-8000-000000000011', true);
  assert identity.issue_trail_link(admin_session, 'LNKA-2026-00001', 'one@example.test',
    encode(sha256(convert_to(token, 'UTF8')), 'hex'), 'bad hint') = 'invalid';
  assert identity.issue_trail_link(admin_session, 'LNKA-2026-00001', 'one@example.test',
    repeat('e', 64), 'eeee') = 'issued';
  assert identity.issue_trail_link(admin_session, 'LNKA-2026-00001', 'one@example.test',
    encode(sha256(convert_to(token, 'UTF8')), 'hex'), right(token, 4)) = 'issued';
  assert identity.revoke_trail_link(admin_session, 'LNKA-2026-00001', repeat('x', 201)) = 'invalid';
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
do $test$
begin
  assert (select revoke_reason from app.trail_links where token_hash = repeat('e', 64)) = 'Replaced by a new link';
  assert (select token_hint from app.trail_links
    where donor_id = '94000000-0000-4000-8000-000000000051' and revoked_at is null) = 'Ab-_';
  insert into app.trail_links (institute_id, donor_id, token_hash, token_hint, created_by)
  values ('94000000-0000-4000-8000-000000000002', '94000000-0000-4000-8000-000000000053',
    encode(sha256(convert_to(repeat('B', 43), 'UTF8')), 'hex'), 'BBBB',
    (select id from app.users where institute_id = '94000000-0000-4000-8000-000000000001' limit 1));
  assert false, 'a link was created by a user of another institute';
exception when foreign_key_violation then null;
end
$test$;

-- Resolving a token.
reset role;
set local role tazkiyah_app;
do $test$
declare
  one_token constant text := repeat('O', 39) || 'Ab-_';
  two_token constant text := repeat('T', 43);
  first_use timestamptz;
begin
  perform set_config('app.institute_id', '94000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '', true);
  assert app.use_trail_token('not a token') is null and app.current_trail_donor_id() is null;
  assert app.use_trail_token(repeat('Z', 43)) is null;
  assert app.use_trail_token(two_token) = '94000000-0000-4000-8000-000000000052';
  assert app.current_trail_donor_id() = '94000000-0000-4000-8000-000000000052';
  -- A failed lookup clears an earlier donor.
  assert app.use_trail_token(repeat('Z', 43)) is null and app.current_trail_donor_id() is null;

  assert app.use_trail_token(one_token) = '94000000-0000-4000-8000-000000000051';
  assert (select array_agg(id) from app.my_donor_ids() as t(id)) = array['94000000-0000-4000-8000-000000000051'::uuid];

  -- The donor reads their own links' metadata only, never the hash.
  assert (select count(*) from app.trail_links) = 2, 'the donor should see their live and replaced links';
  assert not exists (select from app.trail_links where donor_id <> '94000000-0000-4000-8000-000000000051');
  first_use := (select last_used_at from app.trail_links where revoked_at is null);
  assert first_use is not null;
  begin
    perform token_hash from app.trail_links;
    assert false, 'the hash was readable';
  exception when insufficient_privilege then null;
  end;
  -- Last use is written at most once an hour.
  perform app.use_trail_token(one_token);
  assert (select last_used_at from app.trail_links where revoked_at is null) = first_use;

  -- A token from this institute opens nothing in the other one.
  perform set_config('app.institute_id', '94000000-0000-4000-8000-000000000002', true);
  assert app.use_trail_token(one_token) is null;
  assert not exists (select from app.my_donor_ids());

  -- A forged trail donor id without a live link gives nothing.
  perform set_config('app.institute_id', '94000000-0000-4000-8000-000000000001', true);
  perform set_config('app.trail_donor_id', '94000000-0000-4000-8000-000000000053', true);
  assert not exists (select from app.my_donor_ids());
  assert not exists (select from app.trail_links);

  -- Staff: admin and finance see every link; an editor sees none.
  perform set_config('app.trail_donor_id', '', true);
  perform set_config('app.user_id', '94000000-0000-4000-8000-000000000011', true);
  assert (select count(*) from app.trail_links) = 3;
  perform set_config('app.user_id', '94000000-0000-4000-8000-000000000013', true);
  assert (select count(*) from app.trail_links) = 3;
  perform set_config('app.user_id', '94000000-0000-4000-8000-000000000012', true);
  assert not exists (select from app.trail_links);
end
$test$;

-- Revocation works at once and only once; nothing else about a link changes.
reset role;
set local role tazkiyah_auth;
do $test$
begin
  perform set_config('app.institute_id', '94000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '94000000-0000-4000-8000-000000000011', true);
  assert identity.revoke_trail_link('94000000-0000-4000-8000-000000000021', 'LNKA-2026-00001',
    ' Donor reported a lost phone ') = 'revoked';
  perform set_config('app.user_id', '', true);
  assert app.use_trail_token(repeat('O', 39) || 'Ab-_') is null;
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
do $test$
declare
  revoked_link uuid;
  live_link uuid;
begin
  select id into strict revoked_link from app.trail_links
  where donor_id = '94000000-0000-4000-8000-000000000051' and revoke_reason = 'Donor reported a lost phone';
  select id into strict live_link from app.trail_links where donor_id = '94000000-0000-4000-8000-000000000052';
  begin
    update app.trail_links set revoked_at = null, revoked_by = null, revoke_reason = null where id = revoked_link;
    assert false, 'a revocation was cleared';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.trail_links set revoke_reason = 'Changed later' where id = revoked_link;
    assert false, 'a revocation reason was rewritten';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.trail_links set token_hash = repeat('f', 64) where id = live_link;
    assert false, 'a token hash was replaced';
  exception when object_not_in_prerequisite_state then null;
  end;
  update app.trail_links set last_used_at = now() where id = live_link;
  begin
    update app.trail_links set last_used_at = now() - interval '1 day' where id = live_link;
    assert false, 'last use moved backwards';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.trail_links set revoke_reason = 'No revocation' where id = live_link;
    assert false, 'a reason was set on a live link';
  exception when check_violation then null;
  end;
end
$test$;
