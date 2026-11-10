-- Post media and the face flag rules (04 §11.4, §11.7, 07 §11, §12.1,
-- REQ-CHS-001, REQ-PRF-004, P3-E4-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a9000000-0000-4000-8000-000000000001', 'media-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
values ('a9000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'MED',
  array['student_hub', 'teacher_hub']);
insert into app.users (id, institute_id, email, username, full_name, status) values
  ('a9000000-0000-4000-8000-000000000011', 'a9000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin', 'active'),
  ('a9000000-0000-4000-8000-000000000021', 'a9000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active'),
  ('a9000000-0000-4000-8000-000000000022', 'a9000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active'),
  ('a9000000-0000-4000-8000-000000000031', 'a9000000-0000-4000-8000-000000000001', null, 'media-1', 'Student One', 'active'),
  ('a9000000-0000-4000-8000-000000000032', 'a9000000-0000-4000-8000-000000000001', null, 'media-2', 'Student Two', 'active'),
  ('a9000000-0000-4000-8000-000000000033', 'a9000000-0000-4000-8000-000000000001', null, 'media-3', 'Student Three', 'active');
insert into app.user_roles (institute_id, user_id, role)
select 'a9000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('a9000000-0000-4000-8000-000000000011', 'admin'), ('a9000000-0000-4000-8000-000000000021', 'teacher'),
  ('a9000000-0000-4000-8000-000000000022', 'teacher'), ('a9000000-0000-4000-8000-000000000031', 'student'),
  ('a9000000-0000-4000-8000-000000000032', 'student'), ('a9000000-0000-4000-8000-000000000033', 'student')) r(id, role);
insert into app.classes (id, institute_id, name, created_by) values
  ('a9000000-0000-4000-8000-000000000051', 'a9000000-0000-4000-8000-000000000001', '{"en":"A"}', 'a9000000-0000-4000-8000-000000000021'),
  ('a9000000-0000-4000-8000-000000000052', 'a9000000-0000-4000-8000-000000000001', '{"en":"B"}', 'a9000000-0000-4000-8000-000000000022');
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000051', 'a9000000-0000-4000-8000-000000000031', 'student'),
  ('a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000051', 'a9000000-0000-4000-8000-000000000032', 'student'),
  ('a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000052', 'a9000000-0000-4000-8000-000000000033', 'student');
insert into app.personas (id, institute_id, display_name) values
  ('a9000000-0000-4000-8000-000000000061', 'a9000000-0000-4000-8000-000000000001', 'Sitara 301'),
  ('a9000000-0000-4000-8000-000000000062', 'a9000000-0000-4000-8000-000000000001', 'Qalam 302'),
  ('a9000000-0000-4000-8000-000000000063', 'a9000000-0000-4000-8000-000000000001', 'Jugnu 303');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000061', 'a9000000-0000-4000-8000-000000000031', 'a9000000-0000-4000-8000-000000000021'),
  ('a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000062', 'a9000000-0000-4000-8000-000000000032', 'a9000000-0000-4000-8000-000000000021'),
  ('a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000063', 'a9000000-0000-4000-8000-000000000033', 'a9000000-0000-4000-8000-000000000022');
insert into app.threads (id, institute_id, class_id, scope, title, language, author_persona_id, author_user_id) values
  ('a9000000-0000-4000-8000-000000000071', 'a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000051',
    'class', 'Garden', 'en', 'a9000000-0000-4000-8000-000000000061', null),
  ('a9000000-0000-4000-8000-000000000072', 'a9000000-0000-4000-8000-000000000001', null,
    'madrasa', 'Notice', 'en', null, 'a9000000-0000-4000-8000-000000000021');
-- An older post of student one, and an older draft.
insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_persona_id, moderation_state) values
  ('a9000000-0000-4000-8000-000000000081', 'a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000071',
    'message', 'en', 'Yesterday', 'a9000000-0000-4000-8000-000000000061', 'published'),
  ('a9000000-0000-4000-8000-000000000082', 'a9000000-0000-4000-8000-000000000001', 'a9000000-0000-4000-8000-000000000071',
    'message', 'en', 'Draft', 'a9000000-0000-4000-8000-000000000061', 'draft');
