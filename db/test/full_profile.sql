-- Full-profile consent for one sponsorship: the principal opens it, assigns
-- the second sign-off to a teacher, both sign in either order, and the
-- sponsor's view shows the full profile only while it is active (04 §10.1,
-- §10.2, 06 §12.4, REQ-ORP-003 to REQ-ORP-006, P4-E2-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('af000000-0000-4000-8000-000000000001', 'full-profile-fixture');
insert into app.users (id, institute_id, email, username, full_name, status, is_orphan, date_of_birth) values
  ('af000000-0000-4000-8000-000000000011', 'af000000-0000-4000-8000-000000000001', 'principal@example.test', null, 'Principal', 'active', false, null),
  ('af000000-0000-4000-8000-000000000012', 'af000000-0000-4000-8000-000000000001', 'admin2@example.test', null, 'Second Admin', 'active', false, null),
  ('af000000-0000-4000-8000-000000000021', 'af000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active', false, null),
  ('af000000-0000-4000-8000-000000000022', 'af000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active', false, null),
  ('af000000-0000-4000-8000-000000000081', 'af000000-0000-4000-8000-000000000001', 'd1@example.test', null, 'Donor One', 'active', false, null),
  ('af000000-0000-4000-8000-000000000082', 'af000000-0000-4000-8000-000000000001', 'd2@example.test', null, 'Donor Two', 'active', false, null),
  ('af000000-0000-4000-8000-000000000031', 'af000000-0000-4000-8000-000000000001', null, 'fp-1', 'Ayesha Khan', 'active', true, date '2014-06-15'),
  ('af000000-0000-4000-8000-000000000032', 'af000000-0000-4000-8000-000000000001', null, 'fp-2', 'Student Two', 'active', true, date '2013-01-01');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules, principal_user_id)
values ('af000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'FPR',
  array['student_hub'], 'af000000-0000-4000-8000-000000000011');
insert into app.user_roles (institute_id, user_id, role)
select 'af000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('af000000-0000-4000-8000-000000000011', 'admin'), ('af000000-0000-4000-8000-000000000012', 'admin'),
  ('af000000-0000-4000-8000-000000000021', 'teacher'), ('af000000-0000-4000-8000-000000000022', 'teacher'),
  ('af000000-0000-4000-8000-000000000081', 'donor'), ('af000000-0000-4000-8000-000000000082', 'donor'),
  ('af000000-0000-4000-8000-000000000031', 'student'), ('af000000-0000-4000-8000-000000000032', 'student')) r(id, role);
insert into app.classes (id, institute_id, name, created_by) values
  ('af000000-0000-4000-8000-000000000051', 'af000000-0000-4000-8000-000000000001', '{"en":"Hifz A"}', 'af000000-0000-4000-8000-000000000021'),
  ('af000000-0000-4000-8000-000000000052', 'af000000-0000-4000-8000-000000000001', '{"en":"Old class"}', 'af000000-0000-4000-8000-000000000021');
insert into app.class_members (institute_id, class_id, user_id, member_role, ended_at) values
  ('af000000-0000-4000-8000-000000000001', 'af000000-0000-4000-8000-000000000051', 'af000000-0000-4000-8000-000000000031', 'student', null),
  ('af000000-0000-4000-8000-000000000001', 'af000000-0000-4000-8000-000000000052', 'af000000-0000-4000-8000-000000000031', 'student', now()),
  ('af000000-0000-4000-8000-000000000001', 'af000000-0000-4000-8000-000000000051', 'af000000-0000-4000-8000-000000000032', 'student', null);
insert into app.personas (id, institute_id, display_name) values
  ('af000000-0000-4000-8000-000000000061', 'af000000-0000-4000-8000-000000000001', 'Sitara 901'),
  ('af000000-0000-4000-8000-000000000062', 'af000000-0000-4000-8000-000000000001', 'Qalam 902');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('af000000-0000-4000-8000-000000000001', 'af000000-0000-4000-8000-000000000061', 'af000000-0000-4000-8000-000000000031', 'af000000-0000-4000-8000-000000000021'),
  ('af000000-0000-4000-8000-000000000001', 'af000000-0000-4000-8000-000000000062', 'af000000-0000-4000-8000-000000000032', 'af000000-0000-4000-8000-000000000021');
