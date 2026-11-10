-- Threads and posts: types, language, scope, authors and who reads what
-- (04 §11.1, §11.2, §11.4, 07 §6, §7, P3-E3-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a7000000-0000-4000-8000-000000000001', 'hub-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
values ('a7000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'HUB',
  array['student_hub', 'teacher_hub']);
insert into app.users (id, institute_id, email, username, full_name, status) values
  ('a7000000-0000-4000-8000-000000000011', 'a7000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin', 'active'),
  ('a7000000-0000-4000-8000-000000000021', 'a7000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active'),
  ('a7000000-0000-4000-8000-000000000022', 'a7000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active'),
  ('a7000000-0000-4000-8000-000000000041', 'a7000000-0000-4000-8000-000000000001', 'editor@example.test', null, 'Editor', 'active'),
  ('a7000000-0000-4000-8000-000000000031', 'a7000000-0000-4000-8000-000000000001', null, 'hub-1', 'Student One', 'active'),
  ('a7000000-0000-4000-8000-000000000032', 'a7000000-0000-4000-8000-000000000001', null, 'hub-2', 'Student Two', 'active'),
  ('a7000000-0000-4000-8000-000000000033', 'a7000000-0000-4000-8000-000000000001', null, 'hub-3', 'Student Three', 'active');
insert into app.user_roles (institute_id, user_id, role)
select 'a7000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('a7000000-0000-4000-8000-000000000011', 'admin'), ('a7000000-0000-4000-8000-000000000021', 'teacher'),
  ('a7000000-0000-4000-8000-000000000022', 'teacher'), ('a7000000-0000-4000-8000-000000000041', 'editor'),
  ('a7000000-0000-4000-8000-000000000031', 'student'), ('a7000000-0000-4000-8000-000000000032', 'student'),
  ('a7000000-0000-4000-8000-000000000033', 'student')) r(id, role);
-- Class A (teacher one, students one and two), class B (teacher two, student
-- three) and an archived class of teacher one.
insert into app.classes (id, institute_id, name, created_by, archived_at) values
  ('a7000000-0000-4000-8000-000000000051', 'a7000000-0000-4000-8000-000000000001', '{"en":"A"}', 'a7000000-0000-4000-8000-000000000021', null),
  ('a7000000-0000-4000-8000-000000000052', 'a7000000-0000-4000-8000-000000000001', '{"en":"B"}', 'a7000000-0000-4000-8000-000000000022', null),
  ('a7000000-0000-4000-8000-000000000053', 'a7000000-0000-4000-8000-000000000001', '{"en":"Old"}', 'a7000000-0000-4000-8000-000000000021', now());
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('a7000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000051', 'a7000000-0000-4000-8000-000000000031', 'student'),
  ('a7000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000051', 'a7000000-0000-4000-8000-000000000032', 'student'),
  ('a7000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000052', 'a7000000-0000-4000-8000-000000000033', 'student');