alter table app.posts disable trigger posts_moderation;
update app.posts set created_at = now() - interval '1 day'
where id in ('a9000000-0000-4000-8000-000000000081', 'a9000000-0000-4000-8000-000000000082');
alter table app.posts enable trigger posts_moderation;
-- Uploads: photos of students one and two, a YouTube link of student one, a
-- deleted and an avatar upload of student one, and a teacher's photo.
insert into app.media_assets
  (id, institute_id, kind, purpose, visibility, storage_key, youtube_id, mime_type, bytes, status, deleted_at, uploaded_by)
select id::uuid, 'a9000000-0000-4000-8000-000000000001', kind, purpose, visibility,
  case when kind <> 'youtube' then 'a9000000-0000-4000-8000-000000000001/' || id end,
  case when kind = 'youtube' then 'dQw4w9WgXcQ' end,
  case when kind <> 'youtube' then 'image/webp' end, case when kind <> 'youtube' then 1000 end,
  status, case when status = 'deleted' then now() end, uploader::uuid
from (values
  ('a9000000-0000-4000-8000-000000000091', 'image', 'post', 'private', 'ready', 'a9000000-0000-4000-8000-000000000031'),
  ('a9000000-0000-4000-8000-000000000092', 'image', 'post', 'private', 'ready', 'a9000000-0000-4000-8000-000000000032'),
  ('a9000000-0000-4000-8000-000000000093', 'youtube', 'post', 'private', 'ready', 'a9000000-0000-4000-8000-000000000031'),
  ('a9000000-0000-4000-8000-000000000094', 'image', 'post', 'private', 'deleted', 'a9000000-0000-4000-8000-000000000031'),
  ('a9000000-0000-4000-8000-000000000095', 'image', 'avatar', 'private', 'ready', 'a9000000-0000-4000-8000-000000000031'),
  ('a9000000-0000-4000-8000-000000000096', 'image', 'post', 'public', 'ready', 'a9000000-0000-4000-8000-000000000021'),
  ('a9000000-0000-4000-8000-000000000097', 'image', 'post', 'public', 'ready', 'a9000000-0000-4000-8000-000000000031')
) m(id, kind, purpose, visibility, status, uploader);

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a9000000-0000-4000-8000-000000000001';
  admin constant uuid := 'a9000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'a9000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'a9000000-0000-4000-8000-000000000022';
  s1 constant uuid := 'a9000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'a9000000-0000-4000-8000-000000000032';
  s3 constant uuid := 'a9000000-0000-4000-8000-000000000033';
  p1 constant uuid := 'a9000000-0000-4000-8000-000000000061';
  thread_a constant uuid := 'a9000000-0000-4000-8000-000000000071';
  thread_m constant uuid := 'a9000000-0000-4000-8000-000000000072';
  older constant uuid := 'a9000000-0000-4000-8000-000000000081';
  draft constant uuid := 'a9000000-0000-4000-8000-000000000082';
  photo1 constant uuid := 'a9000000-0000-4000-8000-000000000091';
  photo2 constant uuid := 'a9000000-0000-4000-8000-000000000092';
  video1 constant uuid := 'a9000000-0000-4000-8000-000000000093';
  gone1 constant uuid := 'a9000000-0000-4000-8000-000000000094';
  avatar1 constant uuid := 'a9000000-0000-4000-8000-000000000095';
  staff_photo constant uuid := 'a9000000-0000-4000-8000-000000000096';
  public1 constant uuid := 'a9000000-0000-4000-8000-000000000097';
  question uuid;
  vlog uuid;
  poll uuid;
  notice uuid;
  changed bigint;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- A student posts a question with their photo, and a vlog with a YouTube link (REQ-PRF-004).
  perform set_config('app.user_id', s1::text, true);
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
  values (tenant, thread_a, 'question', 'en', 'What is this leaf?', p1) returning id into question;
  insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, question, photo1, 1);
  insert into app.posts (institute_id, thread_id, post_type, language, title, body, author_persona_id)
  values (tenant, thread_a, 'vlog', 'en', 'My garden', 'A walk', p1) returning id into vlog;
  insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, vlog, video1, 1);
  -- Two items cannot share a position.
  begin
    insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, question, video1, 1);
    assert false, 'two items took one position';
  exception when unique_violation then null;
  end;
  -- Only the author's own uploads, only post uploads, never deleted ones, never on a poll.
  begin
    insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, question, photo2, 2);
    assert false, 'a student attached a classmate''s upload';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, question, avatar1, 2);
    assert false, 'an avatar upload was attached to a post';
  exception when check_violation then null;
  end;
  begin
    insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, question, gone1, 2);
    assert false, 'a deleted upload was attached';
  exception when check_violation then null;
  end;
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id, poll_results)
  values (tenant, thread_a, 'poll', 'en', 'Poll', p1, 'after_voting') returning id into poll;
  begin
    insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, poll, photo1, 1);
    assert false, 'media was attached to a poll';
  exception when check_violation then null;
  end;
  -- Adding media to a post already out is an edit (P3-E3-T11); a draft takes it.
  begin
    insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, older, photo1, 1);
    assert false, 'media was added to a published post later';
  exception when insufficient_privilege then null;
  end;
  insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, draft, photo1, 1);

  -- Another student cannot attach to the post.
  perform set_config('app.user_id', s2::text, true);
  begin
    insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, question, photo2, 2);
    assert false, 'a classmate attached media to another''s post';
  exception when insufficient_privilege then null;
  end;
  -- A classmate sees what is attached, but not the upload itself (P3-E4-T03, T72).
  assert (select count(*) from app.post_media where post_id in (question, vlog)) = 2, 'a classmate cannot see post media';
  assert not exists (select from app.post_media where post_id = draft), 'a classmate saw a draft''s media';
  assert not exists (select from app.media_assets where id = photo1), 'a classmate read another student''s upload';
  -- Another class and visitors see nothing.
  perform set_config('app.user_id', s3::text, true);
  assert not exists (select from app.post_media where post_id = question), 'another class saw the media';
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.post_media), 'a visitor saw post media';

  -- Removing media is moderation: the class teacher and admins, not the
  -- author or another class's teacher (D-135).
  perform set_config('app.user_id', s1::text, true);
  delete from app.post_media where post_id = vlog;
  get diagnostics changed = row_count;
  assert changed = 0, 'the author removed media';
  perform set_config('app.user_id', t2::text, true);
  delete from app.post_media where post_id = vlog;
  get diagnostics changed = row_count;
  assert changed = 0, 'another class''s teacher removed media';
  perform set_config('app.user_id', t1::text, true);
  delete from app.post_media where post_id = vlog;
  get diagnostics changed = row_count;
  assert changed = 1, 'the class teacher could not remove media';

  -- A teacher's madrasa notice with their public photo: every member sees
  -- it, and any teacher may remove it.
  insert into app.posts (institute_id, thread_id, post_type, language, body, author_user_id)
  values (tenant, thread_m, 'message', 'en', 'Sports day photo', t1) returning id into notice;
  insert into app.post_media (institute_id, post_id, media_asset_id, position) values (tenant, notice, staff_photo, 1);
  perform set_config('app.user_id', s3::text, true);
  assert exists (select from app.post_media where post_id = notice), 'a member cannot see madrasa post media';
  perform set_config('app.user_id', t2::text, true);
  delete from app.post_media where post_id = notice;
  get diagnostics changed = row_count;
  assert changed = 1, 'a teacher could not remove madrasa post media';
  perform set_config('app.user_id', admin::text, true);
  delete from app.post_media where post_id = draft;
  get diagnostics changed = row_count;
  assert changed = 1, 'an admin could not remove media';

  -- The face flag: the uploader raises it; a student never clears it; the
  -- uploader's teacher and admins do. Raising it on public media makes the
  -- media private, since student one has no face consent.
  perform set_config('app.user_id', s2::text, true);
  assert not app.set_media_shows_face(public1, true), 'a classmate set another student''s face flag';
  perform set_config('app.user_id', s1::text, true);
  assert app.set_media_shows_face(public1, true), 'the uploader could not raise the face flag';
  assert (select shows_face and visibility = 'private' from app.media_assets where id = public1),
    'public media showing a face without consent stayed public';
  assert not app.set_media_shows_face(public1, false), 'a student cleared the face flag';
  perform set_config('app.user_id', t2::text, true);
  assert not app.set_media_shows_face(public1, false), 'another class''s teacher cleared the face flag';
  perform set_config('app.user_id', t1::text, true);
  assert app.set_media_shows_face(public1, false), 'the student''s teacher could not clear the face flag';
  assert app.set_media_shows_face(public1, true), 'the student''s teacher could not raise the face flag';
  assert app.set_media_shows_face(staff_photo, true), 'the uploader could not flag their own photo';
