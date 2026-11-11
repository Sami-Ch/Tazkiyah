-- Consent records, their sign-offs, withdrawal and app.consent_active()
-- (04 §10, 07 §5, P3-E2-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a6000000-0000-4000-8000-000000000001', 'consent-fixture');
insert into app.users (id, institute_id, email, username, full_name, status, is_orphan) values
  ('a6000000-0000-4000-8000-000000000011', 'a6000000-0000-4000-8000-000000000001', 'principal@example.test', null, 'Principal', 'active', false),
  ('a6000000-0000-4000-8000-000000000012', 'a6000000-0000-4000-8000-000000000001', 'admin2@example.test', null, 'Second Admin', 'active', false),
  ('a6000000-0000-4000-8000-000000000021', 'a6000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active', false),
  ('a6000000-0000-4000-8000-000000000022', 'a6000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active', false),
  ('a6000000-0000-4000-8000-000000000041', 'a6000000-0000-4000-8000-000000000001', 'editor@example.test', null, 'Editor', 'active', false),
  ('a6000000-0000-4000-8000-000000000031', 'a6000000-0000-4000-8000-000000000001', null, 'cst-1', 'Student One', 'active', false),
  ('a6000000-0000-4000-8000-000000000032', 'a6000000-0000-4000-8000-000000000001', null, 'cst-2', 'Orphan Two', 'active', true);
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, principal_user_id)
values ('a6000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'CON',
  'a6000000-0000-4000-8000-000000000011');
insert into app.user_roles (institute_id, user_id, role) values
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000011', 'admin'),
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000012', 'admin'),
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000021', 'teacher'),
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000022', 'teacher'),
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000041', 'editor'),
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000031', 'student'),
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000032', 'student');
insert into app.classes (id, institute_id, name, created_by)
values ('a6000000-0000-4000-8000-000000000051', 'a6000000-0000-4000-8000-000000000001', '{"en":"Hifz"}',
  'a6000000-0000-4000-8000-000000000021');
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000051', 'a6000000-0000-4000-8000-000000000031', 'student'),
  ('a6000000-0000-4000-8000-000000000001', 'a6000000-0000-4000-8000-000000000051', 'a6000000-0000-4000-8000-000000000032', 'student');
insert into app.media_assets
  (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, status, uploaded_by)
