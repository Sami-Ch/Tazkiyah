-- Hide, remove, takedown, restore and scope widening (REQ-MOD-002, REQ-CHS-004,
-- REQ-MOD-004, REQ-MOD-007).
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('c2000000-0000-4000-8000-000000000001', 'moderation-a'),
  ('c2000000-0000-4000-8000-000000000002', 'moderation-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix) values
  ('c2000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'MDA'),
  ('c2000000-0000-4000-8000-000000000002', '{"en":"Other"}', '{"en":"B"}', '{}', 'MDB');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('c2000000-0000-4000-8000-000000000011', 'c2000000-0000-4000-8000-000000000001', 'admin@moderation-a.test', 'Admin', 'active', true, false),
  ('c2000000-0000-4000-8000-000000000021', 'c2000000-0000-4000-8000-000000000001', 'teacher@moderation-a.test', 'Class Teacher', 'active', false, false),
  ('c2000000-0000-4000-8000-000000000022', 'c2000000-0000-4000-8000-000000000001', 'other@moderation-a.test', 'Other Teacher', 'active', false, false),
  ('c2000000-0000-4000-8000-000000000091', 'c2000000-0000-4000-8000-000000000002', 'admin@moderation-b.test', 'Other Admin', 'active', true, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('c2000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000011', 'admin'),
  ('c2000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000021', 'teacher'),
  ('c2000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000022', 'teacher'),
  ('c2000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000091', 'admin');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('c2000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000011', 'secret', 'codes', true),
  ('c2000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000091', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('c2000000-0000-4000-8000-000000000061', 'c2000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000011', 'admin-session', now() + interval '1 hour', now(), now()),
  ('c2000000-0000-4000-8000-000000000062', 'c2000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000021', 'teacher-session', now() + interval '1 hour', now(), null),
  ('c2000000-0000-4000-8000-000000000063', 'c2000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000022', 'other-session', now() + interval '1 hour', now(), null),
  ('c2000000-0000-4000-8000-000000000064', 'c2000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000091', 'foreign-session', now() + interval '1 hour', now(), now());

select set_config('app.institute_id', 'c2000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'c2000000-0000-4000-8000-000000000021', true);
insert into app.classes (id, institute_id, name, created_by) values
  ('c2000000-0000-4000-8000-000000000031', 'c2000000-0000-4000-8000-000000000001', '{"en":"Hifz"}',
    'c2000000-0000-4000-8000-000000000021');
select app.create_student_account('Sample Student', 'mod-student', 'c2000000-0000-4000-8000-000000000031', false);
insert into app.threads (id, institute_id, class_id, scope, language, author_persona_id)
select 'c2000000-0000-4000-8000-000000000071', 'c2000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000031', 'class', 'ur', l.persona_id
from app.persona_links l
join app.users u on u.id = l.user_id
where u.username = 'mod-student';
insert into app.posts (id, institute_id, thread_id, post_type, language, body, scope, class_id,
  moderation_state, author_persona_id)
select 'c2000000-0000-4000-8000-000000000081', 'c2000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000071', 'message', 'ur', 'A class note', 'class',
  'c2000000-0000-4000-8000-000000000031', 'published', l.persona_id
from app.persona_links l
join app.users u on u.id = l.user_id
where u.username = 'mod-student';
insert into app.posts (id, institute_id, thread_id, post_type, language, body, scope, class_id,
  moderation_state, target_scope, submitted_at, author_persona_id)
select 'c2000000-0000-4000-8000-000000000082', 'c2000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000071', 'message', 'ur', 'Please share this', 'class',
  'c2000000-0000-4000-8000-000000000031', 'submitted', 'madrasa', now(), l.persona_id
from app.persona_links l
join app.users u on u.id = l.user_id
where u.username = 'mod-student';

reset role;
set local role tazkiyah_auth;
select set_config('app.institute_id', 'c2000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'c2000000-0000-4000-8000-000000000021', true);

do $test$
declare
  tenant constant uuid := 'c2000000-0000-4000-8000-000000000001';
  other constant uuid := 'c2000000-0000-4000-8000-000000000002';
  admin constant uuid := 'c2000000-0000-4000-8000-000000000011';
  teacher constant uuid := 'c2000000-0000-4000-8000-000000000021';
  teacher2 constant uuid := 'c2000000-0000-4000-8000-000000000022';
  admin_session constant uuid := 'c2000000-0000-4000-8000-000000000061';
  teacher_session constant uuid := 'c2000000-0000-4000-8000-000000000062';
  other_session constant uuid := 'c2000000-0000-4000-8000-000000000063';
  foreign_session constant uuid := 'c2000000-0000-4000-8000-000000000064';
  live constant uuid := 'c2000000-0000-4000-8000-000000000081';
  request constant uuid := 'c2000000-0000-4000-8000-000000000082';
  decision text;
  board jsonb;
  state text;
  scope text;
begin
  perform set_config('app.user_id', teacher2::text, true);
  decision := identity.moderate_post(other_session, live, 'hide', 'Not for this class');
  assert decision = 'denied', decision;

  perform set_config('app.user_id', teacher::text, true);
  decision := identity.moderate_post(teacher_session, live, 'hide', null);
  assert decision = 'invalid', decision;
  decision := identity.moderate_post(teacher_session, live, 'hide', 'Kept for the teacher');
  assert decision = 'hide', decision;
  board := identity.moderation_board(teacher_session);
  assert board ->> 'allowed' = 'true', 'after hide ' || board::text;
  assert exists (
    select from jsonb_array_elements(board -> 'posts') item
    where item ->> 'id' = live::text and (item ->> 'hidden')::boolean and item ->> 'state' = 'published'
  ), 'hidden post ' || board::text;
  decision := identity.moderate_post(teacher_session, live, 'unhide', null);
  assert decision = 'unhide', decision;

  decision := identity.decide_post(teacher_session, request, 'approve', null);
  assert decision = 'denied', 'a teacher widened without being chosen';
  perform set_config('app.user_id', admin::text, true);
  decision := identity.set_scope_widener(admin_session, teacher, true);
  assert decision = 'saved', decision;
  perform set_config('app.user_id', teacher::text, true);
  board := identity.moderation_board(teacher_session);
  assert board ->> 'allowed' = 'true', 'after widener ' || board::text;
  assert board ->> 'can_widen' = 'true', 'widen flag ' || board::text;
  assert exists (
    select from jsonb_array_elements(board -> 'requests') item
    where item ->> 'id' = request::text and item ->> 'state' = 'submitted'
      and item ->> 'target_scope' = 'madrasa' and (item ->> 'can_approve')::boolean
  ), board::text;
  decision := identity.decide_post(teacher_session, request, 'approve', null);
  assert decision = 'approved', decision;
  board := identity.moderation_board(teacher_session);
  assert exists (
    select from jsonb_array_elements(board -> 'posts') item
    where item ->> 'id' = request::text and item ->> 'state' = 'published' and item ->> 'scope' = 'madrasa'
  ), board::text;

  decision := identity.moderate_post(teacher_session, live, 'remove', 'Removed from the class');
  assert decision = 'remove', decision;
  board := identity.moderation_board(teacher_session);
  assert exists (
    select from jsonb_array_elements(board -> 'taken_down') item
    where item ->> 'id' = live::text and item ->> 'state' = 'taken_down'
  ), board::text;
  decision := identity.moderate_post(teacher_session, live, 'restore', null);
  assert decision = 'denied', 'a teacher restored a taken-down post';

  perform set_config('app.user_id', admin::text, true);
  decision := identity.moderate_post(admin_session, request, 'takedown', 'Not for the public page');
  assert decision = 'takedown', decision;
  board := identity.moderation_board(admin_session);
  assert exists (
    select from jsonb_array_elements(board -> 'taken_down') item
    where item ->> 'id' = request::text and item ->> 'state' = 'taken_down'
      and (item ->> 'can_restore')::boolean
  ), board::text;
  decision := identity.moderate_post(admin_session, request, 'restore', null);
  assert decision = 'restore', decision;
  board := identity.moderation_board(admin_session);
  assert exists (
    select from jsonb_array_elements(board -> 'posts') item
    where item ->> 'id' = request::text and item ->> 'state' = 'published' and item ->> 'scope' = 'madrasa'
  ), board::text;

  perform set_config('app.institute_id', other::text, true);
  perform set_config('app.user_id', 'c2000000-0000-4000-8000-000000000091', true);
  board := identity.moderation_board(foreign_session);
  assert jsonb_array_length(board -> 'posts') = 0, 'the other institute saw these posts';
  assert jsonb_array_length(board -> 'requests') = 0, 'the other institute saw this request';
  decision := identity.moderate_post(foreign_session, live, 'takedown', 'Cross tenant');
  assert decision = 'not_found', decision;
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);
  board := identity.moderation_board(admin_session);
  assert exists (
    select from jsonb_array_elements(board -> 'taken_down') item
    where item ->> 'id' = live::text and item ->> 'state' = 'taken_down'
  ), 'another institute changed this post';
end
$test$;
