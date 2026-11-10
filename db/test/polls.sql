-- Polls: options, votes, closing and counts (04 §11.5, 07 §6.4, REQ-STU-007,
-- P3-E3-T41).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a8000000-0000-4000-8000-000000000001', 'poll-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
values ('a8000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'POL',
  array['student_hub', 'teacher_hub']);
insert into app.users (id, institute_id, email, username, full_name, status) values
  ('a8000000-0000-4000-8000-000000000011', 'a8000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin', 'active'),
  ('a8000000-0000-4000-8000-000000000021', 'a8000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active'),
  ('a8000000-0000-4000-8000-000000000022', 'a8000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active'),
  ('a8000000-0000-4000-8000-000000000041', 'a8000000-0000-4000-8000-000000000001', 'editor@example.test', null, 'Editor', 'active'),
  ('a8000000-0000-4000-8000-000000000031', 'a8000000-0000-4000-8000-000000000001', null, 'poll-1', 'Student One', 'active'),
  ('a8000000-0000-4000-8000-000000000032', 'a8000000-0000-4000-8000-000000000001', null, 'poll-2', 'Student Two', 'active'),
  ('a8000000-0000-4000-8000-000000000033', 'a8000000-0000-4000-8000-000000000001', null, 'poll-3', 'Student Three', 'active');
insert into app.user_roles (institute_id, user_id, role)
select 'a8000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('a8000000-0000-4000-8000-000000000011', 'admin'), ('a8000000-0000-4000-8000-000000000021', 'teacher'),
  ('a8000000-0000-4000-8000-000000000022', 'teacher'), ('a8000000-0000-4000-8000-000000000041', 'editor'),
  ('a8000000-0000-4000-8000-000000000031', 'student'), ('a8000000-0000-4000-8000-000000000032', 'student'),
  ('a8000000-0000-4000-8000-000000000033', 'student')) r(id, role);
-- Class A (teacher one, students one and two) and class B (teacher two,
-- student three).
insert into app.classes (id, institute_id, name, created_by) values
  ('a8000000-0000-4000-8000-000000000051', 'a8000000-0000-4000-8000-000000000001', '{"en":"A"}', 'a8000000-0000-4000-8000-000000000021'),
  ('a8000000-0000-4000-8000-000000000052', 'a8000000-0000-4000-8000-000000000001', '{"en":"B"}', 'a8000000-0000-4000-8000-000000000022');
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000051', 'a8000000-0000-4000-8000-000000000031', 'student'),
  ('a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000051', 'a8000000-0000-4000-8000-000000000032', 'student'),
  ('a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000052', 'a8000000-0000-4000-8000-000000000033', 'student');
insert into app.personas (id, institute_id, display_name) values
  ('a8000000-0000-4000-8000-000000000061', 'a8000000-0000-4000-8000-000000000001', 'Sitara 201'),
  ('a8000000-0000-4000-8000-000000000062', 'a8000000-0000-4000-8000-000000000001', 'Qalam 202'),
  ('a8000000-0000-4000-8000-000000000063', 'a8000000-0000-4000-8000-000000000001', 'Jugnu 203');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000061', 'a8000000-0000-4000-8000-000000000031', 'a8000000-0000-4000-8000-000000000021'),
  ('a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000062', 'a8000000-0000-4000-8000-000000000032', 'a8000000-0000-4000-8000-000000000021'),
  ('a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000063', 'a8000000-0000-4000-8000-000000000033', 'a8000000-0000-4000-8000-000000000022');
