-- Moderation: hide, public requests, approval, publishing with consent,
-- widening, takedown and restore (04 §11.3, §11.4, 07 §8, P3-E5-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('aa000000-0000-4000-8000-000000000001', 'moderation-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
values ('aa000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'MOD',
  array['student_hub', 'teacher_hub']);
insert into app.users (id, institute_id, email, username, full_name, status) values
  ('aa000000-0000-4000-8000-000000000011', 'aa000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin', 'active'),
  ('aa000000-0000-4000-8000-000000000021', 'aa000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active'),
  ('aa000000-0000-4000-8000-000000000022', 'aa000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active'),
  ('aa000000-0000-4000-8000-000000000023', 'aa000000-0000-4000-8000-000000000001', 't3@example.test', null, 'Teacher Three', 'active'),
  ('aa000000-0000-4000-8000-000000000041', 'aa000000-0000-4000-8000-000000000001', 'editor@example.test', null, 'Editor', 'active'),
  ('aa000000-0000-4000-8000-000000000031', 'aa000000-0000-4000-8000-000000000001', null, 'mod-1', 'Student One', 'active'),
  ('aa000000-0000-4000-8000-000000000032', 'aa000000-0000-4000-8000-000000000001', null, 'mod-2', 'Student Two', 'active'),
  ('aa000000-0000-4000-8000-000000000033', 'aa000000-0000-4000-8000-000000000001', null, 'mod-3', 'Student Three', 'active');
insert into app.user_roles (institute_id, user_id, role, can_widen_scope)
select 'aa000000-0000-4000-8000-000000000001', id::uuid, role, widen from (values
  ('aa000000-0000-4000-8000-000000000011', 'admin', false), ('aa000000-0000-4000-8000-000000000021', 'teacher', false),
  ('aa000000-0000-4000-8000-000000000022', 'teacher', false), ('aa000000-0000-4000-8000-000000000023', 'teacher', true),
  ('aa000000-0000-4000-8000-000000000041', 'editor', false), ('aa000000-0000-4000-8000-000000000031', 'student', false),
  ('aa000000-0000-4000-8000-000000000032', 'student', false), ('aa000000-0000-4000-8000-000000000033', 'student', false)
) r(id, role, widen);
-- Class A (teacher one, students one and two), class B (teacher two, student
-- three); teacher three teaches no class but may widen scopes.
insert into app.classes (id, institute_id, name, created_by) values
  ('aa000000-0000-4000-8000-000000000051', 'aa000000-0000-4000-8000-000000000001', '{"en":"A"}', 'aa000000-0000-4000-8000-000000000021'),
  ('aa000000-0000-4000-8000-000000000052', 'aa000000-0000-4000-8000-000000000001', '{"en":"B"}', 'aa000000-0000-4000-8000-000000000022');
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000051', 'aa000000-0000-4000-8000-000000000031', 'student'),
  ('aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000051', 'aa000000-0000-4000-8000-000000000032', 'student'),
  ('aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000052', 'aa000000-0000-4000-8000-000000000033', 'student');
insert into app.personas (id, institute_id, display_name) values
  ('aa000000-0000-4000-8000-000000000061', 'aa000000-0000-4000-8000-000000000001', 'Sitara 401'),
  ('aa000000-0000-4000-8000-000000000062', 'aa000000-0000-4000-8000-000000000001', 'Qalam 402'),
  ('aa000000-0000-4000-8000-000000000063', 'aa000000-0000-4000-8000-000000000001', 'Jugnu 403');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000061', 'aa000000-0000-4000-8000-000000000031', 'aa000000-0000-4000-8000-000000000021'),
  ('aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000062', 'aa000000-0000-4000-8000-000000000032', 'aa000000-0000-4000-8000-000000000021'),
  ('aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000063', 'aa000000-0000-4000-8000-000000000033', 'aa000000-0000-4000-8000-000000000022');
insert into app.threads (id, institute_id, class_id, scope, title, language, author_persona_id, author_user_id) values
  ('aa000000-0000-4000-8000-000000000071', 'aa000000-0000-4000-8000-000000000001', 'aa000000-0000-4000-8000-000000000051',
    'class', 'Questions', 'en', 'aa000000-0000-4000-8000-000000000061', null),
  ('aa000000-0000-4000-8000-000000000072', 'aa000000-0000-4000-8000-000000000001', null,
    'madrasa', 'Teachers', 'en', null, 'aa000000-0000-4000-8000-000000000021');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'aa000000-0000-4000-8000-000000000001';
  admin constant uuid := 'aa000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'aa000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'aa000000-0000-4000-8000-000000000022';
  t3 constant uuid := 'aa000000-0000-4000-8000-000000000023';
  editor constant uuid := 'aa000000-0000-4000-8000-000000000041';
  s1 constant uuid := 'aa000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'aa000000-0000-4000-8000-000000000032';
  s3 constant uuid := 'aa000000-0000-4000-8000-000000000033';
  p1 constant uuid := 'aa000000-0000-4000-8000-000000000061';
  p2 constant uuid := 'aa000000-0000-4000-8000-000000000062';
  thread_a constant uuid := 'aa000000-0000-4000-8000-000000000071';
  thread_m constant uuid := 'aa000000-0000-4000-8000-000000000072';
  consent uuid;
  q1 uuid;
  q2 uuid;
  q3 uuid;
  q4 uuid;
  d1 uuid;
  m1 uuid;
  changed_post uuid;
  changed bigint;
  p app.posts;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- Student one's guardian agreed to public work; student two has no consent.
  perform set_config('app.user_id', t1::text, true);
  insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
    method, given_on, recorded_by)
  values (tenant, s1, 'public_work', 'Guardian', 'father', 'in_person', current_date, t1) returning id into consent;

  perform set_config('app.user_id', s1::text, true);
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_a, 'question', 'en', 'Question one', p1) returning id into q1;
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_a, 'question', 'en', 'Question two', p1) returning id into q2;
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_a, 'question', 'en', 'Question three', p1) returning id into q3;
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id, moderation_state)
  values (tenant, thread_a, 'message', 'en', 'Draft one', p1, 'draft') returning id into d1;

  -- Hiding (REQ-MOD-002): not by students, not by another class's teacher.
  begin
    update app.posts set hidden_at = now() where id = q1;
    assert false, 'the author hid their own post';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', s2::text, true);
  update app.posts set hidden_at = now() where id = q1;
  get diagnostics changed = row_count;
  assert changed = 0, 'a classmate hid a post';
  perform set_config('app.user_id', t2::text, true);
  update app.posts set hidden_at = now() where id = q1;
  get diagnostics changed = row_count;
  assert changed = 0, 'another class''s teacher hid a post';
  -- The class teacher hides it: the author and teachers still see it, classmates do not.
  perform set_config('app.user_id', t1::text, true);
  update app.posts set hidden_at = now() - interval '1 year', hidden_reason = 'Check the wording' where id = q1;
  select * into p from app.posts where id = q1;
  assert p.hidden_by = t1 and p.hidden_at = now() and p.moderation_state = 'published', 'the hide was not recorded';
  perform set_config('app.user_id', s2::text, true);
  assert not exists (select from app.posts where id = q1), 'a classmate saw a hidden post';
  perform set_config('app.user_id', s1::text, true);
  assert exists (select from app.posts where id = q1), 'the author lost sight of their hidden post';
  -- A hidden post cannot be put forward for public view.
  begin
    update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = q1;
    assert false, 'a hidden post was put forward';
  exception when object_not_in_prerequisite_state then null;
  end;
  perform set_config('app.user_id', t1::text, true);
  update app.posts set hidden_at = null where id = q1;
  assert (select hidden_by is null and hidden_reason is null from app.posts where id = q1), 'the unhide left traces';

  -- A public request by the author, with consent (REQ-MOD-004, REQ-CHS-005).
  perform set_config('app.user_id', s1::text, true);
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = q1;
  assert (select submitted_at = now() and scope = 'class' from app.posts where id = q1), 'the request was not recorded';
  perform set_config('app.user_id', s2::text, true);
  assert exists (select from app.posts where id = q1), 'a submitted post left the class';
  -- Nobody approves their own post; classmates, other teachers and editors cannot.
  perform set_config('app.user_id', s1::text, true);
  begin
    update app.posts set moderation_state = 'approved' where id = q1;
    assert false, 'a student approved their own post';
  exception when insufficient_privilege then null;
  end;
  foreach changed in array array[1, 2, 3] loop
    perform set_config('app.user_id', (array[s2, t2, editor])[changed]::text, true);
    begin
      update app.posts set moderation_state = 'approved' where id = q1;
      assert not found, 'the wrong person approved a student''s public request';
    exception when insufficient_privilege then null;
    end;
  end loop;
  -- The class teacher approves (REQ-MOD-003), and it is published at once.
  perform set_config('app.user_id', t1::text, true);
  update app.posts set moderation_state = 'approved' where id = q1;
  select * into p from app.posts where id = q1;
  assert p.moderation_state = 'published' and p.scope = 'public' and p.target_scope is null
    and p.approved_by = t1 and p.published_at = now(), 'the approved post was not published';
  perform set_config('app.user_id', s3::text, true);
  assert exists (select from app.posts where id = q1), 'a public post is hidden from other members';

  -- Without consent a student's work is not put forward.
  perform set_config('app.user_id', s2::text, true);
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_a, 'message', 'en', 'Student two', p2) returning id into q4;
  begin
    update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = q4;
    assert false, 'work without consent was put forward';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.posts set moderation_state = 'submitted', target_scope = 'class' where id = q4;
    assert false, 'a request asked for the same scope';
  exception when check_violation then null;
  end;
  begin
    update app.posts set moderation_state = 'submitted', target_scope = 'community' where id = q4;
    assert false, 'a request asked for the reserved community scope';
  exception when check_violation then null;
  end;

  -- Consent withdrawn after the request: approval holds it as approved.
  perform set_config('app.user_id', s1::text, true);
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = q2;
  perform set_config('app.user_id', t1::text, true);
  assert app.withdraw_consent(consent, 'Guardian changed their mind') = 'withdrawn_now', 'consent was not withdrawn';
  update app.posts set moderation_state = 'approved' where id = q2;
  assert (select moderation_state = 'approved' and scope = 'class' from app.posts where id = q2),
    'a post was published after consent was withdrawn';
  begin
    update app.posts set moderation_state = 'published' where id = q2;
    assert false, 'an approved post was published without consent';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- Consent again, then publishing the approved post goes through.
  insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
    method, given_on, recorded_by)
  values (tenant, s1, 'public_work', 'Guardian', 'father', 'in_person', current_date, t1);
  update app.posts set moderation_state = 'published' where id = q2;
  assert (select moderation_state = 'published' and scope = 'public' from app.posts where id = q2),
    'the approved post was not published once consent was back';

  -- Rejection returns a post where it was: published in its class, or a draft.
  perform set_config('app.user_id', s1::text, true);
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = q3;
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = d1;
  perform set_config('app.user_id', t1::text, true);
  update app.posts set moderation_state = 'published' where id = q3;
  assert (select moderation_state = 'published' and scope = 'class' and target_scope is null and submitted_at is null
    from app.posts where id = q3), 'a rejected request did not return to the class';
  begin
    update app.posts set moderation_state = 'published' where id = d1;
    assert false, 'a rejected draft was posted';
  exception when check_violation then null;
  end;
  update app.posts set moderation_state = 'draft' where id = d1;
  -- Only the author posts a draft.
  begin
    update app.posts set moderation_state = 'published' where id = d1;
    assert false, 'a teacher posted a student''s draft';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', s1::text, true);
  update app.posts set moderation_state = 'published' where id = d1;
  assert (select published_at = now() from app.posts where id = d1), 'the posted draft has no publishing time';
  -- The author withdraws a request.
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = q3;
  update app.posts set moderation_state = 'published' where id = q3;
  assert (select moderation_state = 'published' and target_scope is null from app.posts where id = q3),
    'the author could not withdraw a request';
  -- Steps outside the diagram are refused.
  begin
    update app.posts set moderation_state = 'approved' where id = q3;
    assert false, 'a post skipped the request';
  exception when check_violation then null;
  end;

  -- Widening to the madrasa needs a teacher the admin chose (REQ-MOD-007).
  perform set_config('app.user_id', s2::text, true);
  update app.posts set moderation_state = 'submitted', target_scope = 'madrasa' where id = q4;
  perform set_config('app.user_id', t1::text, true);
  begin
    update app.posts set moderation_state = 'approved' where id = q4;
    assert false, 'a class teacher widened a post without being chosen';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', s3::text, true);
  assert not exists (select from app.posts where id = q4), 'another class saw a class post';
  perform set_config('app.user_id', t3::text, true);
  assert exists (select from app.posts where id = q4), 'the widening teacher cannot see the request';
  update app.posts set moderation_state = 'approved' where id = q4;
  assert (select moderation_state = 'published' and scope = 'madrasa' and approved_by = t3 from app.posts where id = q4),
    'the chosen teacher could not widen the post';
  perform set_config('app.user_id', s3::text, true);
  assert exists (select from app.posts where id = q4), 'a widened post is hidden from the madrasa';
  -- Any teacher may hide a madrasa-scope post; only its class teacher or an admin shows it again.
  perform set_config('app.user_id', t2::text, true);
  update app.posts set hidden_at = now() where id = q4;
  assert (select hidden_by = t2 from app.posts where id = q4), 'a teacher could not hide a madrasa post';
  begin
    update app.posts set hidden_at = null where id = q4;
    assert false, 'another teacher showed a hidden post again';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', t1::text, true);
  update app.posts set hidden_at = null where id = q4;

  -- Teacher work goes public through an editor or admin (REQ-TCH-004).
  insert into app.posts (institute_id, thread_id, post_type, language, title, body, author_user_id)
  values (tenant, thread_m, 'article', 'en', 'Wudu', 'Steps of wudu', t1) returning id into m1;
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = m1;
  begin
    update app.posts set moderation_state = 'approved' where id = m1;
    assert false, 'a teacher approved their own work';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', t3::text, true);
  begin
    update app.posts set moderation_state = 'approved' where id = m1;
    assert false, 'a teacher approved another teacher''s public work';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', editor::text, true);
  update app.posts set moderation_state = 'approved' where id = m1;
  assert (select moderation_state = 'published' and scope = 'public' and approved_by = editor from app.posts where id = m1),
    'the editor could not approve teacher work';

  -- A student's madrasa post goes public through a teacher of one of the
  -- student's classes, not any teacher who can see it (07 §8.2).
  perform set_config('app.user_id', s1::text, true);
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_m, 'message', 'en', 'Madrasa post', 'aa000000-0000-4000-8000-000000000061')
  returning id into changed_post;
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = changed_post;
  perform set_config('app.user_id', t2::text, true);
  begin
    update app.posts set moderation_state = 'approved' where id = changed_post;
    assert false, 'a teacher who does not teach the student approved their work';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', t1::text, true);
  update app.posts set moderation_state = 'approved' where id = changed_post;
  assert (select scope from app.posts where id = changed_post) = 'public', 'the student''s teacher could not approve';

  -- Takedown (REQ-CHS-004): a reason is required, the post is hidden from
  -- everyone but teachers and admins, including its author.
  perform set_config('app.user_id', s1::text, true);
  begin
    update app.posts set moderation_state = 'taken_down', takedown_reason = 'Mine' where id = q1;
    assert false, 'a student took down a post';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', t1::text, true);
  begin
    update app.posts set moderation_state = 'taken_down' where id = q1;
    assert false, 'a post was taken down without a reason';
  exception when check_violation then null;
  end;
  update app.posts set moderation_state = 'taken_down', takedown_reason = 'Personal details' where id = q1;
  select * into p from app.posts where id = q1;
  assert p.taken_down_by = t1 and p.taken_down_at = now() and p.hidden_by = t1, 'the takedown was not recorded';
  foreach changed in array array[1, 2, 3] loop
    perform set_config('app.user_id', (array[s1, s2, s3])[changed]::text, true);
    assert not exists (select from app.posts where id = q1), 'a student saw a taken-down post';
  end loop;
  perform set_config('app.user_id', t1::text, true);
  begin
    update app.posts set hidden_at = null where id = q1;
    assert false, 'a taken-down post was shown again';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.posts set moderation_state = 'submitted' where id = q1;
    assert false, 'a teacher restored a post';
  exception when insufficient_privilege then null;
  end;
  -- An admin restores a public post to a fresh request, never straight to published.
  perform set_config('app.user_id', admin::text, true);
  begin
    update app.posts set moderation_state = 'published' where id = q1;
    assert false, 'a public post was restored without fresh approval';
  exception when check_violation then null;
  end;
  update app.posts set moderation_state = 'submitted' where id = q1;
  select * into p from app.posts where id = q1;
  assert p.scope = 'class' and p.target_scope = 'public' and p.taken_down_at is null and p.approved_by is null
    and p.hidden_at is not null, 'the restore did not ask for fresh approval';
  -- Approval waits while the post is hidden, then publishes once shown.
  perform set_config('app.user_id', t1::text, true);
  update app.posts set moderation_state = 'approved' where id = q1;
  assert (select moderation_state from app.posts where id = q1) = 'approved', 'a hidden post was published';
  update app.posts set hidden_at = null where id = q1;
  update app.posts set moderation_state = 'published' where id = q1;
  assert (select scope from app.posts where id = q1) = 'public', 'the restored post was not published again';

  -- The scope and authorship never change directly.
  begin
    update app.posts set scope = 'public' where id = q3;
    assert false, 'a scope was changed directly';
  exception when insufficient_privilege then null;
  end;
end
$test$;

-- The trigger runs for the owner too. A step with no user is a system step,
-- which may only hide or take down.
reset role;
set local role tazkiyah_schema_owner;
select set_config('app.institute_id', 'aa000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', '', true);
do $test$
declare
  q3 uuid;
  q4 uuid;
begin
  select id into strict q3 from app.posts where body = 'Question three';
  select id into strict q4 from app.posts where body = 'Student two';
  begin
    update app.posts set scope = 'madrasa' where id = q3;
    assert false, 'the owner widened a post directly';
  exception when insufficient_privilege then null;
  end;
  begin
    update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = q3;
    assert false, 'a system step put a post forward';
  exception when insufficient_privilege then null;
  end;
  update app.posts set hidden_at = now(), hidden_reason = 'Three reports' where id = q3;
  assert (select hidden_at is not null and hidden_by is null from app.posts where id = q3), 'the system could not hide a post';
  update app.posts set moderation_state = 'taken_down', takedown_reason = 'Consent withdrawn' where id = q4;
  assert (select taken_down_by is null and moderation_state = 'taken_down' from app.posts where id = q4),
    'the system could not take down a post';
end
$test$;

rollback;