values
  ('a6000000-0000-4000-8000-000000000071', 'a6000000-0000-4000-8000-000000000001', 'document', 'consent_form', 'private',
    'a6000000-0000-4000-8000-000000000001/form.pdf', 'application/pdf', 1000, 'ready', 'a6000000-0000-4000-8000-000000000021'),
  ('a6000000-0000-4000-8000-000000000072', 'a6000000-0000-4000-8000-000000000001', 'image', 'post', 'private',
    'a6000000-0000-4000-8000-000000000001/post.webp', 'image/webp', 1000, 'ready', 'a6000000-0000-4000-8000-000000000021');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a6000000-0000-4000-8000-000000000001';
  principal constant text := 'a6000000-0000-4000-8000-000000000011';
  admin2 constant text := 'a6000000-0000-4000-8000-000000000012';
  t1 constant uuid := 'a6000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'a6000000-0000-4000-8000-000000000022';
  editor constant uuid := 'a6000000-0000-4000-8000-000000000041';
  s1 constant uuid := 'a6000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'a6000000-0000-4000-8000-000000000032';
  work1 constant uuid := 'a6000000-0000-4000-8000-000000000081';
  name2 constant uuid := 'a6000000-0000-4000-8000-000000000082';
  changed bigint;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- The student's teacher records consent on the light form; it is active at once.
  perform set_config('app.user_id', t1::text, true);
  insert into app.consent_records (id, institute_id, student_user_id, kind, guardian_name, guardian_relation,
    method, given_on, form_media_id, recorded_by)
  values (work1, tenant, s1, 'public_work', 'Muhammad Aslam', 'father', 'paper_form', current_date - 1,
    'a6000000-0000-4000-8000-000000000071', t1);
  assert app.consent_status(work1) = 'active';
  assert app.sign_consent(work1) = 'not_needed', 'a non-orphan record asked for sign-offs';

  -- Bad records are refused.
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
      method, given_on, recorded_by, principal_signed_by, principal_signed_at)
    values (tenant, s2, 'public_work', 'Guardian', 'guardian', 'in_person', current_date, t1, t1, now());
    assert false, 'a record arrived already signed';
  exception when check_violation then null;
  end;
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
      method, given_on, recorded_by)
    values (tenant, s1, 'real_name', 'Guardian', 'mother', 'phone', current_date + 2, t1);
    assert false, 'consent was dated in the future';
  exception when check_violation then null;
  end;
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
      method, given_on, form_media_id, recorded_by)
    values (tenant, s1, 'real_name', 'Guardian', 'mother', 'phone', current_date,
      'a6000000-0000-4000-8000-000000000072', t1);
    assert false, 'a post image became a consent form';
  exception when check_violation then null;
  end;
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
      method, given_on, recorded_by)
    values (tenant, s1, 'orphan_full_profile', 'Guardian', 'mother', 'phone', current_date, t1);
    assert false, 'full-profile consent was recorded without a sponsorship';
  exception when check_violation or insufficient_privilege then null;
  end;
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
      method, given_on, recorded_by)
    values (tenant, s1, 'real_name', 'Guardian', 'mother', 'phone', current_date, editor);
    assert false, 'a record named someone else as its recorder';
  exception when insufficient_privilege then null;
  end;
  begin
    update app.consent_records set guardian_name = 'Changed' where id = work1;
    assert false, 'a consent record was edited directly';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from app.consent_records where id = work1;
    assert false, 'a consent record was deleted';
  exception when insufficient_privilege then null;
  end;

  -- An unrelated teacher, an editor and the student see and record nothing.
  foreach changed in array array[1, 2, 3] loop
    perform set_config('app.user_id', (array[t2, editor, s1])[changed]::text, true);
    assert not exists (select from app.consent_records), 'consent records leaked';
    assert app.consent_status(work1) is null, 'a consent status leaked';
    begin
      insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
        method, given_on, recorded_by)
      values (tenant, s1, 'real_name', 'Guardian', 'mother', 'phone', current_date, (array[t2, editor, s1])[changed]);
      assert false, 'consent was recorded by someone who does not teach the student';
    exception when insufficient_privilege then null;
    end;
  end loop;
  assert app.withdraw_consent(work1, 'asked') = 'denied', 'an unrelated person withdrew consent';

  -- An orphan's record needs the principal, then the assigned teacher (07 §5.4).
  perform set_config('app.user_id', t1::text, true);
  insert into app.consent_records (id, institute_id, student_user_id, kind, guardian_name, guardian_relation,
    method, given_on, recorded_by)
  values (name2, tenant, s2, 'real_name', 'Principal', 'guardian', 'in_person', current_date, t1);
  assert app.consent_status(name2) = 'pending';
  assert app.sign_consent(name2) = 'denied', 'a teacher signed for the principal';
  assert app.assign_second_signer(name2, t2) = 'denied', 'a teacher assigned the second sign-off';
  perform set_config('app.user_id', admin2, true);
  assert app.sign_consent(name2) = 'denied', 'an admin who is not the principal signed';
  perform set_config('app.user_id', principal, true);
  assert app.assign_second_signer(name2, principal::uuid) = 'invalid', 'the principal assigned themself';
  assert app.assign_second_signer(name2, editor) = 'invalid', 'a non-teacher was assigned';
  assert app.assign_second_signer(name2, t1) = 'assigned';
  -- The assigned teacher cannot sign before the principal.
  perform set_config('app.user_id', t1::text, true);
  assert app.sign_consent(name2) = 'denied', 'the second sign-off came before the principal''s';
  perform set_config('app.user_id', principal, true);
  assert app.sign_consent(name2) = 'principal_signed';
  assert app.consent_status(name2) = 'pending', 'one sign-off made an orphan''s consent active';
  -- The assignment may still change; the new teacher now reads the record.
  assert app.assign_second_signer(name2, t2) = 'assigned';
  perform set_config('app.user_id', t1::text, true);
  assert app.sign_consent(name2) = 'denied', 'a replaced signer still signed';
  perform set_config('app.user_id', t2::text, true);
  assert (select count(*) from app.consent_records) = 1, 'the assigned teacher cannot see the record';
  assert app.sign_consent(name2) = 'second_signed';
  assert app.consent_status(name2) = 'active';
  assert app.sign_consent(name2) = 'already_signed';
  perform set_config('app.user_id', principal, true);
  assert app.assign_second_signer(name2, t1) = 'already_signed', 'the signer changed after signing';
  assert app.assign_second_signer(work1, t1) = 'not_needed';

  -- Withdrawal is recorded once, with a reason, by the student's teacher or a signer.
  perform set_config('app.user_id', t1::text, true);
  assert app.withdraw_consent(work1, '  ') = 'invalid';
  assert app.withdraw_consent(work1, 'Father phoned') = 'withdrawn_now';
  assert app.withdraw_consent(work1, 'Again') = 'withdrawn';
  assert app.consent_status(work1) = 'withdrawn';
  perform set_config('app.user_id', t2::text, true);
  assert app.withdraw_consent(name2, 'Guardian asked') = 'withdrawn_now', 'the second signer could not withdraw';
  assert app.sign_consent(name2) = 'withdrawn';