insert into app.personas (id, institute_id, display_name) values
  ('a7000000-0000-4000-8000-000000000061', 'a7000000-0000-4000-8000-000000000001', 'Sitara 101'),
  ('a7000000-0000-4000-8000-000000000062', 'a7000000-0000-4000-8000-000000000001', 'Qalam 102'),
  ('a7000000-0000-4000-8000-000000000063', 'a7000000-0000-4000-8000-000000000001', 'Jugnu 103');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('a7000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000061', 'a7000000-0000-4000-8000-000000000031', 'a7000000-0000-4000-8000-000000000021'),
  ('a7000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000062', 'a7000000-0000-4000-8000-000000000032', 'a7000000-0000-4000-8000-000000000021'),
  ('a7000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000063', 'a7000000-0000-4000-8000-000000000033', 'a7000000-0000-4000-8000-000000000022');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a7000000-0000-4000-8000-000000000001';
  admin constant uuid := 'a7000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'a7000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'a7000000-0000-4000-8000-000000000022';
  editor constant uuid := 'a7000000-0000-4000-8000-000000000041';
  s1 constant uuid := 'a7000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'a7000000-0000-4000-8000-000000000032';
  s3 constant uuid := 'a7000000-0000-4000-8000-000000000033';
  p1 constant uuid := 'a7000000-0000-4000-8000-000000000061';
  p2 constant uuid := 'a7000000-0000-4000-8000-000000000062';
  p3 constant uuid := 'a7000000-0000-4000-8000-000000000063';
  class_a constant uuid := 'a7000000-0000-4000-8000-000000000051';
  old_class constant uuid := 'a7000000-0000-4000-8000-000000000053';
  thread_a constant uuid := 'a7000000-0000-4000-8000-000000000071';
  thread_m constant uuid := 'a7000000-0000-4000-8000-000000000072';
  question constant uuid := 'a7000000-0000-4000-8000-000000000081';
  draft constant uuid := 'a7000000-0000-4000-8000-000000000082';
  changed bigint;
  t app.threads;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- A student starts a class thread with a question; it is live at once (REQ-MOD-001).
  perform set_config('app.user_id', s1::text, true);
  insert into app.threads (id, institute_id, class_id, scope, title, language, author_persona_id)
  values (thread_a, tenant, class_a, 'class', 'Tajweed', 'ur', p1);
  insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_persona_id)
  values (question, tenant, thread_a, 'question', 'ur', 'مد کب لمبا ہوتا ہے؟', p1);
  select * into t from app.threads where id = thread_a;
  assert t.first_post_id = question and t.reply_count = 0, 'the thread did not record its first post';
  assert (select scope = 'class' and class_id = class_a and moderation_state = 'published' and published_at is not null
    from app.posts where id = question), 'the post did not take its thread''s scope';

  -- Students write only as their own persona, never as a user or as another persona.
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_a, 'message', 'en', 'Pretending', p2);
    assert false, 'a student posted as a classmate''s persona';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_user_id)
    values (tenant, thread_a, 'message', 'en', 'Real name', s1);
    assert false, 'a student posted under their account';
  exception when check_violation then null;
  end;
  -- Public and community are not chosen at creation (REQ-STU-008, REQ-MIR-004).
  foreach changed in array array[1, 2] loop
    begin
      insert into app.threads (institute_id, scope, language, author_persona_id)
      values (tenant, (array['public', 'community'])[changed], 'en', p1);
      assert false, 'a thread started outside class and madrasa scope';
    exception when insufficient_privilege or check_violation then null;
    end;
  end loop;

  -- A classmate sees it and answers; a reply keeps the thread's scope.
  perform set_config('app.user_id', s2::text, true);
  assert (select count(*) from app.posts where id = question) = 1, 'a classmate cannot see a class post';
  insert into app.posts (institute_id, thread_id, parent_post_id, post_type, language, body, scope, author_persona_id)
  values (tenant, thread_a, question, 'answer', 'ur', 'جب اس کے بعد ہمزہ ہو', 'madrasa', p2);
  assert (select count(*) from app.posts where thread_id = thread_a and scope = 'class') = 2,
    'a reply widened its scope';
  assert (select reply_count from app.threads where id = thread_a) = 1;
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_a, 'answer', 'en', 'Answer to nothing', p2);
    assert false, 'an answer had no question';
  exception when check_violation then null;
  end;
  begin
    insert into app.posts (institute_id, thread_id, parent_post_id, post_type, language, body, author_persona_id)
    values (tenant, thread_a, (select id from app.posts where post_type = 'answer'), 'answer', 'en', 'Answer to an answer', p2);
    assert false, 'an answer replied to something other than a question';
  exception when check_violation then null;
  end;
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_a, 'message', 'urdu', 'Bad language code', p2);
    assert false, 'a bad language code was saved';
  exception when check_violation then null;
  end;
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_a, 'article', 'en', 'An article needs a title', p2);
    assert false, 'an article had no title';
  exception when check_violation then null;
  end;
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_a, 'gossip', 'en', 'Not a type', p2);
    assert false, 'an unknown post type was saved';
  exception when check_violation then null;
  end;
  -- Every post type of REQ-STU-005 can be saved.
  insert into app.posts (institute_id, thread_id, post_type, language, title, body, author_persona_id, poll_closes_at)
  select tenant, thread_a, kind, 'en', 'Title', 'Body', p2, case when kind = 'poll' then now() + interval '1 day' end
  from unnest(array['message', 'poll', 'article', 'video', 'vlog', 'audio', 'slides']) kind;

  -- A draft is seen by its author and the class teacher only.
  perform set_config('app.user_id', s1::text, true);
  insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_persona_id, moderation_state)
  values (draft, tenant, thread_a, 'message', 'en', 'Not posted yet', p1, 'draft');
  assert (select count(*) from app.posts where id = draft) = 1;
  assert (select reply_count from app.threads where id = thread_a) = 8, 'a draft counted as a reply';
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id, moderation_state)
    values (tenant, thread_a, 'message', 'en', 'Straight to public', p1, 'approved');
    assert false, 'a post skipped moderation';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', s2::text, true);
  assert not exists (select from app.posts where id = draft), 'a classmate read a draft';

  -- Nobody edits or deletes posts yet (P3-E3-T11, P3-E5-T40).
  perform set_config('app.user_id', s1::text, true);
  begin
    update app.posts set body = 'Changed' where id = question;
    assert false, 'a post was edited';
  exception when insufficient_privilege then null;
  end;
  begin
    update app.posts set moderation_state = 'published', scope = 'public' where id = question;
    assert false, 'a post went public without moderation';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from app.posts where id = question;
    assert false, 'a post was deleted';
  exception when insufficient_privilege then null;
  end;

  -- Outside the class: another class's student and teacher see and write nothing.
  foreach changed in array array[1, 2] loop
    perform set_config('app.user_id', (array[s3, t2])[changed]::text, true);
    assert not exists (select from app.threads where id = thread_a), 'a class thread leaked outside the class';
    assert not exists (select from app.posts where thread_id = thread_a), 'class posts leaked outside the class';
    begin
      if changed = 1 then
        insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
        values (tenant, thread_a, 'message', 'en', 'Intruder', p3);
      else
        insert into app.posts (institute_id, thread_id, post_type, language, body, author_user_id)
        values (tenant, thread_a, 'message', 'en', 'Intruder', t2);
      end if;
      assert false, 'someone outside the class posted in it';
    exception when insufficient_privilege then null;
    end;
  end loop;

  -- The class teacher sees everything in the class, drafts included (REQ-CHS-003), and posts as a teacher.
  perform set_config('app.user_id', t1::text, true);
  assert (select count(*) from app.posts where thread_id = thread_a) = 10, 'the class teacher misses class posts';
  insert into app.posts (institute_id, thread_id, parent_post_id, post_type, language, body, author_user_id)
  values (tenant, thread_a, question, 'answer', 'en', 'Teacher answer', t1);
  begin
    insert into app.threads (institute_id, class_id, scope, language, author_user_id)
    values (tenant, old_class, 'class', 'en', t1);
    assert false, 'a thread started in an archived class';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- Madrasa scope: every member reads; editors do not post; visitors read nothing.
  perform set_config('app.user_id', s3::text, true);
  insert into app.threads (id, institute_id, scope, language, author_persona_id)
  values (thread_m, tenant, 'madrasa', 'en', p3);
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_m, 'message', 'en', 'Hello everyone', p3);
  foreach changed in array array[1, 2, 3, 4] loop
    perform set_config('app.user_id', (array[s1, t1, editor, admin])[changed]::text, true);
    assert (select count(*) from app.posts where thread_id = thread_m) = 1, 'a member cannot read a madrasa post';
  end loop;
  perform set_config('app.user_id', editor::text, true);
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_user_id)
    values (tenant, thread_m, 'message', 'en', 'Editor post', editor);
    assert false, 'an editor posted in the hub';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', t2::text, true);
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_user_id)
  values (tenant, thread_m, 'message', 'en', 'Teacher in madrasa', t2);
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.posts) and not exists (select from app.threads), 'a visitor read hub posts';
end
$test$;

