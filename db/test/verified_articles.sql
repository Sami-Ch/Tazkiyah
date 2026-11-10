-- Verified articles made from threads (04 §11.1, §11.2, 07 §9, REQ-TCH-002,
-- REQ-TCH-003, P3-E6-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('ac000000-0000-4000-8000-000000000001', 'article-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
values ('ac000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'ART',
  array['student_hub', 'teacher_hub']);
insert into app.users (id, institute_id, email, username, full_name, status) values
  ('ac000000-0000-4000-8000-000000000011', 'ac000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin', 'active'),
  ('ac000000-0000-4000-8000-000000000021', 'ac000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active'),
  ('ac000000-0000-4000-8000-000000000022', 'ac000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active'),
  ('ac000000-0000-4000-8000-000000000041', 'ac000000-0000-4000-8000-000000000001', 'editor@example.test', null, 'Editor', 'active'),
  ('ac000000-0000-4000-8000-000000000031', 'ac000000-0000-4000-8000-000000000001', null, 'art-1', 'Student One', 'active');
insert into app.user_roles (institute_id, user_id, role)
select 'ac000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('ac000000-0000-4000-8000-000000000011', 'admin'), ('ac000000-0000-4000-8000-000000000021', 'teacher'),
  ('ac000000-0000-4000-8000-000000000022', 'teacher'), ('ac000000-0000-4000-8000-000000000041', 'editor'),
  ('ac000000-0000-4000-8000-000000000031', 'student')) r(id, role);
insert into app.classes (id, institute_id, name, created_by, archived_at) values
  ('ac000000-0000-4000-8000-000000000051', 'ac000000-0000-4000-8000-000000000001', '{"en":"A"}', 'ac000000-0000-4000-8000-000000000021', null),
  ('ac000000-0000-4000-8000-000000000052', 'ac000000-0000-4000-8000-000000000001', '{"en":"B"}', 'ac000000-0000-4000-8000-000000000022', null),
  ('ac000000-0000-4000-8000-000000000053', 'ac000000-0000-4000-8000-000000000001', '{"en":"Old"}', 'ac000000-0000-4000-8000-000000000021', null);
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('ac000000-0000-4000-8000-000000000001', 'ac000000-0000-4000-8000-000000000051', 'ac000000-0000-4000-8000-000000000031', 'student');
insert into app.personas (id, institute_id, display_name) values
  ('ac000000-0000-4000-8000-000000000061', 'ac000000-0000-4000-8000-000000000001', 'Sitara 601');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('ac000000-0000-4000-8000-000000000001', 'ac000000-0000-4000-8000-000000000061', 'ac000000-0000-4000-8000-000000000031', 'ac000000-0000-4000-8000-000000000021');
insert into app.threads (id, institute_id, class_id, scope, title, language, author_persona_id, author_user_id) values
  ('ac000000-0000-4000-8000-000000000071', 'ac000000-0000-4000-8000-000000000001', 'ac000000-0000-4000-8000-000000000051',
    'class', 'Rules of noon sakin', 'en', 'ac000000-0000-4000-8000-000000000061', null),
  ('ac000000-0000-4000-8000-000000000072', 'ac000000-0000-4000-8000-000000000001', null,
    'madrasa', 'Fasting questions', 'en', null, 'ac000000-0000-4000-8000-000000000022'),
  ('ac000000-0000-4000-8000-000000000073', 'ac000000-0000-4000-8000-000000000001', 'ac000000-0000-4000-8000-000000000052',
    'class', 'Class B thread', 'en', null, 'ac000000-0000-4000-8000-000000000022'),
  ('ac000000-0000-4000-8000-000000000074', 'ac000000-0000-4000-8000-000000000001', 'ac000000-0000-4000-8000-000000000053',
    'class', 'Old thread', 'en', null, 'ac000000-0000-4000-8000-000000000021');
update app.classes set archived_at = now() where id = 'ac000000-0000-4000-8000-000000000053';

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'ac000000-0000-4000-8000-000000000001';
  admin constant uuid := 'ac000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'ac000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'ac000000-0000-4000-8000-000000000022';
  editor constant uuid := 'ac000000-0000-4000-8000-000000000041';
  s1 constant uuid := 'ac000000-0000-4000-8000-000000000031';
  thread_a constant uuid := 'ac000000-0000-4000-8000-000000000071';
  thread_m constant uuid := 'ac000000-0000-4000-8000-000000000072';
  thread_b constant uuid := 'ac000000-0000-4000-8000-000000000073';
  thread_old constant uuid := 'ac000000-0000-4000-8000-000000000074';
  article uuid;
  other uuid;
  p app.posts;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- Only the class's teachers or an admin turn a class thread into an article.
  foreach other in array array[t2, editor, s1] loop
    perform set_config('app.user_id', other::text, true);
    assert app.make_verified_article(thread_a, 'Noon sakin', 'Four rules', 'en') is null,
      'the wrong person made a verified article';
  end loop;
  perform set_config('app.user_id', '', true);
  assert app.make_verified_article(thread_a, 'Noon sakin', 'Four rules', 'en') is null, 'a visitor made an article';

  -- The class teacher makes it: an article by the teacher, live in the class
  -- at once, with the verified mark, linked from the thread (REQ-TCH-002, REQ-TCH-003).
  perform set_config('app.user_id', t1::text, true);
  article := app.make_verified_article(thread_a, 'Noon sakin', 'Izhar, idgham, iqlab and ikhfa', 'en');
  select * into p from app.posts where id = article;
  assert p.post_type = 'article' and p.author_user_id = t1 and p.is_verified and p.verified_by = t1
    and p.verified_at = now() and p.scope = 'class' and p.moderation_state = 'published',
    'the verified article is wrong: ' || row_to_json(p)::text;
  assert (select article_post_id from app.threads where id = thread_a) = article, 'the thread does not link its article';
  assert app.make_verified_article(thread_a, 'Again', 'Again', 'en') is null, 'a thread got a second article';
  perform set_config('app.user_id', s1::text, true);
  assert exists (select from app.posts where id = article and is_verified), 'the class cannot see the article';

  -- An article needs a title, and an archived class takes none.
  perform set_config('app.user_id', t2::text, true);
  begin
    perform app.make_verified_article(thread_b, null, 'No title', 'en');
    assert false, 'an article without a title was saved';
  exception when check_violation then null;
  end;
  perform set_config('app.user_id', t1::text, true);
  begin
    perform app.make_verified_article(thread_old, 'Old', 'Old', 'en');
    assert false, 'an article was made in an archived class';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- Any teacher makes one from a madrasa thread; admins from any thread.
  perform set_config('app.user_id', t1::text, true);
  assert app.make_verified_article(thread_m, 'Fasting', 'Who must fast', 'en') is not null,
    'a teacher could not make an article from a madrasa thread';
  perform set_config('app.user_id', admin::text, true);
  assert app.make_verified_article(thread_b, 'Class B', 'Summary', 'ur') is not null,
    'an admin could not make an article';

  -- Nobody marks a post or links a thread directly.
  perform set_config('app.user_id', t1::text, true);
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, title, body, author_user_id,
      is_verified, verified_by, verified_at)
    values (tenant, thread_a, 'article', 'en', 'Fake', 'Fake', t1, true, t1, now());
    assert false, 'a post was marked verified directly';
  exception when insufficient_privilege then null;
  end;
  begin
    update app.posts set is_verified = false where id = article;
    assert false, 'the verified mark was changed directly';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into app.threads (institute_id, class_id, scope, title, language, author_user_id, article_post_id)
    values (tenant, 'ac000000-0000-4000-8000-000000000051', 'class', 'Fake', 'en', t1, article);
    assert false, 'a thread was linked to an article directly';
  exception when insufficient_privilege then null;
  end;

  -- The article goes public as teacher work, through an editor (REQ-TCH-004).
  update app.posts set moderation_state = 'submitted', target_scope = 'public' where id = article;
  perform set_config('app.user_id', editor::text, true);
  update app.posts set moderation_state = 'approved' where id = article;
  assert (select scope = 'public' and is_verified from app.posts where id = article),
    'the verified article did not go public through the editor';
end
$test$;

-- With the teacher hub off, madrasa threads give no articles.
reset role;
update app.institute_settings set enabled_modules = array['student_hub']
where institute_id = 'ac000000-0000-4000-8000-000000000001';
update app.threads set article_post_id = null where id = 'ac000000-0000-4000-8000-000000000072';
set local role tazkiyah_app;
do $test$
begin
  perform set_config('app.institute_id', 'ac000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', 'ac000000-0000-4000-8000-000000000022', true);
  assert app.make_verified_article('ac000000-0000-4000-8000-000000000072', 'Off', 'Off', 'en') is null,
    'an article was made with the teacher hub off';
end
$test$;

rollback;
