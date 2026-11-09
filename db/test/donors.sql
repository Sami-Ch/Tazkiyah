-- Donor rows (04 §8.2, P1-E3-T40): profile shape, erasure, claiming and
-- reminder evidence, audit redaction and no direct runtime access.
begin;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('15000000-0000-4000-8000-000000000001', 'donor-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('15000000-0000-4000-8000-000000000001', '{"en":"Donor institute"}', '{"en":"Address"}', '{}', 'DON');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password)
values ('15000000-0000-4000-8000-000000000011', '15000000-0000-4000-8000-000000000001',
  'donor-admin@example.test', 'Donor admin', 'active', true, false);
insert into app.user_roles (institute_id, user_id, role)
values ('15000000-0000-4000-8000-000000000001', '15000000-0000-4000-8000-000000000011', 'admin');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
values ('15000000-0000-4000-8000-000000000001', '15000000-0000-4000-8000-000000000011', 's', 'c', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, two_factor_verified_at)
values ('15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000001',
  '15000000-0000-4000-8000-000000000011', 'donor-admin', now() + interval '1 hour', now());
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('15000000-0000-4000-8000-000000000031', '15000000-0000-4000-8000-000000000001',
  '{"en":"Account"}', 'Bank', 'Title', 'donor-account');

reset role;
set local role tazkiyah_auth;
do $test$
begin
  perform set_config('app.institute_id', '15000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '15000000-0000-4000-8000-000000000011', true);
  assert (select code from identity.record_manual_donation(
    '15000000-0000-4000-8000-000000000021', gen_random_uuid(), '15000000-0000-4000-8000-000000000031',
    'donor-ref', (now() at time zone 'Asia/Karachi')::date, 10000, 'general', null,
    'Private.Donor@Example.test', 'ur', true, false, true
  )) = 'recorded', 'Fixture donation was not recorded';
end
$test$;

reset role;
do $test$
declare
  donor uuid;
  audit text;
begin
  select id into strict donor from app.donors where email = 'private.donor@example.test';
  assert (select kind = 'person' and not profile_public and not reminder_opt_in and profile_links = '[]'
    from app.donors where id = donor), 'New donor defaults do not match 04 §8.2';

  select string_agg(a::text, ' ') into audit from app.audit_log a
  where a.entity_table = 'donors' and a.entity_id = donor::text;
  assert audit like '%donors.insert%', 'Recording a donor was not audited';
  assert audit not like '%private.donor%', 'The audit log holds a donor email';

  for bad in 1..4 loop
    begin
      update app.donors set profile_links = case bad
        when 1 then (select jsonb_agg(jsonb_build_object('label', 'L' || n, 'url', 'https://example.test/' || n))
                     from generate_series(1, 6) n)
        when 2 then '[{"label":"Site","url":"http://example.test"}]'
        when 3 then '[{"label":"Site","url":"https://example.test","extra":1}]'
        else '[{"label":"","url":"https://example.test"}]'
      end where id = donor;
      raise exception 'Invalid profile links % were accepted', bad;
    exception when check_violation then null;
    end;
  end loop;
  update app.donors set profile_links = '[{"label":"Site","url":"https://example.test/me"}]' where id = donor;

  begin
    update app.donors set reminder_opt_in = true where id = donor;
    raise exception 'A reminder opt-in without its time was accepted';
  exception when check_violation then null;
  end;
  begin
    update app.donors set claimed_at = now() where id = donor;
    raise exception 'A claim without an account was accepted';
  exception when check_violation then null;
  end;
  begin
    update app.donors set erased_at = now() where id = donor;
    raise exception 'An erased donor kept personal fields';
  exception when check_violation then null;
  end;
  update app.donors set erased_at = now(), email = null, legal_name = null, phone = null,
    display_name = null, photo_media_id = null, profile_links = '[]', profile_public = false
  where id = donor;
end
$test$;

-- 04 §8.4: no runtime role reads donors directly.
do $test$
begin
  assert not has_table_privilege('tazkiyah_app', 'app.donors', 'SELECT, INSERT, UPDATE, DELETE'),
    'The application role can reach donors directly';
  assert not has_table_privilege('tazkiyah_auth', 'app.donors', 'SELECT, INSERT, UPDATE, DELETE'),
    'The auth role can reach donors directly';
end
$test$;

rollback;
