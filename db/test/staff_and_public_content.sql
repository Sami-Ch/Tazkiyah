begin;
grant tazkiyah_app to current_user;
set local role tazkiyah_schema_owner;
set local plpgsql.check_asserts = on;

insert into app.institutes (id, slug) values
  ('20000000-0000-0000-0000-000000000001', 'staff-test-a'),
  ('20000000-0000-0000-0000-000000000002', 'staff-test-b');

insert into app.institute_settings (institute_id, name, theme, address, receipt_prefix) values
  ('20000000-0000-0000-0000-000000000001', '{"en":"A"}', '{}', '{"en":"A"}', 'TA'),
  ('20000000-0000-0000-0000-000000000002', '{"en":"B"}', '{}', '{"en":"B"}', 'TB');

insert into app.users (id, institute_id, email, username, full_name, status) values
  ('21000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
    'admin@example.test', null, 'Admin A', 'active'),
  ('21000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001',
    'editor@example.test', null, 'Editor A', 'active'),
  ('21000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001',
    null, 'student-001', 'Private student name', 'left'),
  ('21000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001',
    'suspended@example.test', null, 'Suspended admin', 'suspended'),
  ('21000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000002',
    'ADMIN@example.test', null, 'Admin B', 'active');

insert into app.user_roles (institute_id, user_id, role)
select institute_id, id, role from app.users
join (values
  ('21000000-0000-0000-0000-000000000001'::uuid, 'admin'),
  ('21000000-0000-0000-0000-000000000002'::uuid, 'editor'),
  ('21000000-0000-0000-0000-000000000003'::uuid, 'student'),
  ('21000000-0000-0000-0000-000000000004'::uuid, 'admin'),
  ('21000000-0000-0000-0000-000000000005'::uuid, 'admin')
) assigned(user_id, role) on id = assigned.user_id;

do $test$
begin
  begin
    insert into app.user_roles (institute_id, user_id, role)
    values ('20000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000003', 'teacher');
    raise exception 'Student received a staff role';
  exception when check_violation then
    null;
  end;
  begin
    insert into app.users (institute_id, email, full_name)
    values ('20000000-0000-0000-0000-000000000001', 'ADMIN@example.test', 'Duplicate admin A');
    raise exception 'Case-insensitive institute email uniqueness failed';
  exception when unique_violation then
    null;
  end;
end
$test$;

insert into app.media_assets (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, status, shows_face)
select media_id, tenant, 'image', purpose, visibility, tenant::text || '/image/' || media_id::text || '.webp',
  'image/webp', 10000, 'ready', shows_face
from (values
  ('22000000-0000-0000-0000-000000000001'::uuid, '20000000-0000-0000-0000-000000000001'::uuid, 'logo', 'public', false),
  ('22000000-0000-0000-0000-000000000002'::uuid, '20000000-0000-0000-0000-000000000001'::uuid, 'cover', 'public', false),
  ('22000000-0000-0000-0000-000000000003'::uuid, '20000000-0000-0000-0000-000000000001'::uuid, 'cover', 'private', false),
  ('22000000-0000-0000-0000-000000000004'::uuid, '20000000-0000-0000-0000-000000000001'::uuid, 'cover', 'public', true),
  ('22000000-0000-0000-0000-000000000005'::uuid, '20000000-0000-0000-0000-000000000002'::uuid, 'cover', 'public', false)
) media(media_id, tenant, purpose, visibility, shows_face);

update app.institute_settings set logo_media_id = '22000000-0000-0000-0000-000000000001'
where institute_id = '20000000-0000-0000-0000-000000000001';

insert into app.site_pages (institute_id, slug, title, body, cover_media_id, status, published_at) values
  ('20000000-0000-0000-0000-000000000001', 'public-page', '{"en":"Public A"}', '{"en":"A"}',
    '22000000-0000-0000-0000-000000000002', 'published', now()),
  ('20000000-0000-0000-0000-000000000001', 'private-cover', '{"en":"Private cover"}', '{"en":"A"}',
    '22000000-0000-0000-0000-000000000003', 'published', now()),
  ('20000000-0000-0000-0000-000000000001', 'face-cover', '{"en":"Face cover"}', '{"en":"A"}',
    '22000000-0000-0000-0000-000000000004', 'published', now()),
  ('20000000-0000-0000-0000-000000000001', 'draft-page', '{"en":"Draft A"}', '{"en":"Draft"}', null, 'draft', null),
  ('20000000-0000-0000-0000-000000000002', 'public-page', '{"en":"Public B"}', '{"en":"B"}',
    '22000000-0000-0000-0000-000000000005', 'published', now());