insert into app.donors (id, institute_id, email, user_id, email_verified_at, claimed_at) values
  ('af000000-0000-4000-8000-000000000091', 'af000000-0000-4000-8000-000000000001', 'd1@example.test', 'af000000-0000-4000-8000-000000000081', now(), now()),
  ('af000000-0000-4000-8000-000000000092', 'af000000-0000-4000-8000-000000000001', 'd2@example.test', 'af000000-0000-4000-8000-000000000082', now(), now());
insert into app.causes (id, institute_id, slug, cause_type, title, summary, status, target_period) values
  ('af000000-0000-4000-8000-000000000041', 'af000000-0000-4000-8000-000000000001', 'orphan-sponsorship', 'ongoing',
    '{"en":"Orphan sponsorship"}', '{"en":"Care for the children"}', 'active', 'monthly');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'af000000-0000-4000-8000-000000000001';
  principal constant uuid := 'af000000-0000-4000-8000-000000000011';
  admin2 constant uuid := 'af000000-0000-4000-8000-000000000012';
  t1 constant uuid := 'af000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'af000000-0000-4000-8000-000000000022';
  d1 constant uuid := 'af000000-0000-4000-8000-000000000081';
  d2 constant uuid := 'af000000-0000-4000-8000-000000000082';
  s1 constant uuid := 'af000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'af000000-0000-4000-8000-000000000032';
  child constant uuid := 'af000000-0000-4000-8000-000000000061';
  other_child constant uuid := 'af000000-0000-4000-8000-000000000062';
  donor1 constant uuid := 'af000000-0000-4000-8000-000000000091';
  donor2 constant uuid := 'af000000-0000-4000-8000-000000000092';
  cause constant uuid := 'af000000-0000-4000-8000-000000000041';
  sponsorship uuid;
  other_sponsorship uuid;
  later_sponsorship uuid;
  consent uuid;
  second_consent uuid;
  seen record;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', principal::text, true);
  insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
  values (tenant, donor1, child, cause, principal) returning id into sponsorship;
  insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
  values (tenant, donor2, other_child, cause, principal) returning id into other_sponsorship;

  -- By default the sponsor sees no full profile (REQ-ORP-002).
  perform set_config('app.user_id', d1::text, true);
  select * into strict seen from app.sponsor_child_view();
  assert not seen.full_profile and seen.full_name is null and seen.photo_media_id is null and seen.class_names is null,
    'the full profile showed without consent: ' || row_to_json(seen)::text;

  -- Only the principal, as the orphans' guardian, opens the record (06 §12.4).
  perform set_config('app.user_id', t1::text, true);
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, sponsorship_id, guardian_name,
      guardian_relation, method, given_on, recorded_by)
    values (tenant, s1, 'orphan_full_profile', sponsorship, 'Principal', 'guardian', 'in_person', current_date, t1);
    assert false, 'a teacher opened full-profile consent';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', admin2::text, true);
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, sponsorship_id, guardian_name,
      guardian_relation, method, given_on, recorded_by)
    values (tenant, s1, 'orphan_full_profile', sponsorship, 'Principal', 'guardian', 'in_person', current_date, admin2);
    assert false, 'an admin who is not the principal opened full-profile consent';
  exception when insufficient_privilege then null;
  end;

  -- The record is for one sponsorship of that child (REQ-ORP-005).
  perform set_config('app.user_id', principal::text, true);
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, sponsorship_id, guardian_name,
      guardian_relation, method, given_on, recorded_by)
    values (tenant, s2, 'orphan_full_profile', sponsorship, 'Principal', 'guardian', 'in_person', current_date, principal);
    assert false, 'consent named a sponsorship of another child';
  exception when check_violation then null;
  end;
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, guardian_name,
      guardian_relation, method, given_on, recorded_by)
    values (tenant, s1, 'orphan_full_profile', 'Principal', 'guardian', 'in_person', current_date, principal);
    assert false, 'full-profile consent without a sponsorship';
  exception when check_violation then null;
  end;
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, sponsorship_id, guardian_name,
      guardian_relation, method, given_on, recorded_by)
    values (tenant, s1, 'public_work', sponsorship, 'Principal', 'guardian', 'in_person', current_date, principal);
    assert false, 'another kind of consent named a sponsorship';
  exception when check_violation then null;
  end;
  insert into app.consent_records (institute_id, student_user_id, kind, sponsorship_id, guardian_name,
    guardian_relation, method, given_on, recorded_by)
  values (tenant, s1, 'orphan_full_profile', sponsorship, 'Principal', 'guardian', 'in_person', current_date, principal)
  returning id into consent;
  assert app.consent_status(consent) = 'pending', 'a new full-profile record is not pending';
  begin
    update app.consent_records set sponsorship_id = other_sponsorship where id = consent;
    assert false, 'the sponsorship of a consent record changed';
  exception when insufficient_privilege or object_not_in_prerequisite_state then null;
  end;

  -- The principal assigns any teacher but themself (REQ-ORP-004).
  assert app.assign_second_signer(consent, principal) = 'invalid', 'the principal assigned themself';
  perform set_config('app.user_id', t1::text, true);
  assert app.assign_second_signer(consent, t1) = 'denied', 'a teacher assigned the second sign-off';
  assert app.sign_consent(consent) = 'denied', 'an unassigned teacher signed';
  perform set_config('app.user_id', principal::text, true);
  assert app.assign_second_signer(consent, t1) = 'assigned', 'the principal could not assign a teacher';

  -- Sign-offs come in either order: the teacher first (06 §12.4).
  perform set_config('app.user_id', t2::text, true);
  assert app.sign_consent(consent) = 'denied', 'a teacher who was not assigned signed';
  perform set_config('app.user_id', t1::text, true);
  assert app.sign_consent(consent) = 'second_signed', 'the assigned teacher could not sign first';
  assert app.sign_consent(consent) = 'denied', 'the teacher signed twice';
  assert app.consent_status(consent) = 'pending', 'one sign-off made the consent active';
  perform set_config('app.user_id', d1::text, true);
  assert not (select full_profile from app.sponsor_child_view()), 'one sign-off showed the full profile';
  perform set_config('app.user_id', principal::text, true);
  assert app.assign_second_signer(consent, t2) = 'already_signed', 'the signer changed after signing';
  assert app.sign_consent(consent) = 'principal_signed', 'the principal could not sign';
  assert app.sign_consent(consent) = 'already_signed', 'a signed record was signed again';
  assert app.consent_status(consent) = 'active', 'two sign-offs did not make the consent active';
  set local role tazkiyah_schema_owner;
  assert app.consent_active(s1, 'orphan_full_profile'), 'consent_active disagrees with the status';
  set local role tazkiyah_app;

  -- The matched sponsor now sees the full profile (REQ-ORP-003).
  perform set_config('app.user_id', d1::text, true);
  select * into strict seen from app.sponsor_child_view();
  assert seen.full_profile and seen.full_name = 'Ayesha Khan' and seen.class_names = '[{"en":"Hifz A"}]'
    and seen.persona_name = 'Sitara 901', 'the full profile is wrong: ' || row_to_json(seen)::text;
  -- Nobody else does, and the sponsor reads no consent record (REQ-ORP-005).
  assert not exists (select from app.consent_records), 'the sponsor read a consent record';
  perform set_config('app.user_id', d2::text, true);
  select * into strict seen from app.sponsor_child_view();
  assert seen.persona_name = 'Qalam 902' and not seen.full_profile and seen.full_name is null,
    'another sponsor saw a full profile';
  assert (select string_agg(row_to_json(v)::text, ' ') from app.sponsor_child_view() v) !~ 'Ayesha',
    'another sponsor saw the child''s name';
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.sponsor_child_view()), 'a visitor got the sponsor view';

  -- A paused sponsorship shows nothing, and the consent counts again on resuming.
  perform set_config('app.user_id', principal::text, true);
  update app.sponsorships set status = 'paused' where id = sponsorship;
  assert app.consent_status(consent) = 'paused', 'a paused sponsorship did not pause the consent';
  set local role tazkiyah_schema_owner;
  assert not app.consent_active(s1, 'orphan_full_profile'), 'consent stayed active while paused';
  assert not app.full_profile_active(sponsorship), 'the full profile stayed active while paused';
  set local role tazkiyah_app;
  update app.sponsorships set status = 'active' where id = sponsorship;
  assert app.consent_status(consent) = 'active', 'the consent did not resume';

  -- Withdrawal hides the full profile at once (REQ-ORP-006).
  perform set_config('app.user_id', t1::text, true);
  assert app.withdraw_consent(consent, 'Guardian asked') = 'withdrawn_now', 'the assigned teacher could not withdraw';
  perform set_config('app.user_id', d1::text, true);
  select * into strict seen from app.sponsor_child_view();
  assert not seen.full_profile and seen.full_name is null and seen.class_names is null,
    'the full profile stayed after withdrawal';
  perform set_config('app.user_id', principal::text, true);
  assert app.consent_status(consent) = 'withdrawn', 'the status is not withdrawn';
  assert app.sign_consent(consent) = 'withdrawn', 'a withdrawn record was signed';

  -- Either signer may decline before both have signed (06 §12.4).
  insert into app.consent_records (institute_id, student_user_id, kind, sponsorship_id, guardian_name,
    guardian_relation, method, given_on, recorded_by)
  values (tenant, s1, 'orphan_full_profile', sponsorship, 'Principal', 'guardian', 'in_person', current_date, principal)
  returning id into second_consent;
  assert app.assign_second_signer(second_consent, t2) = 'assigned', 'the second record took no signer';
  assert app.sign_consent(second_consent) = 'principal_signed', 'the principal could not sign the second record';
  perform set_config('app.user_id', t2::text, true);
  assert app.withdraw_consent(second_consent, 'Not now') = 'withdrawn_now', 'the assigned teacher could not decline';
  perform set_config('app.user_id', principal::text, true);
  assert app.consent_status(second_consent) = 'declined', 'a refusal before both sign-offs is not declined';

  -- Ending the sponsorship ends the consent; a new sponsor of the same child
  -- starts with the default view (06 §12.1, REQ-ORP-005).
  insert into app.consent_records (institute_id, student_user_id, kind, sponsorship_id, guardian_name,
    guardian_relation, method, given_on, recorded_by)
  values (tenant, s1, 'orphan_full_profile', sponsorship, 'Principal', 'guardian', 'in_person', current_date, principal)
  returning id into consent;
  perform app.assign_second_signer(consent, t1);
  perform app.sign_consent(consent);
  perform set_config('app.user_id', t1::text, true);
  perform app.sign_consent(consent);
  perform set_config('app.user_id', principal::text, true);
  assert app.consent_status(consent) = 'active', 'the third record is not active';
  update app.sponsorships set status = 'ended' where id = sponsorship;
  assert app.consent_status(consent) = 'ended', 'ending the sponsorship did not end the consent';
  update app.sponsorships set status = 'ended' where id = other_sponsorship;
  insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
  values (tenant, donor2, child, cause, principal) returning id into later_sponsorship;
  begin
    insert into app.consent_records (institute_id, student_user_id, kind, sponsorship_id, guardian_name,
      guardian_relation, method, given_on, recorded_by)
    values (tenant, s1, 'orphan_full_profile', sponsorship, 'Principal', 'guardian', 'in_person', current_date, principal);
    assert false, 'consent was opened for an ended sponsorship';
  exception when check_violation then null;
  end;
  set local role tazkiyah_schema_owner;
  assert not app.consent_active(s1, 'orphan_full_profile'), 'consent carried over to the new sponsor';
  set local role tazkiyah_app;
  perform set_config('app.user_id', d2::text, true);
  select * into strict seen from app.sponsor_child_view();
  assert seen.sponsorship_id = later_sponsorship and not seen.full_profile and seen.full_name is null,
    'the new sponsor inherited the old full profile';
end
$test$;

-- The runtime role cannot call the full-profile check directly.
do $test$
begin
  assert not has_function_privilege('tazkiyah_app', 'app.full_profile_active(uuid)', 'execute'),
    'the runtime role can call app.full_profile_active';
end
$test$;

rollback;
