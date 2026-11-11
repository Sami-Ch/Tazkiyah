-- Public student and teacher work: public_api.public_posts and
-- public_api.public_teachers (04 §6.5, §10.2, REQ-PUB-004, REQ-PUB-005,
-- REQ-CHS-005, P3-E8-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('ae000000-0000-4000-8000-000000000001', 'public-work-fixture'),
  ('ae000000-0000-4000-8000-000000000002', 'public-work-other');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
select id, '{"en":"Institute"}', '{"en":"A"}', '{}', 'PUB', array['student_hub', 'teacher_hub']
from app.institutes where slug like 'public-work-%';
insert into app.users (id, institute_id, email, username, full_name, public_name, public_bio, status, is_orphan) values
  ('ae000000-0000-4000-8000-000000000011', 'ae000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin Person', null, null, 'active', false),
  ('ae000000-0000-4000-8000-000000000021', 'ae000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Bilal Ahmad Full', 'Ustad Bilal Ahmad', '{"en":"Teaches tajweed"}', 'active', false),
  ('ae000000-0000-4000-8000-000000000022', 'ae000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', null, null, 'active', false),
  ('ae000000-0000-4000-8000-000000000031', 'ae000000-0000-4000-8000-000000000001', null, 'pub-1', 'Ayesha Khan', null, null, 'active', false),
  ('ae000000-0000-4000-8000-000000000032', 'ae000000-0000-4000-8000-000000000001', null, 'pub-2', 'Hamza Ali', null, null, 'active', false),
  ('ae000000-0000-4000-8000-000000000033', 'ae000000-0000-4000-8000-000000000001', null, 'pub-3', 'Zainab Noor', null, null, 'active', true);
insert into app.user_roles (institute_id, user_id, role)
select 'ae000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('ae000000-0000-4000-8000-000000000011', 'admin'), ('ae000000-0000-4000-8000-000000000021', 'teacher'),
  ('ae000000-0000-4000-8000-000000000022', 'teacher'), ('ae000000-0000-4000-8000-000000000031', 'student'),
  ('ae000000-0000-4000-8000-000000000032', 'student'), ('ae000000-0000-4000-8000-000000000033', 'student')) r(id, role);
insert into app.classes (id, institute_id, name, created_by) values
  ('ae000000-0000-4000-8000-000000000051', 'ae000000-0000-4000-8000-000000000001', '{"en":"A"}', 'ae000000-0000-4000-8000-000000000021');
insert into app.class_members (institute_id, class_id, user_id, member_role)
select 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000051', id::uuid, 'student'
from unnest(array['ae000000-0000-4000-8000-000000000031', 'ae000000-0000-4000-8000-000000000032',
  'ae000000-0000-4000-8000-000000000033']) id;
insert into app.media_assets (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, width, height,
  status, uploaded_by) values
  ('ae000000-0000-4000-8000-000000000071', 'ae000000-0000-4000-8000-000000000001', 'image', 'avatar', 'public',
    'ae000000-0000-4000-8000-000000000001/avatar-star.webp', 'image/webp', 1000, 96, 96, 'ready', null),
  ('ae000000-0000-4000-8000-000000000072', 'ae000000-0000-4000-8000-000000000001', 'image', 'staff_photo', 'public',
    'ae000000-0000-4000-8000-000000000001/bilal.webp', 'image/webp', 1000, 200, 200, 'ready', 'ae000000-0000-4000-8000-000000000021');
update app.users set photo_media_id = 'ae000000-0000-4000-8000-000000000072' where id = 'ae000000-0000-4000-8000-000000000021';
insert into app.personas (id, institute_id, display_name, avatar_media_id) values
  ('ae000000-0000-4000-8000-000000000061', 'ae000000-0000-4000-8000-000000000001', 'Sitara 801', 'ae000000-0000-4000-8000-000000000071'),
  ('ae000000-0000-4000-8000-000000000062', 'ae000000-0000-4000-8000-000000000001', 'Qalam 802', null),
  ('ae000000-0000-4000-8000-000000000063', 'ae000000-0000-4000-8000-000000000001', 'Jugnu 803', null);
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000061', 'ae000000-0000-4000-8000-000000000031', 'ae000000-0000-4000-8000-000000000021'),
  ('ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000062', 'ae000000-0000-4000-8000-000000000032', 'ae000000-0000-4000-8000-000000000021'),
  ('ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000063', 'ae000000-0000-4000-8000-000000000033', 'ae000000-0000-4000-8000-000000000021');
-- Student one has public_work consent; student two has none; student three
-- is an orphan whose record still waits for both sign-offs (07 §5.4).
insert into app.consent_records (id, institute_id, student_user_id, kind, guardian_name, guardian_relation, method,
  given_on, recorded_by) values
  ('ae000000-0000-4000-8000-000000000091', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000031',
    'public_work', 'Guardian', 'mother', 'in_person', current_date, 'ae000000-0000-4000-8000-000000000021'),
  ('ae000000-0000-4000-8000-000000000093', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000033',
    'public_work', 'Guardian', 'other', 'in_person', current_date, 'ae000000-0000-4000-8000-000000000021');
-- Work that went public: a thread in public scope with each student's post,
-- a teacher's verified article, a hidden one and a taken-down one; and a
-- class post that stays inside.
insert into app.threads (id, institute_id, class_id, scope, title, language, author_persona_id, author_user_id) values
  ('ae000000-0000-4000-8000-000000000081', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000051',
    'public', 'Student work', 'en', 'ae000000-0000-4000-8000-000000000061', null),
  ('ae000000-0000-4000-8000-000000000082', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000051',
    'class', 'Inside', 'en', 'ae000000-0000-4000-8000-000000000061', null);