do $test$
begin
  begin
    update app.media_assets set bytes = 600001 where id = '22000000-0000-0000-0000-000000000001';
    raise exception 'Oversized image was accepted';
  exception when check_violation then
    null;
  end;
  begin
    update app.media_assets set variants = '{"w480":"20000000-0000-0000-0000-000000000002/image/other.webp"}'
    where id = '22000000-0000-0000-0000-000000000001';
    raise exception 'Another institute could supply a media variant';
  exception when check_violation then
    null;
  end;
  begin
    update app.site_pages set cover_media_id = '22000000-0000-0000-0000-000000000005'
    where institute_id = '20000000-0000-0000-0000-000000000001' and slug = 'public-page';
    raise exception 'A page accepted a cover from another institute';
  exception when foreign_key_violation then
    null;
  end;
end
$test$;

set local role tazkiyah_app;

do $test$
declare
  a constant uuid := '20000000-0000-0000-0000-000000000001';
  b constant uuid := '20000000-0000-0000-0000-000000000002';
  admin_a constant uuid := '21000000-0000-0000-0000-000000000001';
  editor_a constant uuid := '21000000-0000-0000-0000-000000000002';
  student_a constant uuid := '21000000-0000-0000-0000-000000000003';
  suspended_a constant uuid := '21000000-0000-0000-0000-000000000004';
begin
  assert not exists (select 1 from public_api.site_pages);
  assert not exists (select 1 from public_api.institute_logo);
  perform set_config('app.institute_id', a::text, true);
  assert (select count(*) from public_api.site_pages) = 3;
  assert (select count(*) from public_api.site_pages where cover_storage_key is not null) = 1;
  assert (select title ->> 'en' from public_api.site_pages where slug = 'public-page') = 'Public A';
  assert (select count(*) from public_api.institute_logo) = 1;
  assert not exists (select 1 from app.users);
  assert not exists (select 1 from app.media_assets);
  assert not exists (select 1 from app.site_pages);

  perform set_config('app.user_id', student_a::text, true);
  assert app.is_member() and not app.is_staff();
  assert (select array_agg(id) from app.users) = array[student_a];
  update app.users set preferred_language = 'ur' where id = student_a;
  assert found;
  update app.users set preferred_language = 'ur' where id = admin_a;
  assert not found;
  begin
    insert into app.user_roles (institute_id, user_id, role) values (a, student_a, 'admin');
    raise exception 'Student could grant a role';
  exception when insufficient_privilege then
    null;
  end;

  perform set_config('app.user_id', suspended_a::text, true);
  assert not app.is_staff();
  assert not exists (select 1 from app.users);

  perform set_config('app.user_id', editor_a::text, true);
  perform set_config('app.request_id', 'staff-test-request', true);
  assert app.has_role('editor') and not app.has_role('admin');
  assert (select array_agg(id) from app.users) = array[editor_a];
  assert exists (select 1 from app.site_pages where slug = 'draft-page');
  assert not exists (select 1 from app.institute_settings);
  update app.site_pages set body = '{"en":"Private draft copy"}' where slug = 'draft-page';
  assert found;
  assert not exists (select 1 from app.audit_log);
  begin
    insert into app.site_pages (institute_id, slug, title, body)
    values (b, 'cross-tenant', '{"en":"Other institute"}', '{"en":"Other institute"}');
    raise exception 'Editor could insert into another institute';
  exception when insufficient_privilege then
    null;
  end;

  perform set_config('app.user_id', admin_a::text, true);
  assert app.has_role('admin');
  assert (select count(*) from app.users) = 4;
  assert exists (select 1 from app.audit_log
    where actor_user_id = editor_a and action = 'site_pages.update'
      and request_id = 'staff-test-request' and changes = '{"body":"[redacted]"}'::jsonb);
  assert (select count(*) from app.audit_log) = 1;
  assert not has_table_privilege(current_user, 'app.audit_log', 'INSERT, UPDATE, DELETE, TRUNCATE');
  perform set_config('app.institute_id', b::text, true);
  assert not app.has_role('admin');
  assert not exists (select 1 from app.audit_log);
  assert not exists (select 1 from public_api.institute_logo);
  assert (select title ->> 'en' from public_api.site_pages where slug = 'public-page') = 'Public B';
end
$test$;

set local role tazkiyah_schema_owner;
do $test$
begin
  begin
    update app.audit_log set changes = '{}' where request_id = 'staff-test-request';
    raise exception 'Audit update was accepted';
  exception when object_not_in_prerequisite_state then
    null;
  end;
  begin
    delete from app.audit_log where request_id = 'staff-test-request';
    raise exception 'Audit deletion was accepted';
  exception when object_not_in_prerequisite_state then
    null;
  end;
  begin
    truncate app.audit_log;
    raise exception 'Audit truncate was accepted';
  exception when object_not_in_prerequisite_state then
    null;
  end;
end
$test$;

rollback;