-- Switched-off module, locked thread, inactive persona, taken-down post and
-- a student who left: set up as the owner, checked as the app.
reset role;
set local role tazkiyah_schema_owner;
do $test$
begin
  begin
    insert into app.threads (institute_id, scope, language, author_user_id)
    values ('a7000000-0000-4000-8000-000000000001', 'community', 'en', 'a7000000-0000-4000-8000-000000000021');
    assert false, 'the community scope was used';
  exception when check_violation then null;
  end;
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_user_id)
    values ('a7000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000072', 'message', 'en',
      'As a user', 'a7000000-0000-4000-8000-000000000031');
    assert false, 'a student posted under their account';
  exception when check_violation then null;
  end;
end
$test$;
select set_config('app.user_id', 'a7000000-0000-4000-8000-000000000011', true);
update app.threads set locked_at = now(), locked_by = 'a7000000-0000-4000-8000-000000000021'
where id = 'a7000000-0000-4000-8000-000000000071';
update app.posts set moderation_state = 'taken_down' where id = 'a7000000-0000-4000-8000-000000000081';
update app.institute_settings set enabled_modules = array['teacher_hub']
where institute_id = 'a7000000-0000-4000-8000-000000000001';
update app.personas set is_active = false where id = 'a7000000-0000-4000-8000-000000000063';
update app.class_members set ended_at = current_date where user_id = 'a7000000-0000-4000-8000-000000000032';

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a7000000-0000-4000-8000-000000000001';
  thread_a constant uuid := 'a7000000-0000-4000-8000-000000000071';
  thread_m constant uuid := 'a7000000-0000-4000-8000-000000000072';
  question constant uuid := 'a7000000-0000-4000-8000-000000000081';
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- With the student hub off, students cannot post; teachers still can.
  perform set_config('app.user_id', 'a7000000-0000-4000-8000-000000000031', true);
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_m, 'message', 'en', 'Hub is off', 'a7000000-0000-4000-8000-000000000061');
    assert false, 'a student posted with the student hub off';
  exception when insufficient_privilege then null;
  end;
  -- A taken-down post is gone for its author and classmates, not for the class teacher.
  assert not exists (select from app.posts where id = question), 'the author still sees a taken-down post';
  perform set_config('app.user_id', 'a7000000-0000-4000-8000-000000000021', true);
  assert exists (select from app.posts where id = question), 'the class teacher lost a taken-down post';
  -- A locked thread takes staff posts only.
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_user_id)
  values (tenant, thread_a, 'message', 'en', 'Closing note', 'a7000000-0000-4000-8000-000000000021');
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
update app.institute_settings set enabled_modules = array['student_hub', 'teacher_hub']
where institute_id = 'a7000000-0000-4000-8000-000000000001';
set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a7000000-0000-4000-8000-000000000001';
  thread_a constant uuid := 'a7000000-0000-4000-8000-000000000071';
  thread_m constant uuid := 'a7000000-0000-4000-8000-000000000072';
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', 'a7000000-0000-4000-8000-000000000031', true);
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_a, 'message', 'en', 'Locked out', 'a7000000-0000-4000-8000-000000000061');
    assert false, 'a student posted in a locked thread';
  exception when object_not_in_prerequisite_state then null;
  end;
  -- A persona switched off by an admin cannot post.
  perform set_config('app.user_id', 'a7000000-0000-4000-8000-000000000033', true);
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_m, 'message', 'en', 'Switched off', 'a7000000-0000-4000-8000-000000000063');
    assert false, 'a switched-off persona posted';
  exception when check_violation then null;
  end;
  -- A student whose membership ended keeps their own posts and the madrasa scope,
  -- but no longer reads or writes in the class.
  perform set_config('app.user_id', 'a7000000-0000-4000-8000-000000000032', true);
  assert (select count(*) from app.posts where thread_id = thread_a) = 8, 'a former member lost their own posts or kept others''';
  assert not exists (select from app.posts where thread_id = thread_a and author_persona_id <> 'a7000000-0000-4000-8000-000000000062');
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_m, 'message', 'en', 'Still here', 'a7000000-0000-4000-8000-000000000062');
end
$test$;
