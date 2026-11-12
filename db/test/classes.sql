-- Classes, members and the class helpers (04 §6.2, §7.3, P3-E1-T40).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a4000000-0000-4000-8000-000000000001', 'class-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('a4000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'CLS');
insert into app.users (id, institute_id, email, full_name, status, username) values
  ('a4000000-0000-4000-8000-000000000011', 'a4000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active', null),
  ('a4000000-0000-4000-8000-000000000021', 'a4000000-0000-4000-8000-000000000001', 't1@example.test', 'Teacher One', 'active', null),
  ('a4000000-0000-4000-8000-000000000022', 'a4000000-0000-4000-8000-000000000001', 't2@example.test', 'Teacher Two', 'active', null),
  ('a4000000-0000-4000-8000-000000000031', 'a4000000-0000-4000-8000-000000000001', null, 'Student One', 'active', 'student.one'),
  ('a4000000-0000-4000-8000-000000000032', 'a4000000-0000-4000-8000-000000000001', null, 'Student Two', 'active', 'student.two'),
  ('a4000000-0000-4000-8000-000000000041', 'a4000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active', null);
insert into app.user_roles (institute_id, user_id, role) values
  ('a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000011', 'admin'),
  ('a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000021', 'teacher'),
  ('a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000022', 'teacher'),
  ('a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000031', 'student'),
  ('a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000032', 'student'),
  ('a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000041', 'editor');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a4000000-0000-4000-8000-000000000001';
  admin constant uuid := 'a4000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'a4000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'a4000000-0000-4000-8000-000000000022';
  s1 constant uuid := 'a4000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'a4000000-0000-4000-8000-000000000032';
  editor constant uuid := 'a4000000-0000-4000-8000-000000000041';
  hifz constant uuid := 'a4000000-0000-4000-8000-000000000051';
  changed bigint;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- An editor cannot create a class; a teacher can, and joins it as its teacher.
  perform set_config('app.user_id', editor::text, true);
  begin
    insert into app.classes (id, institute_id, name, created_by) values (hifz, tenant, '{"en":"Hifz 1"}', editor);
    assert false, 'an editor created a class';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', t1::text, true);
  insert into app.classes (id, institute_id, name, year_label, created_by)
  values (hifz, tenant, '{"en":"Hifz 1","ur":"حفظ ۱"}', '2026', t1);
  assert app.is_class_teacher(hifz) and app.is_class_member(hifz);
  assert (select count(*) from app.class_members where class_id = hifz and member_role = 'teacher') = 1;

  -- The class teacher adds students, not teachers, and only holders of the role.
  insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
  values (tenant, hifz, s1, 'student', t1);
  begin
    insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
    values (tenant, hifz, t2, 'teacher', t1);
    assert false, 'a class teacher added a teacher';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
    values (tenant, hifz, editor, 'student', t1);
    assert false, 'an editor joined as a student';
  exception when check_violation then null;
  end;
  begin
    insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
    values (tenant, hifz, s1, 'student', t1);
    assert false, 'a student joined the same class twice';
  exception when unique_violation then null;
  end;
  update app.classes set name = '{"en":"Hifz One"}' where id = hifz;

  -- Another teacher sees nothing of the class until an admin adds them.
  perform set_config('app.user_id', t2::text, true);
  assert not exists (select from app.classes) and not exists (select from app.class_members);
  assert not app.is_teacher_of(s1);
  update app.classes set name = '{"en":"Taken"}' where id = hifz;
  get diagnostics changed = row_count;
  assert changed = 0, 'another teacher renamed the class';
  perform set_config('app.user_id', admin::text, true);
  insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
  values (tenant, hifz, t2, 'teacher', admin);
  perform set_config('app.user_id', t2::text, true);
  assert app.is_teacher_of(s1);

  -- A student reads the class and only their own membership.
  perform set_config('app.user_id', s1::text, true);
  assert (select count(*) from app.classes) = 1;
  assert (select array_agg(user_id) from app.class_members) = array[s1];
  assert not app.is_class_teacher(hifz);

  -- Teachers trace students they teach, past students too, but not others.
  perform set_config('app.user_id', t1::text, true);
  assert app.is_teacher_of(s1) and not app.is_teacher_of(s2);
  update app.class_members set ended_at = current_date where user_id = s1;
  assert app.is_teacher_of(s1), 'a student who left stopped being traceable by their teacher';
  begin
    update app.class_members set ended_at = current_date where user_id = s1;
    assert false, 'an ended membership changed again';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    delete from app.class_members where user_id = s1;
    assert false, 'a membership was deleted';
  exception when insufficient_privilege then null;
  end;

  -- A teacher whose own membership ended no longer traces the class's students.
  perform set_config('app.user_id', admin::text, true);
  update app.class_members set ended_at = current_date where user_id = t1;
  perform set_config('app.user_id', t1::text, true);
  assert not app.is_teacher_of(s1) and not app.is_class_teacher(hifz);
end
$test$;
