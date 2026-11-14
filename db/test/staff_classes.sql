-- Class creation and D-129 membership (P3-E1-T06, P3-E1-T07).
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('b7000000-0000-4000-8000-000000000001', 'staff-classes');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('b7000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SCL');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('b7000000-0000-4000-8000-000000000011', 'b7000000-0000-4000-8000-000000000001', 'admin@staff-classes.test', 'Admin', 'active', true, false),
  ('b7000000-0000-4000-8000-000000000021', 'b7000000-0000-4000-8000-000000000001', 't1@staff-classes.test', 'Teacher One', 'active', false, false),
  ('b7000000-0000-4000-8000-000000000022', 'b7000000-0000-4000-8000-000000000001', 't2@staff-classes.test', 'Teacher Two', 'active', false, false),
  ('b7000000-0000-4000-8000-000000000041', 'b7000000-0000-4000-8000-000000000001', 'editor@staff-classes.test', 'Editor', 'active', false, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('b7000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000011', 'admin'),
  ('b7000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000021', 'teacher'),
  ('b7000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000022', 'teacher'),
  ('b7000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000041', 'editor');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('b7000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000011', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('b7000000-0000-4000-8000-000000000061', 'b7000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000011', 'admin-session', now() + interval '1 hour', now(), now()),
  ('b7000000-0000-4000-8000-000000000062', 'b7000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000021', 'teacher-session', now() + interval '1 hour', now(), null),
  ('b7000000-0000-4000-8000-000000000063', 'b7000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000041', 'editor-session', now() + interval '1 hour', now(), null);

reset role;
set local role tazkiyah_auth;
select set_config('app.institute_id', 'b7000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'b7000000-0000-4000-8000-000000000021', true);

do $test$
declare
  admin_session constant uuid := 'b7000000-0000-4000-8000-000000000061';
  teacher_session constant uuid := 'b7000000-0000-4000-8000-000000000062';
  editor_session constant uuid := 'b7000000-0000-4000-8000-000000000063';
  admin_user constant uuid := 'b7000000-0000-4000-8000-000000000011';
  teacher constant uuid := 'b7000000-0000-4000-8000-000000000021';
  other_teacher constant uuid := 'b7000000-0000-4000-8000-000000000022';
  saved_code text;
  room_id uuid;
  workspace jsonb;
  student_name text;
begin
  perform set_config('app.user_id', 'b7000000-0000-4000-8000-000000000041', true);
  select code into saved_code from identity.save_class(
    editor_session, null, '{"en":"Nope"}'::jsonb, null, false);
  assert saved_code = 'denied', saved_code;

  perform set_config('app.user_id', teacher::text, true);
  select code, class_id into saved_code, room_id from identity.save_class(
    teacher_session, null, '{"ur":"حفظ","en":"Hifz"}'::jsonb, '2026', false);
  assert saved_code = 'saved', saved_code;

  workspace := identity.class_workspace(teacher_session);
  assert exists (
    select from jsonb_array_elements(workspace -> 'classes') room
    where room ->> 'id' = room_id::text
      and exists (
        select from jsonb_array_elements(room -> 'teachers') member
        where member ->> 'user_id' = teacher::text
      )
  ), 'creator was not joined as teacher';

  assert identity.set_class_member(teacher_session, room_id, other_teacher, 'teacher', 'add') = 'denied',
    'a class teacher added another teacher';

  perform set_config('app.user_id', admin_user::text, true);
  assert identity.set_class_member(admin_session, room_id, other_teacher, 'teacher', 'add') = 'added',
    'admin could not add a teacher';

  perform set_config('app.user_id', teacher::text, true);
  student_name := identity.create_student_account(
    teacher_session, 'Ahmed Raza', repeat('h', 64), room_id, false);
  assert student_name is not null, 'student was not created';
  workspace := identity.class_workspace(teacher_session);
  assert exists (
    select from jsonb_array_elements(workspace -> 'classes') room
    cross join jsonb_array_elements(room -> 'students') student
    where room ->> 'id' = room_id::text and student ->> 'real_name' = 'Ahmed Raza'
  ), 'class teacher could not see the student name';

  perform set_config('app.user_id', 'b7000000-0000-4000-8000-000000000041', true);
  assert identity.class_workspace(editor_session) ->> 'allowed' = 'false', 'editor opened classes';
end
$test$;