end
$test$;

-- Media showing a student's face is public only with face consent
-- (REQ-CHS-001), for the owner too.
reset role;
set local role tazkiyah_schema_owner;
select set_config('app.institute_id', 'a9000000-0000-4000-8000-000000000001', true);
do $test$
declare
  tenant constant uuid := 'a9000000-0000-4000-8000-000000000001';
begin
  begin
    update app.media_assets set visibility = 'public' where id = 'a9000000-0000-4000-8000-000000000097';
    assert false, 'a student''s face photo was made public without consent';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into app.media_assets (institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, status,
      shows_face, uploaded_by)
    values (tenant, 'image', 'post', 'public', tenant || '/face-new', 'image/webp', 1000, 'ready', true,
      'a9000000-0000-4000-8000-000000000031');
    assert false, 'a public face photo of a student was uploaded without consent';
  exception when insufficient_privilege then null;
  end;
  -- A teacher's public face photo is not about a student until it is
  -- attached to a student's post; then the student's consent counts.
  assert (select shows_face and visibility = 'public' from app.media_assets
    where id = 'a9000000-0000-4000-8000-000000000096'), 'the staff photo fixture changed';
  begin
    insert into app.post_media (institute_id, post_id, media_asset_id, position)
    values (tenant, 'a9000000-0000-4000-8000-000000000081', 'a9000000-0000-4000-8000-000000000096', 1);
    assert false, 'public face media was attached to a student''s post without consent';
  exception when insufficient_privilege then null;
  end;
  update app.media_assets set visibility = 'private' where id = 'a9000000-0000-4000-8000-000000000096';
  insert into app.post_media (institute_id, post_id, media_asset_id, position)
  values (tenant, 'a9000000-0000-4000-8000-000000000081', 'a9000000-0000-4000-8000-000000000096', 1);
  begin
    update app.media_assets set visibility = 'public' where id = 'a9000000-0000-4000-8000-000000000096';
    assert false, 'face media in a student''s post was made public without consent';
  exception when insufficient_privilege then null;
  end;

  -- With face consent on record, the student's media may be public.
  insert into app.consent_records (institute_id, student_user_id, kind, guardian_name, guardian_relation,
    method, given_on, recorded_by)
  values (tenant, 'a9000000-0000-4000-8000-000000000031', 'face', 'Guardian', 'mother', 'in_person', current_date,
    'a9000000-0000-4000-8000-000000000021');
  update app.media_assets set visibility = 'public'
  where id in ('a9000000-0000-4000-8000-000000000096', 'a9000000-0000-4000-8000-000000000097');
  assert (select count(*) from app.media_assets where visibility = 'public' and shows_face
    and id in ('a9000000-0000-4000-8000-000000000096', 'a9000000-0000-4000-8000-000000000097')) = 2,
    'consented face media could not be made public';
end
$test$;

rollback;