-- A class thread of student one and a madrasa thread of teacher one.
insert into app.threads (id, institute_id, class_id, scope, title, language, author_persona_id, author_user_id) values
  ('a8000000-0000-4000-8000-000000000071', 'a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000051',
    'class', 'Trip', 'en', 'a8000000-0000-4000-8000-000000000061', null),
  ('a8000000-0000-4000-8000-000000000072', 'a8000000-0000-4000-8000-000000000001', null,
    'madrasa', 'Sports day', 'en', null, 'a8000000-0000-4000-8000-000000000021');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a8000000-0000-4000-8000-000000000001';
  admin constant uuid := 'a8000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'a8000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'a8000000-0000-4000-8000-000000000022';
  editor constant uuid := 'a8000000-0000-4000-8000-000000000041';
  s1 constant uuid := 'a8000000-0000-4000-8000-000000000031';
  s2 constant uuid := 'a8000000-0000-4000-8000-000000000032';
  s3 constant uuid := 'a8000000-0000-4000-8000-000000000033';
  p1 constant uuid := 'a8000000-0000-4000-8000-000000000061';
  thread_a constant uuid := 'a8000000-0000-4000-8000-000000000071';
  thread_m constant uuid := 'a8000000-0000-4000-8000-000000000072';
  poll constant uuid := 'a8000000-0000-4000-8000-000000000081';
  multi constant uuid := 'a8000000-0000-4000-8000-000000000082';
  later constant uuid := 'a8000000-0000-4000-8000-000000000083';
  bad uuid;
  opt uuid[];
  multi_opt uuid[];
  later_opt uuid[];
  changed bigint;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- A student posts a single-choice poll with three options (REQ-STU-007).
  perform set_config('app.user_id', s1::text, true);
  insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_persona_id, poll_results)
  values (poll, tenant, thread_a, 'poll', 'en', 'Where should we go?', p1, 'after_voting');
  with added as (
    insert into app.poll_options (institute_id, post_id, label, position)
    select tenant, poll, label, position from unnest(array['Museum', 'Park', 'Library']) with ordinality as o(label, position)
    returning id, position)
  select array_agg(id order by position) into opt from added;
  set constraints all immediate;
  set constraints all deferred;
  assert (select poll_closes_at between now() + interval '7 days' - interval '1 minute' and now() + interval '7 days'
    from app.posts where id = poll), 'a poll does not close after 7 days by default';

  -- The closing date is 1 hour to 30 days away.
  foreach changed in array array[0, 31 * 24] loop
    begin
      insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id, poll_results,
        poll_closes_at)
      values (tenant, thread_a, 'poll', 'en', 'Too soon or too late', p1, 'after_voting',
        now() + interval '30 minutes' + changed * interval '1 hour');
      assert false, 'a poll closing ' || changed || ' hours out was saved';
    exception when check_violation then null;
    end;
  end loop;
  -- Choice and results settings belong to polls, and a poll needs them.
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id, poll_results)
    values (tenant, thread_a, 'message', 'en', 'Not a poll', p1, 'after_voting');
    assert false, 'a message took a poll setting';
  exception when check_violation then null;
  end;
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_a, 'poll', 'en', 'No results setting', p1);
    assert false, 'a poll without a results setting was saved';
  exception when check_violation then null;
  end;
  begin
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id, poll_results,
      poll_multiple)
    values (tenant, thread_a, 'poll', 'en', 'No maximum', p1, 'after_voting', true);
    assert false, 'a multiple-choice poll without a maximum was saved';
  exception when check_violation then null;
  end;

  -- At commit a poll has 2 to 6 options and no more choices than options.
  begin
    insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_persona_id, poll_results)
    values (gen_random_uuid(), tenant, thread_a, 'poll', 'en', 'One option', p1, 'after_voting')
    returning id into bad;
    insert into app.poll_options (institute_id, post_id, label, position) values (tenant, bad, 'Only', 1);
    set constraints all immediate;
    assert false, 'a poll with one option was saved';
  exception when check_violation then null;
  end;
  set constraints all deferred;
  begin
    insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_persona_id, poll_results,
      poll_multiple, poll_max_choices)
    values (gen_random_uuid(), tenant, thread_a, 'poll', 'en', 'Too many choices', p1, 'after_voting', true, 3)
    returning id into bad;
    insert into app.poll_options (institute_id, post_id, label, position)
    values (tenant, bad, 'One', 1), (tenant, bad, 'Two', 2);
    set constraints all immediate;
    assert false, 'a poll allowing more choices than options was saved';
  exception when check_violation then null;
  end;
  set constraints all deferred;
  begin
    insert into app.poll_options (institute_id, post_id, label, position) values (tenant, poll, 'Seventh', 7);
    assert false, 'a seventh option was saved';
  exception when check_violation then null;
  end;
  begin
    insert into app.poll_options (institute_id, post_id, label, position)
    values (tenant, poll, repeat('x', 81), 4);
    assert false, 'an 81-character option was saved';
  exception when check_violation then null;
  end;

  -- Only the poll's author adds options, and only to a poll.
  perform set_config('app.user_id', s2::text, true);
  begin
    insert into app.poll_options (institute_id, post_id, label, position) values (tenant, poll, 'Zoo', 4);
    assert false, 'a classmate added an option';
  exception when insufficient_privilege then null;
  end;

  -- A classmate votes and sees the counts, as the creator chose.
  insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, poll, opt[1], s2);
  assert (select votes from public_api.poll_counts where option_id = opt[1]) = 1
    and (select count(*) from public_api.poll_counts where post_id = poll) = 3
    and (select voters from public_api.poll_counts where option_id = opt[2]) = 1,
    'a voter does not see the counts after voting';
  -- One vote on a single-choice poll; changing it is taking it back and voting again.
  begin
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, poll, opt[2], s2);
    assert false, 'a second vote on a single-choice poll was saved';
  exception when unique_violation then null;
  end;
  begin
    update app.poll_votes set option_id = opt[2] where post_id = poll;
    assert false, 'a vote was updated in place';
  exception when insufficient_privilege then null;
  end;
  delete from app.poll_votes where post_id = poll and voter_user_id = s2;
  insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, poll, opt[2], s2);
  -- Nobody votes for someone else.
  begin
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, poll, opt[1], s1);
    assert false, 'a student voted for a classmate';
  exception when insufficient_privilege then null;
  end;

  -- The author has not voted, so sees no counts yet; options are now fixed.
  perform set_config('app.user_id', s1::text, true);
  assert not exists (select from public_api.poll_counts where post_id = poll), 'a non-voter saw the counts';
  assert exists (select from app.poll_options where post_id = poll), 'the author cannot read the options';
  begin
    insert into app.poll_options (institute_id, post_id, label, position) values (tenant, poll, 'Zoo', 4);
    assert false, 'an option was added after the first vote';
  exception when object_not_in_prerequisite_state then null;
  end;
  insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, poll, opt[2], s1);
  -- Who voted is hidden from students: each reads only their own vote.
  assert (select count(*) from app.poll_votes where post_id = poll) = 1
    and (select voter_user_id from app.poll_votes where post_id = poll) = s1,
    'a student read another student''s vote';
  assert (select votes from public_api.poll_counts where option_id = opt[2]) = 2, 'the counts are wrong';

  -- A student of another class cannot see, vote in or count the poll.
  perform set_config('app.user_id', s3::text, true);
  assert not exists (select from app.poll_options where post_id = poll), 'another class read the options';
  assert not exists (select from public_api.poll_counts where post_id = poll), 'another class read the counts';
  begin
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, poll, opt[1], s3);
    assert false, 'a student of another class voted';
  exception when insufficient_privilege then null;
  end;

  -- The class teacher and admins see who voted; another class's teacher does not.
  perform set_config('app.user_id', t1::text, true);
  assert (select count(*) from app.poll_votes where post_id = poll) = 2, 'the class teacher cannot see who voted';
  perform set_config('app.user_id', admin::text, true);
  assert (select count(*) from app.poll_votes where post_id = poll) = 2, 'an admin cannot see who voted';
  perform set_config('app.user_id', t2::text, true);
  assert not exists (select from app.poll_votes where post_id = poll), 'another teacher saw who voted';

  -- A teacher's multiple-choice madrasa poll, results after closing.
  perform set_config('app.user_id', t1::text, true);
  insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_user_id, poll_results,
    poll_multiple, poll_max_choices)
  values (multi, tenant, thread_m, 'poll', 'en', 'Which games?', t1, 'after_closing', true, 2);
  with added as (
    insert into app.poll_options (institute_id, post_id, label, position)
    select tenant, multi, label, position from unnest(array['Cricket', 'Football', 'Kabaddi']) with ordinality as o(label, position)
    returning id, position)
  select array_agg(id order by position) into multi_opt from added;
  set constraints all immediate;
  set constraints all deferred;
  -- Any student may vote in a madrasa poll, up to the maximum, once per option.
  perform set_config('app.user_id', s3::text, true);
  insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id)
  values (tenant, multi, multi_opt[1], s3), (tenant, multi, multi_opt[3], s3);
  begin
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, multi, multi_opt[2], s3);
    assert false, 'a third choice was saved on a two-choice poll';
  exception when unique_violation then null;
  end;
  delete from app.poll_votes where post_id = multi and option_id = multi_opt[3];
  begin
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, multi, multi_opt[1], s3);
    assert false, 'the same option was chosen twice';
  exception when unique_violation then null;
  end;
  assert not exists (select from public_api.poll_counts where post_id = multi), 'counts showed before closing';
  -- Editors do not vote (07 §4.6), although they can see the poll.
  perform set_config('app.user_id', editor::text, true);
  assert exists (select from app.poll_options where post_id = multi), 'the editor cannot see the madrasa poll';
  begin
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, multi, multi_opt[1], editor);
    assert false, 'an editor voted';
  exception when insufficient_privilege then null;
  end;

  -- A student cannot close a poll early; another class's teacher cannot close
  -- a class poll; any teacher can close a madrasa poll.
  perform set_config('app.user_id', s1::text, true);
  assert not app.close_poll(multi) and not app.close_poll(poll), 'a student closed a poll';
  perform set_config('app.user_id', t2::text, true);
  assert not app.close_poll(poll), 'another class''s teacher closed a class poll';
  assert app.close_poll(multi), 'a teacher could not close a madrasa poll';
  assert not app.close_poll(multi), 'a closed poll closed again';
  -- Once closed, everyone who can see it sees the final counts, and nothing changes.
  perform set_config('app.user_id', s3::text, true);
  assert (select votes from public_api.poll_counts where option_id = multi_opt[1]) = 1
    and (select bool_and(is_closed) from public_api.poll_counts where post_id = multi),
    'the final counts are not shown after closing';
  begin
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, multi, multi_opt[2], s3);
    assert false, 'a vote was cast after closing';
  exception when object_not_in_prerequisite_state then null;
  end;
  delete from app.poll_votes where post_id = multi;
  get diagnostics changed = row_count;
  assert changed = 0, 'a vote was taken back after closing';
  perform set_config('app.user_id', t1::text, true);
  begin
    insert into app.poll_options (institute_id, post_id, label, position) values (tenant, multi, 'Hockey', 4);
    assert false, 'an option was added to a closed poll';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- A draft poll takes no votes.
  perform set_config('app.user_id', s1::text, true);
  insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_persona_id, poll_results,
    moderation_state)
  values (later, tenant, thread_a, 'poll', 'en', 'Not ready', p1, 'after_voting', 'draft');
  with added as (
    insert into app.poll_options (institute_id, post_id, label, position)
    values (tenant, later, 'Yes', 1), (tenant, later, 'No', 2) returning id, position)
  select array_agg(id order by position) into later_opt from added;
  begin
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id) values (tenant, later, later_opt[1], s1);
    assert false, 'a vote was cast in a draft poll';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- Visitors see no member polls.
  perform set_config('app.user_id', '', true);
  assert not exists (select from public_api.poll_counts), 'a visitor saw member poll counts';
