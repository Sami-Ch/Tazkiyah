-- Personas, persona links and student account creation (04 §7.4, §7.5,
-- 07 §4, P3-E1-T41).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a5000000-0000-4000-8000-000000000001', 'persona-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('a5000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'PER');
insert into app.users (id, institute_id, email, full_name, status, must_change_password, two_factor_enabled) values
  ('a5000000-0000-4000-8000-000000000011', 'a5000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active', false, true),
  ('a5000000-0000-4000-8000-000000000021', 'a5000000-0000-4000-8000-000000000001', 't1@example.test', 'Teacher One', 'active', false, false),
  ('a5000000-0000-4000-8000-000000000022', 'a5000000-0000-4000-8000-000000000001', 't2@example.test', 'Teacher Two', 'active', false, false),
  ('a5000000-0000-4000-8000-000000000041', 'a5000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active', false, false),
  ('a5000000-0000-4000-8000-000000000042', 'a5000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active', false, true);
insert into app.user_roles (institute_id, user_id, role) values
  ('a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000011', 'admin'),
  ('a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000021', 'teacher'),
  ('a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000022', 'teacher'),
  ('a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000041', 'editor'),
  ('a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000042', 'finance_officer');
-- Each teacher creates a class and joins it as its teacher; one class is archived.
insert into app.classes (id, institute_id, name, created_by, archived_at) values
  ('a5000000-0000-4000-8000-000000000051', 'a5000000-0000-4000-8000-000000000001', '{"en":"Hifz 1"}', 'a5000000-0000-4000-8000-000000000021', null),
  ('a5000000-0000-4000-8000-000000000052', 'a5000000-0000-4000-8000-000000000001', '{"en":"Urdu"}', 'a5000000-0000-4000-8000-000000000022', null),
  ('a5000000-0000-4000-8000-000000000053', 'a5000000-0000-4000-8000-000000000001', '{"en":"Old"}', 'a5000000-0000-4000-8000-000000000021', now());
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('a5000000-0000-4000-8000-000000000061', 'a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000021', 'persona-t1', now() + interval '1 hour', now(), null),
  ('a5000000-0000-4000-8000-000000000062', 'a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000022', 'persona-t2', now() + interval '1 hour', now(), null),
  ('a5000000-0000-4000-8000-000000000063', 'a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000041', 'persona-editor', now() + interval '1 hour', now(), null),
  ('a5000000-0000-4000-8000-000000000064', 'a5000000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000011', 'persona-admin', now() + interval '1 hour', now(), now());
insert into app.media_assets
  (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, width, height, status, uploaded_by, shows_face)
values
  ('a5000000-0000-4000-8000-000000000071', 'a5000000-0000-4000-8000-000000000001', 'image', 'avatar', 'public',
    'a5000000-0000-4000-8000-000000000001/avatar-moon.webp', 'image/webp', 1000, 96, 96, 'ready', 'a5000000-0000-4000-8000-000000000011', false),
  ('a5000000-0000-4000-8000-000000000072', 'a5000000-0000-4000-8000-000000000001', 'image', 'post', 'private',
    'a5000000-0000-4000-8000-000000000001/selfie.webp', 'image/webp', 1000, 96, 96, 'ready', 'a5000000-0000-4000-8000-000000000011', true);

-- Staff create student accounts through the auth entry point.
reset role;
set local role tazkiyah_auth;
do $test$
declare
  tenant constant text := 'a5000000-0000-4000-8000-000000000001';
  hash constant text := repeat('h', 64);
  hifz constant uuid := 'a5000000-0000-4000-8000-000000000051';
  urdu constant uuid := 'a5000000-0000-4000-8000-000000000052';
  old_class constant uuid := 'a5000000-0000-4000-8000-000000000053';
  made text;
begin
  perform set_config('app.institute_id', tenant, true);

  -- A teacher creates students in their own open class only.
  perform set_config('app.user_id', 'a5000000-0000-4000-8000-000000000021', true);
  made := identity.create_student_account('a5000000-0000-4000-8000-000000000061', 'Ahmed Raza', hash, hifz, false);
  assert made = 'per-' || extract(year from now()) || '-0001', 'unexpected username ' || coalesce(made, 'null');
  perform set_config('test.s1', made, true);
  made := identity.create_student_account('a5000000-0000-4000-8000-000000000061', 'Bilal Khan', hash, hifz, true);
  perform set_config('test.s2', made, true);
  assert identity.create_student_account('a5000000-0000-4000-8000-000000000061', 'Not Mine', hash, urdu, false) is null,
    'a teacher created a student in another teacher''s class';
  assert identity.create_student_account('a5000000-0000-4000-8000-000000000061', 'Archived', hash, old_class, false) is null,
    'a student was created in an archived class';
  assert identity.create_student_account('a5000000-0000-4000-8000-000000000061', 'No Class', hash, null, false) is null,
    'a student was created without a class';

  -- An editor cannot create students; an admin can, in any class.
  perform set_config('app.user_id', 'a5000000-0000-4000-8000-000000000041', true);
  assert identity.create_student_account('a5000000-0000-4000-8000-000000000063', 'Editor Made', hash, hifz, false) is null,
    'an editor created a student';
  perform set_config('app.user_id', 'a5000000-0000-4000-8000-000000000011', true);
  made := identity.create_student_account('a5000000-0000-4000-8000-000000000064', 'Hamza Ali', hash, urdu, false);
  assert made is not null, 'an admin could not create a student';
  perform set_config('test.s3', made, true);
end
$test$;

reset role;
set local role tazkiyah_schema_owner;
do $test$
declare
  tenant constant uuid := 'a5000000-0000-4000-8000-000000000001';
  s2 uuid := (select id from app.users where username = current_setting('test.s2'));
  name text;
begin
  -- Each student has the role, a membership, a credential, one persona with a
  -- generated name, and a link recorded by the creator.
  assert (select count(*) from app.users u
    join app.user_roles r on (r.institute_id, r.user_id, r.role) = (u.institute_id, u.id, 'student')
    join app.class_members m on (m.institute_id, m.user_id, m.member_role) = (u.institute_id, u.id, 'student')
    join identity.accounts a on (a.institute_id, a.user_id) = (u.institute_id, u.id)
    join app.persona_links l on (l.institute_id, l.user_id) = (u.institute_id, u.id)
    join app.personas p on (p.institute_id, p.id) = (l.institute_id, l.persona_id)
    where u.institute_id = tenant and u.must_change_password and u.status = 'active'
      and p.display_name ~ '^[A-Za-z]+ [0-9]{3,4}$' and p.is_active and not p.show_real_name) = 3,
    'a student account is missing a part';
  assert (select is_orphan from app.users where id = s2), 'the orphan flag was not stored';
  assert (select created_by from app.persona_links where user_id = s2) = 'a5000000-0000-4000-8000-000000000021';
  assert exists (select from app.audit_log where institute_id = tenant and action = 'users.insert'
    and entity_id = s2::text and actor_user_id = 'a5000000-0000-4000-8000-000000000021'),
    'account creation was not audited';
  assert not exists (select from app.audit_log where institute_id = tenant and changes::text ~ 'Bilal'),
    'the audit log holds a student''s real name';

  -- A generated name never uses a word from a real name in the institute.
  insert into app.users (institute_id, full_name, username, status)
  select tenant, w || ' Test', 'name-' || lower(w), 'active'
  from unnest(array['Sitara', 'Chinar', 'Jugnu', 'Darya', 'Badal', 'Kitab', 'Hilal', 'Zaitoon', 'Anaar',
    'Sanober', 'Shahtoot', 'Pahar', 'Barish', 'Kehkashan', 'Titli', 'Bulbul', 'Diya', 'Sahil', 'Shabnam']) w;
  for i in 1..10 loop
    name := app.generate_persona_name(tenant);
    assert name like 'Qalam %', 'a generated name used a real name: ' || name;
  end loop;

  -- Rows come only from the function.
  assert not has_table_privilege('tazkiyah_app', 'app.personas', 'insert')
    and not has_table_privilege('tazkiyah_app', 'app.persona_links', 'insert')
    and not has_table_privilege('tazkiyah_app', 'app.persona_links', 'update')
    and not has_table_privilege('tazkiyah_app', 'app.persona_links', 'delete')
    and not has_table_privilege('tazkiyah_app', 'app.personas', 'delete')
    and not has_column_privilege('tazkiyah_app', 'app.personas', 'show_real_name', 'update');
  assert not has_function_privilege('tazkiyah_app', 'app.create_student_account(text, text, uuid, boolean)', 'execute')
    and not has_function_privilege('tazkiyah_auth', 'app.create_student_account(text, text, uuid, boolean)', 'execute');
end
$test$;

set local role tazkiyah_app;
do $test$
declare
  tenant constant text := 'a5000000-0000-4000-8000-000000000001';
  admin constant text := 'a5000000-0000-4000-8000-000000000011';
  t1 constant text := 'a5000000-0000-4000-8000-000000000021';
  t2 constant text := 'a5000000-0000-4000-8000-000000000022';
  editor constant text := 'a5000000-0000-4000-8000-000000000041';
  finance constant text := 'a5000000-0000-4000-8000-000000000042';
  s1 uuid;
  s2 uuid;
  s3 uuid;
  p1 uuid;
  p2 uuid;
  changed bigint;
begin
  perform set_config('app.institute_id', tenant, true);
  perform set_config('app.user_id', admin, true);
  select id into s1 from app.users where username = current_setting('test.s1');
  select id into s2 from app.users where username = current_setting('test.s2');
  select id into s3 from app.users where username = current_setting('test.s3');
  select persona_id into p1 from app.persona_links where user_id = s1;
  select persona_id into p2 from app.persona_links where user_id = s2;
  assert s1 is not null and s2 is not null and p1 is not null and p2 is not null;

  -- §7.5 test 1: a student sees a classmate's persona, never the link or user row.
  perform set_config('app.user_id', s1::text, true);
  assert app.current_persona_id() = p1;
  assert (select count(*) from app.personas where id = p2) = 1, 'a student cannot see a classmate''s persona';
  assert not exists (select from app.persona_links where user_id = s2), 'a student read a classmate''s persona link';
  assert not exists (select from app.users where id = s2), 'a student read a classmate''s user row';
  assert (select array_agg(user_id) from app.persona_links) = array[s1], 'a student sees links beyond their own';
  assert app.can_trace_persona(p1) and not app.can_trace_persona(p2);

  -- §7.5 test 2: the class teacher traces the student; an unrelated teacher cannot.
  perform set_config('app.user_id', t1, true);
  assert (select count(*) from app.persona_links where user_id = s2) = 1, 'the class teacher cannot trace a student';
  assert (select full_name from app.users where id = s2) = 'Bilal Khan', 'the class teacher cannot see the real student';
  assert app.can_trace_persona(p2);
  perform set_config('app.user_id', t2, true);
  assert not exists (select from app.persona_links where user_id in (s1, s2)), 'an unrelated teacher traced a student';
  assert not exists (select from app.users where id in (s1, s2)), 'an unrelated teacher read a student';
  assert (select count(*) from app.persona_links where user_id = s3) = 1;
  assert not app.can_trace_persona(p1);

  -- §7.5 test 3: editors and finance officers see personas but no links.
  foreach changed in array array[1, 2] loop
    perform set_config('app.user_id', case changed when 1 then editor else finance end, true);
    assert not exists (select from app.persona_links), 'staff outside teaching read persona links';
    assert (select count(*) from app.personas) = 3;
    assert not app.can_trace_persona(p1);
  end loop;
  perform set_config('app.user_id', admin, true);
  assert (select count(*) from app.persona_links) = 3 and app.can_trace_persona(p1);

  -- Visitors and donors see no persona rows directly.
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.personas) and not exists (select from app.persona_links);

  -- The student personalises the persona within the rules.
  perform set_config('app.user_id', s1::text, true);
  update app.personas set display_name = 'ستارہ صبح', bio = 'I like poems.', bio_language = 'en',
    avatar_media_id = 'a5000000-0000-4000-8000-000000000071' where id = p1;
  get diagnostics changed = row_count;
  assert changed = 1, 'a student could not edit their persona';
  begin
    update app.personas set display_name = 'Taken Name' where id = p2;
    get diagnostics changed = row_count;
    assert changed = 0, 'a student edited a classmate''s persona';
  end;
  update app.personas set display_name = 'Sky Reader' where id = p1;
  begin
    perform set_config('app.user_id', s2::text, true);
    update app.personas set display_name = 'SKY READER' where id = p2;
    assert false, 'two personas share a name';
  exception when unique_violation then null;
  end;
  perform set_config('app.user_id', s1::text, true);
  declare
    bad text;
  begin
    foreach bad in array array['0300 1234567', 'Me 03001234567', '+92 300 1234567', '۰۳۰۰۱۲۳۴۵۶۷', 'ab', '12345',
      'name@gmail.com', 'wa.me/923001234567', ' Padded', 'This name is far too long to use']
    loop
      begin
        update app.personas set display_name = bad where id = p1;
        assert false, 'an unsafe display name was accepted: ' || bad;
      exception when check_violation then null;
      end;
    end loop;
    foreach bad in array array['Call 0300-123-4567', 'name@gmail.com', 'name at gmail dot com',
      'chat on wa.me/923001234567', 'instagram.com/someone', 'میرا ای میل علی ایٹ جی میل ڈاٹ کام', repeat('x', 161)]
    loop
      begin
        update app.personas set bio = bad where id = p1;
        assert false, 'an unsafe bio was accepted: ' || bad;
      exception when check_violation then null;
      end;
    end loop;
  end;
  begin
    update app.personas set avatar_media_id = 'a5000000-0000-4000-8000-000000000072' where id = p1;
    assert false, 'a photo became an avatar';
  exception when check_violation then null;
  end;
  begin
    update app.personas set show_real_name = true where id = p1;
    assert false, 'the real name was switched on without consent';
  exception when insufficient_privilege then null;
  end;
  begin
    update app.personas set is_active = false where id = p1;
    assert false, 'a student switched their persona off';
  exception when insufficient_privilege then null;
  end;
  begin
    update app.persona_links set user_id = s2 where user_id = s1;
    assert false, 'a persona link changed';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into app.personas (institute_id, display_name) values (tenant::uuid, 'Second Self');
    assert false, 'a student made a second persona';
  exception when insufficient_privilege then null;
  end;

  -- A teacher of the student resets an unsuitable name; an admin switches a persona off.
  perform set_config('app.user_id', t1, true);
  update app.personas set display_name = 'Qalam 500', bio = null, bio_language = null where id = p1;
  get diagnostics changed = row_count;
  assert changed = 1, 'the class teacher could not reset a persona';
  perform set_config('app.user_id', t2, true);
  update app.personas set bio = null where id = p1;
  get diagnostics changed = row_count;
  assert changed = 0, 'an unrelated teacher changed a persona';
  perform set_config('app.user_id', admin, true);
  update app.personas set is_active = false where id = p2;
  update app.personas set is_active = true where id = p2;

  -- §7.5 test 4: a student who leaves keeps the persona, and the former teacher still traces.
  update app.class_members set ended_at = current_date where user_id = s2;
  perform set_config('app.user_id', s2::text, true);
  assert app.current_persona_id() = p2, 'a student who left lost their persona';
  update app.personas set bio = 'Still here.' where id = p2;
  get diagnostics changed = row_count;
  assert changed = 1, 'a student who left cannot edit their persona';
  perform set_config('app.user_id', t1, true);
  assert (select count(*) from app.persona_links where user_id = s2) = 1, 'a student who left is no longer traceable';