insert into app.posts (id, institute_id, thread_id, post_type, language, title, body, author_persona_id, author_user_id,
  is_verified, verified_by, verified_at) values
  ('ae000000-0000-4000-8000-000000000101', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000081',
    'message', 'en', null, 'Sitara''s poem', 'ae000000-0000-4000-8000-000000000061', null, false, null, null),
  ('ae000000-0000-4000-8000-000000000102', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000081',
    'message', 'en', null, 'Qalam''s poem', 'ae000000-0000-4000-8000-000000000062', null, false, null, null),
  ('ae000000-0000-4000-8000-000000000103', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000081',
    'message', 'en', null, 'Jugnu''s poem', 'ae000000-0000-4000-8000-000000000063', null, false, null, null),
  ('ae000000-0000-4000-8000-000000000104', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000081',
    'article', 'en', 'Tajweed basics', 'Rules', null, 'ae000000-0000-4000-8000-000000000021', true,
    'ae000000-0000-4000-8000-000000000021', now()),
  ('ae000000-0000-4000-8000-000000000105', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000081',
    'message', 'en', null, 'Hidden one', 'ae000000-0000-4000-8000-000000000061', null, false, null, null),
  ('ae000000-0000-4000-8000-000000000106', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000081',
    'message', 'en', null, 'Taken down one', 'ae000000-0000-4000-8000-000000000061', null, false, null, null),
  ('ae000000-0000-4000-8000-000000000107', 'ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000082',
    'message', 'en', null, 'Inside only', 'ae000000-0000-4000-8000-000000000061', null, false, null, null);
select set_config('app.institute_id', 'ae000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'ae000000-0000-4000-8000-000000000011', true);
update app.posts set hidden_at = now() where id = 'ae000000-0000-4000-8000-000000000105';
update app.posts set moderation_state = 'taken_down', takedown_reason = 'Personal details'
where id = 'ae000000-0000-4000-8000-000000000106';

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'ae000000-0000-4000-8000-000000000001';
  shown record;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '', true);

  -- Visitors see published public work whose student has consent (REQ-PUB-004, REQ-CHS-005).
  assert (select array_agg(body order by body) from public_api.public_posts) = array['Rules', 'Sitara''s poem'],
    'the public posts are wrong: ' || (select string_agg(body, ', ') from public_api.public_posts);
  select * into strict shown from public_api.public_posts where body = 'Sitara''s poem';
  assert shown.author_kind = 'persona' and shown.persona_name = 'Sitara 801'
    and shown.persona_avatar_storage_key like '%avatar-star.webp' and shown.teacher_id is null,
    'the student post shows the wrong author: ' || row_to_json(shown)::text;
  assert (select string_agg(row_to_json(v)::text, ' ') from public_api.public_posts v)
    !~ '(Ayesha|Hamza|Zainab|pub-[0-9]|ae000000-0000-4000-8000-00000000003)',
    'a public post reveals a student';
  -- Teacher work shows the teacher's public name and the verifier (REQ-PUB-005, REQ-TCH-003).
  select * into strict shown from public_api.public_posts where body = 'Rules';
  assert shown.author_kind = 'teacher' and shown.teacher_name = 'Ustad Bilal Ahmad' and shown.is_verified
    and shown.verified_by_name = 'Ustad Bilal Ahmad' and shown.persona_name is null,
    'the teacher article shows the wrong author: ' || row_to_json(shown)::text;
  assert row_to_json(shown)::text !~ 'Bilal Ahmad Full|t1@example', 'the teacher''s private details show';

  -- Teachers with a public name show with their public photo; others and students do not.
  assert (select count(*) from public_api.public_teachers) = 1, 'the wrong teachers are public';
  select * into strict shown from public_api.public_teachers;
  assert shown.public_name = 'Ustad Bilal Ahmad' and shown.photo_storage_key like '%bilal.webp'
    and row_to_json(shown)::text !~ 'Bilal Ahmad Full|t1@example', 'the public teacher is wrong';

  -- Members see the same; another institute sees nothing.
  perform set_config('app.user_id', 'ae000000-0000-4000-8000-000000000032', true);
  assert (select count(*) from public_api.public_posts) = 2, 'a member sees different public posts';
  perform set_config('app.institute_id', 'ae000000-0000-4000-8000-000000000002', true);
  assert not exists (select from public_api.public_posts) and not exists (select from public_api.public_teachers),
    'public work leaked to another institute';

  -- Withdrawing consent hides the student's work at once (04 §10.2).
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', 'ae000000-0000-4000-8000-000000000021', true);
  assert app.withdraw_consent('ae000000-0000-4000-8000-000000000091', 'Guardian asked') = 'withdrawn_now',
    'the consent was not withdrawn';
  perform set_config('app.user_id', '', true);
  assert not exists (select from public_api.public_posts where author_kind = 'persona'),
    'a student''s work stayed public after consent was withdrawn';
end
$test$;

-- The module switches hide the work of the module that is off (04 §11.4).
reset role;
update app.institute_settings set enabled_modules = array['student_hub']
where institute_id = 'ae000000-0000-4000-8000-000000000001';
set local role tazkiyah_app;
do $test$
begin
  perform set_config('app.institute_id', 'ae000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '', true);
  assert not exists (select from public_api.public_posts where author_kind = 'teacher'),
    'teacher work showed with the teacher hub off';
  assert not exists (select from public_api.public_teachers), 'teachers showed with the teacher hub off';
end
$test$;

rollback;