end
$test$;

-- Visitors see final counts of a closed public poll, and nothing while the
-- module is off. Public posts are made by later tasks, so the owner sets one up.
reset role;
set local role tazkiyah_schema_owner;
insert into app.threads (id, institute_id, scope, title, language, author_persona_id)
values ('a8000000-0000-4000-8000-000000000073', 'a8000000-0000-4000-8000-000000000001', 'public', 'Public',
  'en', 'a8000000-0000-4000-8000-000000000061');
insert into app.posts (id, institute_id, thread_id, post_type, language, body, author_persona_id, poll_results)
values ('a8000000-0000-4000-8000-000000000084', 'a8000000-0000-4000-8000-000000000001',
  'a8000000-0000-4000-8000-000000000073', 'poll', 'en', 'Public poll', 'a8000000-0000-4000-8000-000000000061',
  'after_voting');
insert into app.poll_options (institute_id, post_id, label, position) values
  ('a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000084', 'Yes', 1),
  ('a8000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000084', 'No', 2);
set local role tazkiyah_app;
do $test$
begin
  perform set_config('app.institute_id', 'a8000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '', true);
  assert not exists (select from public_api.poll_counts), 'a visitor saw an open public poll';
end
$test$;
reset role;
update app.posts set poll_closes_at = now() - interval '1 minute' where id = 'a8000000-0000-4000-8000-000000000084';
set local role tazkiyah_app;
do $test$
begin
  perform set_config('app.institute_id', 'a8000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '', true);
  assert (select count(*) from public_api.poll_counts where post_id = 'a8000000-0000-4000-8000-000000000084') = 2,
    'a visitor does not see a closed public poll';
  assert (select count(*) from public_api.poll_counts) = 2, 'a visitor saw a member poll';
end
$test$;
reset role;
update app.institute_settings set enabled_modules = array['teacher_hub']
where institute_id = 'a8000000-0000-4000-8000-000000000001';
set local role tazkiyah_app;
do $test$
begin
  perform set_config('app.institute_id', 'a8000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '', true);
  assert not exists (select from public_api.poll_counts), 'a public student poll showed with the student hub off';
end
$test$;

-- An archived class is read-only: its polls take no votes.
reset role;
update app.institute_settings set enabled_modules = array['student_hub', 'teacher_hub']
where institute_id = 'a8000000-0000-4000-8000-000000000001';
update app.classes set archived_at = now() where id = 'a8000000-0000-4000-8000-000000000051';
set local role tazkiyah_app;
do $test$
begin
  perform set_config('app.institute_id', 'a8000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', 'a8000000-0000-4000-8000-000000000021', true);
  insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id)
  select institute_id, post_id, id, 'a8000000-0000-4000-8000-000000000021' from app.poll_options
  where post_id = 'a8000000-0000-4000-8000-000000000081' and position = 1;
  assert false, 'a vote was cast in an archived class';
exception when object_not_in_prerequisite_state then null;
end
$test$;

rollback;
