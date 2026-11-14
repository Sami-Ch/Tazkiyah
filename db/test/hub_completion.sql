-- Persona profile, walkthrough, post types, polls, teacher review and alumni
-- (REQ-STU-002, REQ-STU-005, REQ-STU-007, REQ-STU-009, REQ-STU-010,
-- REQ-TCH-001 to REQ-TCH-004).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('c1600000-0000-4000-8000-000000000001', 'hub-completion'),
  ('c1600000-0000-4000-8000-000000000002', 'hub-completion-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules) values
  ('c1600000-0000-4000-8000-000000000001', '{"en":"Institute","ur":"ادارہ"}', '{"en":"A"}', '{}', 'HC',
    array['student_hub', 'teacher_hub']),
  ('c1600000-0000-4000-8000-000000000002', '{"en":"Other"}', '{"en":"B"}', '{}', 'HCB',
    array['student_hub', 'teacher_hub']);
insert into app.users (id, institute_id, email, full_name, status, must_change_password, two_factor_enabled) values
  ('c1600000-0000-4000-8000-000000000011', 'c1600000-0000-4000-8000-000000000001', 'admin@hub-completion.test', 'Admin One', 'active', false, true),
  ('c1600000-0000-4000-8000-000000000021', 'c1600000-0000-4000-8000-000000000001', 'teacher@hub-completion.test', 'Teacher One', 'active', false, false),
  ('c1600000-0000-4000-8000-000000000041', 'c1600000-0000-4000-8000-000000000001', 'editor@hub-completion.test', 'Editor One', 'active', false, false),
  ('c1600000-0000-4000-8000-000000000012', 'c1600000-0000-4000-8000-000000000002', 'admin@hub-completion-b.test', 'Other Admin', 'active', false, true);
insert into app.user_roles (institute_id, user_id, role) values
  ('c1600000-0000-4000-8000-000000000001', 'c1600000-0000-4000-8000-000000000011', 'admin'),
  ('c1600000-0000-4000-8000-000000000001', 'c1600000-0000-4000-8000-000000000021', 'teacher'),
  ('c1600000-0000-4000-8000-000000000001', 'c1600000-0000-4000-8000-000000000041', 'editor'),
  ('c1600000-0000-4000-8000-000000000002', 'c1600000-0000-4000-8000-000000000012', 'admin');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('c1600000-0000-4000-8000-000000000001', 'c1600000-0000-4000-8000-000000000011', 'secret', 'codes', true),
  ('c1600000-0000-4000-8000-000000000002', 'c1600000-0000-4000-8000-000000000012', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('c1600000-0000-4000-8000-000000000091', 'c1600000-0000-4000-8000-000000000001', 'c1600000-0000-4000-8000-000000000011', 'hc-admin', now() + interval '1 hour', now(), now()),
  ('c1600000-0000-4000-8000-000000000092', 'c1600000-0000-4000-8000-000000000001', 'c1600000-0000-4000-8000-000000000021', 'hc-teacher', now() + interval '1 hour', now(), null),
  ('c1600000-0000-4000-8000-000000000093', 'c1600000-0000-4000-8000-000000000001', 'c1600000-0000-4000-8000-000000000041', 'hc-editor', now() + interval '1 hour', now(), null),
  ('c1600000-0000-4000-8000-000000000094', 'c1600000-0000-4000-8000-000000000002', 'c1600000-0000-4000-8000-000000000012', 'hc-admin-b', now() + interval '1 hour', now(), now());

select set_config('app.institute_id', 'c1600000-0000-4000-8000-000000000001', true);
select set_config('app.user_id', 'c1600000-0000-4000-8000-000000000021', true);
insert into app.classes (id, institute_id, name, created_by) values
  ('c1600000-0000-4000-8000-000000000051', 'c1600000-0000-4000-8000-000000000001', '{"en":"Hifz","ur":"حفظ"}', 'c1600000-0000-4000-8000-000000000021');
select set_config('app.user_id', 'c1600000-0000-4000-8000-000000000011', true);
select app.create_student_account('Ahmed Raza', 'hc-student-1', 'c1600000-0000-4000-8000-000000000051', false);
select app.create_student_account('Sara Noor', 'hc-student-2', 'c1600000-0000-4000-8000-000000000051', false);
update app.users set must_change_password = false
where institute_id = 'c1600000-0000-4000-8000-000000000001' and username in ('hc-student-1', 'hc-student-2');
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at)
select ('c1600000-0000-4000-8000-0000000000' || case username when 'hc-student-1' then '81' else '82' end)::uuid,
  institute_id, id, username, now() + interval '1 day', now()
from app.users where username in ('hc-student-1', 'hc-student-2');

do $setup$
begin
  assert (select count(*) from app.users where username like 'hc-student-%') = 2, 'students were not created';
  assert (select count(*) from identity.sessions where token like 'hc-student-%') = 2, 'student sessions were not created';
end
$setup$;

do $test$
declare
  tenant constant uuid := 'c1600000-0000-4000-8000-000000000001';
  other constant uuid := 'c1600000-0000-4000-8000-000000000002';
  admin constant uuid := 'c1600000-0000-4000-8000-000000000011';
  teacher constant uuid := 'c1600000-0000-4000-8000-000000000021';
  editor constant uuid := 'c1600000-0000-4000-8000-000000000041';
  other_admin constant uuid := 'c1600000-0000-4000-8000-000000000012';
  room constant uuid := 'c1600000-0000-4000-8000-000000000051';
  admin_session constant uuid := 'c1600000-0000-4000-8000-000000000091';
  teacher_session constant uuid := 'c1600000-0000-4000-8000-000000000092';
  editor_session constant uuid := 'c1600000-0000-4000-8000-000000000093';
  other_session constant uuid := 'c1600000-0000-4000-8000-000000000094';
  s1 uuid;
  s2 uuid;
  s1_session uuid;
  s2_session uuid;
  persona uuid;
  result jsonb;
  poll uuid;
  option_a uuid;
  article uuid;
  alumni uuid;
begin
  perform set_config('app.institute_id', tenant::text, true);
  select id into s1 from app.users where username = 'hc-student-1';
  select id into s2 from app.users where username = 'hc-student-2';
  select id into s1_session from identity.sessions where user_id = s1;
  select id into s2_session from identity.sessions where user_id = s2;
  select persona_id into persona from app.persona_links where user_id = s1;

  perform set_config('app.user_id', s1::text, true);
  result := identity.save_onboarding(s1_session, 'language', 1, 'ur', null);
  assert result->>'code' = 'ok' and (result->>'step')::int = 2, result::text;
  assert (select preferred_language from app.users where id = s1) = 'ur', 'language was not saved';
  result := identity.save_onboarding(s1_session, 'name', 2, '03001234567', null);
  assert result->>'code' = 'rejected', 'a phone number was accepted as a pen name';
  result := identity.save_onboarding(s1_session, 'name', 2, 'Ahmed', null);
  assert result->>'code' = 'rejected', 'a real-name token was accepted';
  result := identity.save_onboarding(s1_session, 'name', 2, 'Neelam 7', null);
  assert result->>'code' = 'ok', result::text;
  assert (select count(*) from app.persona_names where persona_id = persona) >= 2, 'the old pen name was not kept';
  assert identity.update_persona(s1_session, 'Chand 8', 3::smallint, 'I like recitation', 'ur') = 'too_soon',
    'a pen name changed inside 30 days';
  assert identity.update_persona(s1_session, null, 4::smallint, 'I like recitation', 'ur') = 'saved',
    'avatar and bio were not saved';
  assert (select avatar_preset = 4 and bio = 'I like recitation' from app.personas where id = persona),
    'avatar or bio was not saved';
  assert identity.update_persona(s1_session, null, null, 'Ahmed studies', 'ur') = 'rejected',
    'a bio with a real name was saved';

  perform set_config('app.user_id', s2::text, true);
  assert identity.update_persona(s2_session, 'Stolen Name', null, null, 'en') = 'saved',
    'a student could not choose a pen name';
  assert (select display_name from app.personas where id = persona) = 'Neelam 7',
    'the pen name changed under another student';

  perform set_config('app.user_id', editor::text, true);
  assert identity.reset_persona(editor_session, s1) = 'denied', 'an editor reset a pen name';
  perform set_config('app.user_id', teacher::text, true);
  assert identity.reset_persona(teacher_session, s1) = 'reset', 'the class teacher could not reset a pen name';
  assert (select reset_note = 'reset' and display_name_changed_at is null from app.personas where id = persona),
    'the reset did not let the student choose again';
  assert exists (select from app.audit_log where action = 'personas.reset_name' and entity_id = persona::text),
    'the reset was not audited';

  perform set_config('app.user_id', s1::text, true);
  result := identity.read_hub(s1_session, null, null, null);
  assert result->>'code' = 'ok' and (result->'viewer'->>'walkthrough')::boolean, result::text;
  assert result::text not like '%Ahmed%', 'the hub payload contains a real name';
  assert result::text not like '%user_id%', 'the hub payload names a user id';
  result := identity.save_onboarding(s1_session, 'finish', (result->'viewer'->>'step')::int, null, null);
  assert (result->>'onboarded')::boolean, result::text;

  result := identity.publish_hub_post(s1_session, 'class', room, null, null, 'poll', 'ur',
    null, null, 'Which surah shall we revise?', null, null, false, null, 'after_voting', 24,
    array['Surah Yasin', 'Surah Mulk']);
  assert result->>'code' = 'posted', result::text;
  poll := (result->>'post_id')::uuid;
  select id into option_a from app.poll_options where post_id = poll and position = 1;
  perform set_config('app.user_id', s2::text, true);
  assert identity.vote_hub_poll(s2_session, poll, array[option_a]) = 'voted', 'a classmate could not vote';
  perform set_config('app.user_id', editor::text, true);
  assert identity.vote_hub_poll(editor_session, poll, array[option_a]) = 'denied', 'an editor voted';
  perform set_config('app.user_id', teacher::text, true);
  assert identity.close_hub_poll(teacher_session, poll) = 'closed', 'the teacher could not close the poll';
  perform set_config('app.user_id', s2::text, true);
  assert identity.vote_hub_poll(s2_session, poll, array[option_a]) = 'closed', 'a vote was accepted after closing';

  perform set_config('app.user_id', s1::text, true);
  result := identity.publish_hub_post(s1_session, 'class', room, null, null, 'article', 'ur',
    'A short note', 'About wudu', 'Wudu starts with the intention.', null, null, false, null, null, null, null);
  assert result->>'code' = 'posted', result::text;
  result := identity.publish_hub_post(s1_session, 'class', room, null, null, 'video', 'en',
    'A recitation', null, 'Hands and a notebook only.', 'abcdefghijk', null, false, null, null, null, null);
  assert result->>'code' = 'posted', result::text;
  result := identity.publish_hub_post(s1_session, 'class', room, null, null, 'audio', 'ur',
    'Nasheed', null, 'A spoken nasheed. The file is not attached.', null, null, false, null, null, null, null);
  assert result->>'code' = 'posted' and (result->>'media_gap')::boolean, result::text;
  assert not exists (select from app.post_media pm where pm.post_id = (result->>'post_id')::uuid),
    'an audio post stored a file without storage';
  result := identity.publish_hub_post(s1_session, 'class', room, null, null, 'slides', 'en',
    'Class notes', null, 'Notes without a file.', null, null, false, null, null, null, null);
  assert (result->>'media_gap')::boolean, result::text;
  result := identity.publish_hub_post(s1_session, 'class', room, null, null, 'message', 'en',
    null, null, 'Write to me at name@example.com', null, null, false, null, null, null, null);
  assert result->>'code' = 'contact_details', 'an email was posted';

  perform set_config('app.user_id', teacher::text, true);
  result := identity.publish_hub_post(teacher_session, 'madrasa', null, null, null, 'article', 'ur',
    'A lesson on wudu', 'For beginners', 'Wudu is taught step by step.', null, 'lesson', false, null, null, null, null);
  assert result->>'code' = 'posted', result::text;
  article := (result->>'post_id')::uuid;
  assert identity.submit_hub_post(teacher_session, article) = 'submitted', 'teacher work was not sent for review';
  perform set_config('app.user_id', teacher::text, true);
  assert identity.decide_post(teacher_session, article, 'approve', null) = 'denied', 'a teacher approved their own work';
  perform set_config('app.user_id', editor::text, true);
  assert identity.decide_post(editor_session, article, 'approve', null) = 'approved', 'the editor could not approve teacher work';
  assert (select scope = 'public' and moderation_state = 'published' from app.posts where id = article),
    'approved teacher work did not become public';

  perform set_config('app.user_id', teacher::text, true);
  result := identity.make_hub_article(teacher_session,
    (select thread_id from app.posts where id = poll),
    'What the class revised', 'A verified note', 'The class chose a surah to revise.', 'ur', array[poll]);
  assert result->>'code' = 'posted', result::text;
  assert (select is_verified from app.posts where id = (result->>'post_id')::uuid), 'the article was not verified';
  perform set_config('app.user_id', s1::text, true);
  assert (identity.make_hub_article(s1_session, (select thread_id from app.posts where id = poll),
    'Mine', null, 'No.', 'en', null)->>'code') = 'denied', 'a student verified an article';

  perform set_config('app.user_id', admin::text, true);
  result := identity.publish_hub_post(admin_session, 'madrasa', null, null, null, 'article', 'en',
    'Admin note', null, 'A note from the office.', null, null, false, null, null, null, null);
  assert identity.submit_hub_post(admin_session, (result->>'post_id')::uuid) = 'published',
    'an admin could not publish their own item';
  assert (select scope = 'public' from app.posts where id = (result->>'post_id')::uuid),
    'the admin item stayed inside the madrasa';

  perform set_config('app.user_id', teacher::text, true);
  assert identity.mark_student_left(teacher_session, s1) = 'denied', 'a teacher marked a student as left';
  perform set_config('app.user_id', admin::text, true);
  assert identity.mark_student_left(admin_session, s1) = 'left', 'the admin could not mark a student as left';
  assert (select status = 'left' and (select is_active from app.personas where id = persona)
    from app.users where id = s1), 'leaving closed the persona';
  select id into alumni from app.classes where institute_id = tenant and kind = 'alumni';
  assert alumni is not null, 'the alumni class was not created';
  assert exists (select from app.class_members where user_id = s1 and class_id = alumni and ended_at is null),
    'the student was not added to the alumni class';
  assert not exists (
    select from app.class_members m where m.user_id = s1 and m.class_id = room and m.ended_at is null
  ), 'the old class membership stayed open';
  insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at)
  values ('c1600000-0000-4000-8000-000000000083', tenant, s1, 'hc-student-left', now() + interval '1 day', now());
  s1_session := 'c1600000-0000-4000-8000-000000000083';
  perform set_config('app.user_id', s1::text, true);
  result := identity.publish_hub_post(s1_session, 'class', room, null, null, 'message', 'ur',
    null, null, 'I am back in the old class.', null, null, false, null, null, null, null);
  assert result->>'code' <> 'posted', result::text;
  result := identity.publish_hub_post(s1_session, 'class', alumni, null, null, 'message', 'ur',
    null, null, 'Salaam from the alumni class.', null, null, false, null, null, null, null);
  assert result->>'code' = 'posted', result::text;
  result := identity.publish_hub_post(s1_session, 'madrasa', null, null, null, 'message', 'ur',
    null, null, 'Salaam to the madrasa.', null, null, false, null, null, null, null);
  assert result->>'code' = 'posted', result::text;

  perform set_config('app.institute_id', other::text, true);
  perform set_config('app.user_id', other_admin::text, true);
  assert identity.mark_student_left(other_session, s1) in ('not_found', 'denied'),
    'another institute marked this student as left';
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', s2::text, true);
  assert identity.read_hub(s2_session, 'class', alumni, null)->>'code' = 'unavailable',
    'a current student opened the alumni class';
end
$test$;
rollback;
