-- Public-request approval checks consent and faces (P3-E5-T05, P3-E5-T08).
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('b8000000-0000-4000-8000-000000000001', 'staff-moderation');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('b8000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SMD');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('b8000000-0000-4000-8000-000000000011', 'b8000000-0000-4000-8000-000000000001', 'admin@staff-moderation.test', 'Admin', 'active', true, false),
  ('b8000000-0000-4000-8000-000000000021', 'b8000000-0000-4000-8000-000000000001', 'teacher@staff-moderation.test', 'Class Teacher', 'active', false, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('b8000000-0000-4000-8000-000000000001', 'b8000000-0000-4000-8000-000000000011', 'admin'),
  ('b8000000-0000-4000-8000-000000000001', 'b8000000-0000-4000-8000-000000000021', 'teacher');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('b8000000-0000-4000-8000-000000000001', 'b8000000-0000-4000-8000-000000000011', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('b8000000-0000-4000-8000-000000000061', 'b8000000-0000-4000-8000-000000000001', 'b8000000-0000-4000-8000-000000000021', 'teacher-session', now() + interval '1 hour', now(), null);

select set_config('app.institute_id', 'b8000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'b8000000-0000-4000-8000-000000000021', true);
insert into app.classes (id, institute_id, name, created_by) values
  ('b8000000-0000-4000-8000-000000000031', 'b8000000-0000-4000-8000-000000000001', '{"en":"Hifz"}', 'b8000000-0000-4000-8000-000000000021');
select app.create_student_account('Ahmed Raza', 'smd-student', 'b8000000-0000-4000-8000-000000000031', false);

insert into app.threads (id, institute_id, class_id, scope, language, author_persona_id)
select 'b8000000-0000-4000-8000-000000000071', 'b8000000-0000-4000-8000-000000000001',
  'b8000000-0000-4000-8000-000000000031', 'class', 'ur', l.persona_id
from app.persona_links l
where l.user_id = (select id from app.users where username = 'smd-student');
insert into app.posts (id, institute_id, thread_id, post_type, language, body, scope, class_id,
  moderation_state, target_scope, submitted_at, author_persona_id)
select 'b8000000-0000-4000-8000-000000000081', 'b8000000-0000-4000-8000-000000000001',
  'b8000000-0000-4000-8000-000000000071', 'message', 'ur', 'A question for the class', 'class',
  'b8000000-0000-4000-8000-000000000031', 'submitted', 'public', now(), l.persona_id
from app.persona_links l
where l.user_id = (select id from app.users where username = 'smd-student');
insert into app.media_assets (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes,
  width, height, status, uploaded_by, shows_face) values
  ('b8000000-0000-4000-8000-000000000091', 'b8000000-0000-4000-8000-000000000001', 'image', 'post', 'private',
    'b8000000-0000-4000-8000-000000000001/face.webp', 'image/webp', 1000, 96, 96, 'ready',
    'b8000000-0000-4000-8000-000000000021', true);
insert into app.post_media (institute_id, post_id, media_asset_id, position) values
  ('b8000000-0000-4000-8000-000000000001', 'b8000000-0000-4000-8000-000000000081',
    'b8000000-0000-4000-8000-000000000091', 1);

reset role;
set local role tazkiyah_auth;
select set_config('app.institute_id', 'b8000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'b8000000-0000-4000-8000-000000000021', true);

do $test$
declare
  teacher_session constant uuid := 'b8000000-0000-4000-8000-000000000061';
  post_id constant uuid := 'b8000000-0000-4000-8000-000000000081';
  queue jsonb;
  decision text;
begin
  queue := identity.moderation_queue(teacher_session);
  assert exists (
    select from jsonb_array_elements(queue -> 'items') item
    where item ->> 'id' = post_id::text
      and (item ->> 'needs_public_consent')::boolean
      and not (item ->> 'public_consent')::boolean
      and (item ->> 'shows_face')::boolean
  ), queue::text;
  decision := identity.decide_post(teacher_session, post_id, 'approve', null);
  assert decision = 'needs_consent', decision;
end
$test$;

set local role tazkiyah_schema_owner;
insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
  method, given_on, recorded_by)
select 'b8000000-0000-4000-8000-000000000001', id, 'public_work', 'Guardian', 'father', 'in_person',
  current_date, 'b8000000-0000-4000-8000-000000000021'
from app.users where username = 'smd-student';

set local role tazkiyah_auth;
do $test$
declare
  teacher_session constant uuid := 'b8000000-0000-4000-8000-000000000061';
  post_id constant uuid := 'b8000000-0000-4000-8000-000000000081';
  decision text;
begin
  decision := identity.decide_post(teacher_session, post_id, 'approve', null);
  assert decision = 'face_blocked', decision;
end
$test$;

set local role tazkiyah_schema_owner;
update app.media_assets set shows_face = false where id = 'b8000000-0000-4000-8000-000000000091';
set local role tazkiyah_auth;
do $test$
declare
  teacher_session constant uuid := 'b8000000-0000-4000-8000-000000000061';
  post_id constant uuid := 'b8000000-0000-4000-8000-000000000081';
  decision text;
begin
  decision := identity.decide_post(teacher_session, post_id, 'approve', null);
  assert decision = 'approved', decision;
end
$test$;
