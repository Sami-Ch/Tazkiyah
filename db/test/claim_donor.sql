-- Claiming guest donations and the donor's own row (04 §8.2, 06 §11.3,
-- P2-E5-T40).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a2000000-0000-4000-8000-000000000001', 'claim-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('a2000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'CLM');
insert into app.users (id, institute_id, email, full_name, status, email_verified) values
  ('a2000000-0000-4000-8000-000000000011', 'a2000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active', true),
  ('a2000000-0000-4000-8000-000000000021', 'a2000000-0000-4000-8000-000000000001', 'Guest@Example.test', 'Guest', 'active', false),
  ('a2000000-0000-4000-8000-000000000022', 'a2000000-0000-4000-8000-000000000001', 'other@example.test', 'Other', 'active', true),
  ('a2000000-0000-4000-8000-000000000023', 'a2000000-0000-4000-8000-000000000001', 'teacher@example.test', 'Teacher', 'active', true);
insert into app.user_roles (institute_id, user_id, role) values
  ('a2000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000011', 'admin'),
  ('a2000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000021', 'donor'),
  ('a2000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000022', 'donor'),
  ('a2000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000023', 'teacher');
-- A guest donor with the first account's email, a second guest, and the
-- second account's own donor row.
insert into app.donors (id, institute_id, email, legal_name, preferred_language, user_id) values
  ('a2000000-0000-4000-8000-000000000051', 'a2000000-0000-4000-8000-000000000001', 'guest@example.test',
    'Guest Legal', 'en', null),
  ('a2000000-0000-4000-8000-000000000052', 'a2000000-0000-4000-8000-000000000001', 'stranger@example.test',
    'Stranger Legal', 'en', null),
  ('a2000000-0000-4000-8000-000000000053', 'a2000000-0000-4000-8000-000000000001', 'old@example.test',
    null, 'en', 'a2000000-0000-4000-8000-000000000022');
insert into app.trail_links (institute_id, donor_id, token_hash, token_hint, created_by)
values ('a2000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000051',
  encode(sha256(convert_to(repeat('C', 43), 'UTF8')), 'hex'), 'CCCC', 'a2000000-0000-4000-8000-000000000011');
insert into app.media_assets (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes,
  width, height, status, uploaded_by) values
  ('a2000000-0000-4000-8000-000000000061', 'a2000000-0000-4000-8000-000000000001', 'image', 'donor_photo', 'public',
    'a2000000-0000-4000-8000-000000000001/me.webp', 'image/webp', 1000, 96, 96, 'ready',
    'a2000000-0000-4000-8000-000000000021'),
  ('a2000000-0000-4000-8000-000000000062', 'a2000000-0000-4000-8000-000000000001', 'image', 'receipt', 'public',
    'a2000000-0000-4000-8000-000000000001/receipt.webp', 'image/webp', 1000, 96, 96, 'ready',
    'a2000000-0000-4000-8000-000000000011');

do $test$
declare
  tenant constant uuid := 'a2000000-0000-4000-8000-000000000001';
  guest_account constant uuid := 'a2000000-0000-4000-8000-000000000021';
  guest_donor constant uuid := 'a2000000-0000-4000-8000-000000000051';
begin
  assert not has_function_privilege('tazkiyah_app', 'app.claim_donor_records()', 'EXECUTE');
  assert not has_function_privilege('tazkiyah_auth', 'app.claim_donor_records()', 'EXECUTE');
  assert not has_function_privilege('tazkiyah_auth', 'identity.donation_trail_page(uuid, timestamptz, uuid, text)', 'EXECUTE');
  perform set_config('app.institute_id', tenant::text, true);

  -- Only a donor account can claim, and only with a confirmed email.
  perform set_config('app.user_id', 'a2000000-0000-4000-8000-000000000023', true);
  begin
    perform app.claim_donor_records();
    assert false, 'a teacher account claimed donor records';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', guest_account::text, true);
  assert app.claim_donor_records() = 'unverified';
  assert (select user_id from app.donors where id = guest_donor) is null;

  -- Confirmed: the donor row with the same email, case and spaces aside, is claimed.
  update app.users set email_verified = true where id = guest_account;
  assert app.claim_donor_records() = 'claimed';
  assert (select (user_id, claimed_at is not null, email_verified_at is not null) = (guest_account, true, true)
    from app.donors where id = guest_donor);
  assert (select user_id from app.donors where id = 'a2000000-0000-4000-8000-000000000052') is null,
    'another guest was claimed';
  -- The private link is replaced by the account (06 §11.3).
  assert (select (revoked_at is not null, revoked_by, revoke_reason) = (true, guest_account, 'Claimed into an account')
    from app.trail_links where donor_id = guest_donor);
  assert exists (select from app.audit_log where action = 'donors.claimed' and entity_id = guest_donor::text);
  -- Nothing is left to claim.
  assert app.claim_donor_records() = 'none';

  -- An account that already has a donor row is not merged with a guest row.
  perform set_config('app.user_id', 'a2000000-0000-4000-8000-000000000022', true);
  update app.donors set email = null where id = 'a2000000-0000-4000-8000-000000000053';
  update app.users set email = 'stranger@example.test' where id = 'a2000000-0000-4000-8000-000000000022';
  assert app.claim_donor_records() = 'conflict';
  assert (select user_id from app.donors where id = 'a2000000-0000-4000-8000-000000000052') is null;
end
$test$;

-- The donor's own row, as tazkiyah_app.
set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a2000000-0000-4000-8000-000000000001';
  guest_donor constant uuid := 'a2000000-0000-4000-8000-000000000051';
  changed bigint;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', 'a2000000-0000-4000-8000-000000000021', true);
  assert (select array_agg(id) from app.donors) = array[guest_donor], 'a donor read rows not their own';
  assert (select legal_name from app.donors) = 'Guest Legal';

  update app.donors set display_name = 'Guest G.', profile_public = true,
    photo_media_id = 'a2000000-0000-4000-8000-000000000061',
    profile_links = '[{"label":"Site","url":"https://example.test"}]', preferred_language = 'ur';
  assert (select (display_name, profile_public, preferred_language) = ('Guest G.', true, 'ur') from app.donors);
  begin
    update app.donors set photo_media_id = 'a2000000-0000-4000-8000-000000000062';
    assert false, 'a receipt became a profile photo';
  exception when check_violation then null;
  end;
  begin
    update app.donors set legal_name = 'Changed';
    assert false, 'a donor changed a private field';
  exception when insufficient_privilege then null;
  end;
  begin
    update app.donors set email = 'new@example.test';
    assert false, 'a donor changed their email';
  exception when insufficient_privilege then null;
  end;
  -- Another donor's row cannot be changed.
  update app.donors set display_name = 'Hijack' where id = 'a2000000-0000-4000-8000-000000000052';
  get diagnostics changed = row_count;
  assert changed = 0, 'a donor changed another donor';

  -- Signed out, nothing is readable.
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.donors);
end
$test$;