end
$test$;

-- Checks that run as the owner: the mutability rule holds even without the
-- grants, and app.consent_active() reads live state.
reset role;
set local role tazkiyah_schema_owner;
do $test$
declare
  tenant constant uuid := 'a6000000-0000-4000-8000-000000000001';
  s1 constant uuid := 'a6000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'a6000000-0000-4000-8000-000000000032';
  face1 constant uuid := 'a6000000-0000-4000-8000-000000000083';
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', 'a6000000-0000-4000-8000-000000000021', true);
  begin
    update app.consent_records set withdrawn_at = null, withdrawn_by = null, withdrawal_reason = null
    where id = 'a6000000-0000-4000-8000-000000000081';
    assert false, 'a withdrawal was cleared';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.consent_records set kind = 'real_name' where id = 'a6000000-0000-4000-8000-000000000082';
    assert false, 'a consent record changed its kind';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    delete from app.consent_records where id = 'a6000000-0000-4000-8000-000000000082';
    assert false, 'the owner deleted a consent record';
  exception when insufficient_privilege then null;
  end;

  assert not app.consent_active(s1, 'public_work'), 'withdrawn consent is still active';
  assert not app.consent_active(s2, 'real_name'), 'withdrawn orphan consent is still active';
  assert not app.consent_active(s1, 'real_name'), 'consent of one kind counted for another';

  -- A student marked as an orphan later needs both sign-offs on existing records.
  insert into app.consent_records (id, institute_id, student_user_id, kind, guardian_name, guardian_relation,
    method, given_on, recorded_by)
  values (face1, tenant, s1, 'face', 'Muhammad Aslam', 'father', 'in_person', current_date,
    'a6000000-0000-4000-8000-000000000021');
  assert app.consent_active(s1, 'face');
  update app.users set is_orphan = true where id = s1;
  assert not app.consent_active(s1, 'face'), 'a new orphan kept consent with no sign-offs';
  update app.users set is_orphan = false where id = s1;

  -- Every step is audited, and the guardian's name never reaches the log.
  assert (select count(*) from app.audit_log where institute_id = tenant and entity_table = 'consent_records'
    and action = 'consent_records.update') >= 6, 'consent steps were not audited';
  assert not exists (select from app.audit_log where institute_id = tenant and changes::text ~ 'Aslam|phoned'),
    'the audit log holds a guardian''s name or a withdrawal reason';
end
$test$;