end
$test$;

-- §7.5 test 4 continued: a departed status changes nothing about access.
reset role;
set local role tazkiyah_schema_owner;
update app.users set status = 'left', left_at = current_date
where username = current_setting('test.s2');
set local role tazkiyah_app;
do $test$
declare
  s2 uuid;
begin
  perform set_config('app.institute_id', 'a5000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', 'a5000000-0000-4000-8000-000000000021', true);
  select user_id into s2 from app.persona_links l join app.users u on u.id = l.user_id
  where u.username = current_setting('test.s2');
  assert s2 is not null, 'the former teacher cannot trace a student marked as left';
  perform set_config('app.user_id', s2::text, true);
  assert app.current_persona_id() is not null, 'a student marked as left lost their persona';
end
$test$;

-- §7.5 test 5: no public view reads persona links or a student's private
-- user fields.
reset role;
do $test$
declare
  used text;
begin
  select string_agg(u.view_name || ' uses ' || u.table_name || '.' || u.column_name, ', ') into used
  from information_schema.view_column_usage u
  where u.view_schema = 'public_api' and u.table_schema = 'app'
    and (u.table_name = 'persona_links'
      or (u.table_name = 'users' and u.column_name in
        ('full_name', 'username', 'email', 'date_of_birth', 'is_orphan', 'photo_media_id', 'left_at')))
    -- A teacher's public photo: that view admits only teachers, and a student
    -- cannot also hold a staff role (P3-E8-T40).
    and not (u.view_name = 'public_teachers' and u.column_name = 'photo_media_id');
  assert used is null, 'a public view reads private student data: ' || used;
end
$test$;
