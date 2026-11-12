-- Post reports, closing them, the moderation queue and the open-report hold
-- on publishing (04 §11.6, 07 §8.5, REQ-STU-011, REQ-MOD-005, P3-E5-T41).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('ab000000-0000-4000-8000-000000000001', 'report-fixture'),
  ('ab000000-0000-4000-8000-000000000002', 'report-fixture-other');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
select id, '{"en":"Institute"}', '{"en":"A"}', '{}', 'REP', array['student_hub', 'teacher_hub']
from app.institutes where slug like 'report-fixture%';
insert into app.users (id, institute_id, email, username, full_name, status) values
  ('ab000000-0000-4000-8000-000000000011', 'ab000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin', 'active'),
  ('ab000000-0000-4000-8000-000000000021', 'ab000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active'),
  ('ab000000-0000-4000-8000-000000000022', 'ab000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active'),
  ('ab000000-0000-4000-8000-000000000041', 'ab000000-0000-4000-8000-000000000001', 'editor@example.test', null, 'Editor', 'active'),
  ('ab000000-0000-4000-8000-000000000031', 'ab000000-0000-4000-8000-000000000001', null, 'rep-1', 'Student One', 'active'),
  ('ab000000-0000-4000-8000-000000000032', 'ab000000-0000-4000-8000-000000000001', null, 'rep-2', 'Student Two', 'active'),
  ('ab000000-0000-4000-8000-000000000033', 'ab000000-0000-4000-8000-000000000001', null, 'rep-3', 'Student Three', 'active');
insert into app.user_roles (institute_id, user_id, role)
select 'ab000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('ab000000-0000-4000-8000-000000000011', 'admin'), ('ab000000-0000-4000-8000-000000000021', 'teacher'),
  ('ab000000-0000-4000-8000-000000000022', 'teacher'), ('ab000000-0000-4000-8000-000000000041', 'editor'),
  ('ab000000-0000-4000-8000-000000000031', 'student'), ('ab000000-0000-4000-8000-000000000032', 'student'),
  ('ab000000-0000-4000-8000-000000000033', 'student')) r(id, role);
insert into app.classes (id, institute_id, name, created_by) values
  ('ab000000-0000-4000-8000-000000000051', 'ab000000-0000-4000-8000-000000000001', '{"en":"A"}', 'ab000000-0000-4000-8000-000000000021'),
  ('ab000000-0000-4000-8000-000000000052', 'ab000000-0000-4000-8000-000000000001', '{"en":"B"}', 'ab000000-0000-4000-8000-000000000022');
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-000000000051', 'ab000000-0000-4000-8000-000000000031', 'student'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-000000000051', 'ab000000-0000-4000-8000-000000000032', 'student'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-000000000052', 'ab000000-0000-4000-8000-000000000033', 'student');
insert into app.personas (id, institute_id, display_name) values
  ('ab000000-0000-4000-8000-000000000061', 'ab000000-0000-4000-8000-000000000001', 'Sitara 501'),
  ('ab000000-0000-4000-8000-000000000062', 'ab000000-0000-4000-8000-000000000001', 'Qalam 502'),
  ('ab000000-0000-4000-8000-000000000063', 'ab000000-0000-4000-8000-000000000001', 'Jugnu 503');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-000000000061', 'ab000000-0000-4000-8000-000000000031', 'ab000000-0000-4000-8000-000000000021'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-000000000062', 'ab000000-0000-4000-8000-000000000032', 'ab000000-0000-4000-8000-000000000021'),
  ('ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-000000000063', 'ab000000-0000-4000-8000-000000000033', 'ab000000-0000-4000-8000-000000000022');
insert into app.threads (id, institute_id, class_id, scope, title, language, author_persona_id, author_user_id) values
  ('ab000000-0000-4000-8000-000000000071', 'ab000000-0000-4000-8000-000000000001', 'ab000000-0000-4000-8000-000000000051',
    'class', 'Questions', 'en', 'ab000000-0000-4000-8000-000000000061', null),
  ('ab000000-0000-4000-8000-000000000072', 'ab000000-0000-4000-8000-000000000001', null,
    'madrasa', 'Notices', 'en', null, 'ab000000-0000-4000-8000-000000000021');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'ab000000-0000-4000-8000-000000000001';
  admin constant uuid := 'ab000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'ab000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'ab000000-0000-4000-8000-000000000022';
  editor constant uuid := 'ab000000-0000-4000-8000-000000000041';
  s1 constant uuid := 'ab000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'ab000000-0000-4000-8000-000000000032';
  s3 constant uuid := 'ab000000-0000-4000-8000-000000000033';
  p1 constant uuid := 'ab000000-0000-4000-8000-000000000061';
  thread_a constant uuid := 'ab000000-0000-4000-8000-000000000071';
  thread_m constant uuid := 'ab000000-0000-4000-8000-000000000072';
  q1 uuid;
  q2 uuid;
  notice uuid;
  report1 uuid;
  report2 uuid;
  changed bigint;
  queued record;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', s1::text, true);
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_a, 'question', 'en', 'My number is below', p1) returning id into q1;
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_a, 'message', 'en', 'A poem', p1) returning id into q2;
  perform set_config('app.user_id', t1::text, true);
  insert into app.posts (institute_id, thread_id, post_type, language, title, body, author_user_id)
  values (tenant, thread_m, 'article', 'en', 'Timetable', 'New timetable', t1) returning id into notice;
  insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
    method, given_on, recorded_by)
  values (tenant, s1, 'public_work', 'Guardian', 'mother', 'in_person', current_date, t1);

  -- A classmate reports a post they can see (REQ-STU-011); the report opens.
  perform set_config('app.user_id', s2::text, true);
  insert into app.post_reports (institute_id, post_id, reporter_user_id, reason, status, handled_by)
  values (tenant, q1, s2, 'personal_details', 'dismissed', s2) returning id into report1;
  assert (select status = 'open' and handled_by is null and created_at = now() from app.post_reports where id = report1),
    'a report did not open as filed';
  begin
    insert into app.post_reports (institute_id, post_id, reporter_user_id, reason) values (tenant, q1, s2, 'unkind');
    assert false, 'a second open report by the same person was saved';
  exception when unique_violation then null;
  end;
  begin
    insert into app.post_reports (institute_id, post_id, reporter_user_id, reason) values (tenant, q2, s2, 'other');
    assert false, 'an "other" report without a note was saved';
  exception when check_violation then null;
  end;
  begin
    insert into app.post_reports (institute_id, post_id, reporter_user_id, reason, note)
    values (tenant, q2, s2, 'other', repeat('x', 301));
    assert false, 'a 301-character note was saved';
  exception when check_violation then null;
  end;
  begin
    insert into app.post_reports (institute_id, post_id, reporter_user_id, reason) values (tenant, q2, s3, 'unkind');
    assert false, 'a report was filed for someone else';
  exception when insufficient_privilege then null;
  end;
  -- Another class cannot report what it cannot see; visitors file nothing here.
  perform set_config('app.user_id', s3::text, true);
  begin
    insert into app.post_reports (institute_id, post_id, reporter_user_id, reason) values (tenant, q1, s3, 'unkind');
    assert false, 'a student reported a post of another class';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', '', true);
  begin
    insert into app.post_reports (institute_id, post_id, reporter_user_id, reason) values (tenant, q1, null, 'unkind');
    assert false, 'a visitor filed a report';
  exception when insufficient_privilege then null;
  end;
  -- Editors report what they see.
  perform set_config('app.user_id', editor::text, true);
  insert into app.post_reports (institute_id, post_id, reporter_user_id, reason, note)
  values (tenant, notice, editor, 'wrong_information', 'Friday is wrong');

  -- The author never learns who reported them; the reporter sees their own.
  perform set_config('app.user_id', s1::text, true);
  assert not exists (select from app.post_reports), 'the author read a report';
  assert not exists (select from app.moderation_queue), 'a student saw the moderation queue';
  perform set_config('app.user_id', s2::text, true);
  assert (select count(*) from app.post_reports) = 1, 'the reporter cannot see their report';
  assert not exists (select from app.moderation_queue), 'a reporter saw the moderation queue';
  -- The class teacher and admins see the report and the queue item; another
  -- class's teacher does not see a class post's report.
  perform set_config('app.user_id', t1::text, true);
  assert exists (select from app.post_reports where id = report1), 'the class teacher cannot see the report';
  select * into queued from app.moderation_queue where post_id = q1;
  assert queued.item = 'report' and queued.priority = 1 and queued.report_count = 1
    and queued.reasons = array['personal_details'], 'the queue item is wrong: ' || row_to_json(queued)::text;
  perform set_config('app.user_id', t2::text, true);
  assert not exists (select from app.post_reports where post_id = q1), 'another teacher read a class report';
  assert not exists (select from app.moderation_queue where post_id = q1), 'another teacher saw a class queue item';
  -- Any teacher sees madrasa-scope reports, with lower priority for wrong information.
  assert (select priority from app.moderation_queue where post_id = notice and item = 'report') = 3,
    'a teacher cannot see a madrasa report';
  perform set_config('app.user_id', admin::text, true);
  assert (select count(*) from app.moderation_queue where item = 'report') = 2, 'an admin does not see every report';
  perform set_config('app.user_id', editor::text, true);
  assert not exists (select from app.moderation_queue where item = 'report'), 'an editor saw reports';

  -- Closing a report: only a moderator of the post, once, keeping what was reported.
  perform set_config('app.user_id', s2::text, true);
  update app.post_reports set status = 'dismissed' where id = report1;
  get diagnostics changed = row_count;
  assert changed = 0, 'the reporter closed their own report';
  perform set_config('app.user_id', t2::text, true);
  update app.post_reports set status = 'dismissed' where id = report1;
  get diagnostics changed = row_count;
  assert changed = 0, 'another class''s teacher closed a report';
  perform set_config('app.user_id', t1::text, true);
  begin
    update app.post_reports set reason = 'unkind' where id = report1;
    assert false, 'a report''s reason was changed';
  exception when insufficient_privilege then null;
  end;
  begin
    update app.post_reports set outcome_note = 'Looked' where id = report1;
    assert false, 'a report was left open with an outcome';
  exception when check_violation then null;
  end;
  update app.post_reports set status = 'actioned', outcome_note = 'Number removed' where id = report1;
  assert (select handled_by = t1 and handled_at = now() from app.post_reports where id = report1),
    'the closing was not recorded';
  begin
    update app.post_reports set status = 'dismissed' where id = report1;
    assert false, 'a closed report was closed again';
  exception when object_not_in_prerequisite_state then null;
  end;
  assert not exists (select from app.moderation_queue where post_id = q1), 'a closed report stayed in the queue';
  -- Any teacher closes a madrasa-scope report.
  perform set_config('app.user_id', t2::text, true);
  update app.post_reports set status = 'dismissed', outcome_note = 'Friday is right' where post_id = notice;
  get diagnostics changed = row_count;
  assert changed = 1, 'a teacher could not close a madrasa report';

  -- An open report holds an approved request until it is closed (07 §8.2).
  perform set_config('app.user_id', s2::text, true);
  insert into app.post_reports (institute_id, post_id, reporter_user_id, reason) values (tenant, q2, s2, 'unkind')
  returning id into report2;
  perform set_config('app.user_id', s1::text, true);
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = q2;
  perform set_config('app.user_id', t1::text, true);
  assert (select count(*) from app.moderation_queue where post_id = q2) = 2, 'the queue lacks the report or the request';
  update app.posts set moderation_state = 'approved' where id = q2;
  assert (select moderation_state from app.posts where id = q2) = 'approved', 'a reported post was published';
  assert (select item from app.moderation_queue where post_id = q2 and item <> 'report') = 'approved_waiting',
    'the waiting approval is not in the queue';
  begin
    update app.posts set moderation_state = 'published' where id = q2;
    assert false, 'a reported post was published by hand';
  exception when object_not_in_prerequisite_state then null;
  end;
  update app.post_reports set status = 'dismissed', outcome_note = 'Not unkind' where id = report2;
  update app.posts set moderation_state = 'published' where id = q2;
  assert (select scope from app.posts where id = q2) = 'public', 'the post was not published once the report closed';

  -- Another institute sees nothing of this one's queue.
  perform set_config('app.institute_id', 'ab000000-0000-4000-8000-000000000002', true);
  perform set_config('app.user_id', admin::text, true);
  assert not exists (select from app.moderation_queue), 'the queue leaked across institutes';
end
$test$;

rollback;
