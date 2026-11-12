-- Orphan sponsorship: matching, the sponsor's default view, progress updates
-- and sponsorship gifts (04 §10.3, 06 §12, REQ-ORP-001, REQ-ORP-002,
-- REQ-ORP-008, REQ-ORP-009, P4-E1-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('ad000000-0000-4000-8000-000000000001', 'sponsor-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
values ('ad000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SPN',
  array['student_hub']);
insert into app.users (id, institute_id, email, username, full_name, status, is_orphan, date_of_birth) values
  ('ad000000-0000-4000-8000-000000000011', 'ad000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin', 'active', false, null),
  ('ad000000-0000-4000-8000-000000000021', 'ad000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active', false, null),
  ('ad000000-0000-4000-8000-000000000022', 'ad000000-0000-4000-8000-000000000001', 't2@example.test', null, 'Teacher Two', 'active', false, null),
  ('ad000000-0000-4000-8000-000000000081', 'ad000000-0000-4000-8000-000000000001', 'd1@example.test', null, 'Donor One', 'active', false, null),
  ('ad000000-0000-4000-8000-000000000082', 'ad000000-0000-4000-8000-000000000001', 'd2@example.test', null, 'Donor Two', 'active', false, null),
  ('ad000000-0000-4000-8000-000000000031', 'ad000000-0000-4000-8000-000000000001', null, 'spn-1', 'Ayesha Khan', 'active', true, date '2014-06-15'),
  ('ad000000-0000-4000-8000-000000000032', 'ad000000-0000-4000-8000-000000000001', null, 'spn-2', 'Student Two', 'active', false, date '2013-01-01');
insert into app.user_roles (institute_id, user_id, role)
select 'ad000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('ad000000-0000-4000-8000-000000000011', 'admin'), ('ad000000-0000-4000-8000-000000000021', 'teacher'),
  ('ad000000-0000-4000-8000-000000000022', 'teacher'), ('ad000000-0000-4000-8000-000000000081', 'donor'),
  ('ad000000-0000-4000-8000-000000000082', 'donor'), ('ad000000-0000-4000-8000-000000000031', 'student'),
  ('ad000000-0000-4000-8000-000000000032', 'student')) r(id, role);
insert into app.classes (id, institute_id, name, created_by) values
  ('ad000000-0000-4000-8000-000000000051', 'ad000000-0000-4000-8000-000000000001', '{"en":"A"}', 'ad000000-0000-4000-8000-000000000021'),
  ('ad000000-0000-4000-8000-000000000052', 'ad000000-0000-4000-8000-000000000001', '{"en":"B"}', 'ad000000-0000-4000-8000-000000000022');
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-000000000051', 'ad000000-0000-4000-8000-000000000031', 'student'),
  ('ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-000000000052', 'ad000000-0000-4000-8000-000000000032', 'student');
insert into app.personas (id, institute_id, display_name) values
  ('ad000000-0000-4000-8000-000000000061', 'ad000000-0000-4000-8000-000000000001', 'Sitara 701'),
  ('ad000000-0000-4000-8000-000000000062', 'ad000000-0000-4000-8000-000000000001', 'Qalam 702');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-000000000061', 'ad000000-0000-4000-8000-000000000031', 'ad000000-0000-4000-8000-000000000021'),
  ('ad000000-0000-4000-8000-000000000001', 'ad000000-0000-4000-8000-000000000062', 'ad000000-0000-4000-8000-000000000032', 'ad000000-0000-4000-8000-000000000022');
insert into app.donors (id, institute_id, email, user_id, email_verified_at, claimed_at) values
  ('ad000000-0000-4000-8000-000000000091', 'ad000000-0000-4000-8000-000000000001', 'd1@example.test', 'ad000000-0000-4000-8000-000000000081', now(), now()),
  ('ad000000-0000-4000-8000-000000000092', 'ad000000-0000-4000-8000-000000000001', 'd2@example.test', 'ad000000-0000-4000-8000-000000000082', now(), now()),
  ('ad000000-0000-4000-8000-000000000093', 'ad000000-0000-4000-8000-000000000001', 'guest@example.test', null, null, null);
insert into app.causes (id, institute_id, slug, cause_type, title, summary, status, target_period) values
  ('ad000000-0000-4000-8000-000000000041', 'ad000000-0000-4000-8000-000000000001', 'orphan-sponsorship', 'ongoing',
    '{"en":"Orphan sponsorship"}', '{"en":"Care for the children"}', 'active', 'monthly');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number) values
  ('ad000000-0000-4000-8000-000000000042', 'ad000000-0000-4000-8000-000000000001', '{"en":"Main"}', 'Bank', 'Institute', 'spn-1');
insert into app.media_assets (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, status,
  shows_face, uploaded_by) values
  ('ad000000-0000-4000-8000-000000000071', 'ad000000-0000-4000-8000-000000000001', 'image', 'sponsorship_update', 'private',
    'ad000000-0000-4000-8000-000000000001/chart.webp', 'image/webp', 1000, 'ready', false, 'ad000000-0000-4000-8000-000000000021'),
  ('ad000000-0000-4000-8000-000000000072', 'ad000000-0000-4000-8000-000000000001', 'image', 'sponsorship_update', 'private',
    'ad000000-0000-4000-8000-000000000001/face.webp', 'image/webp', 1000, 'ready', true, 'ad000000-0000-4000-8000-000000000021');

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'ad000000-0000-4000-8000-000000000001';
  admin constant uuid := 'ad000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'ad000000-0000-4000-8000-000000000021';
  t2 constant uuid := 'ad000000-0000-4000-8000-000000000022';
  d1 constant uuid := 'ad000000-0000-4000-8000-000000000081';
  d2 constant uuid := 'ad000000-0000-4000-8000-000000000082';
  s1 constant uuid := 'ad000000-0000-4000-8000-000000000031';
  child constant uuid := 'ad000000-0000-4000-8000-000000000061';
  other_child constant uuid := 'ad000000-0000-4000-8000-000000000062';
  donor1 constant uuid := 'ad000000-0000-4000-8000-000000000091';
  donor2 constant uuid := 'ad000000-0000-4000-8000-000000000092';
  guest constant uuid := 'ad000000-0000-4000-8000-000000000093';
  cause constant uuid := 'ad000000-0000-4000-8000-000000000041';
  chart constant uuid := 'ad000000-0000-4000-8000-000000000071';
  face constant uuid := 'ad000000-0000-4000-8000-000000000072';
  sponsorship uuid;
  teacher_update uuid;
  admin_update uuid;
  changed bigint;
  seen record;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- Only an admin matches (REQ-ORP-001).
  perform set_config('app.user_id', t1::text, true);
  begin
    insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
    values (tenant, donor1, child, cause, t1);
    assert false, 'a teacher matched a sponsor';
  exception when insufficient_privilege then null;
  end;
  -- A sponsor needs an account; the child must be an orphan.
  perform set_config('app.user_id', admin::text, true);
  begin
    insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
    values (tenant, guest, child, cause, admin);
    assert false, 'a guest donor became a sponsor';
  exception when check_violation then null;
  end;
  begin
    insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
    values (tenant, donor1, other_child, cause, admin);
    assert false, 'a child who is not an orphan was sponsored';
  exception when check_violation then null;
  end;
  insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by, status)
  values (tenant, donor1, child, cause, t1, 'ended') returning id into sponsorship;
  assert (select matched_by = admin and status = 'active' and ended_on is null from app.sponsorships where id = sponsorship),
    'the match was not recorded as made by the admin';
  -- One sponsor per child (06-P15, Q-18).
  begin
    insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
    values (tenant, donor2, child, cause, admin);
    assert false, 'a child got a second sponsor';
  exception when unique_violation then null;
  end;

  -- The sponsor, the child's teachers and admins read the match; the child,
  -- other sponsors and other teachers do not.
  perform set_config('app.user_id', d1::text, true);
  assert exists (select from app.sponsorships where id = sponsorship), 'the sponsor cannot read their sponsorship';
  foreach changed in array array[1, 2, 3] loop
    perform set_config('app.user_id', (array[d2, s1, t2])[changed]::text, true);
    assert not exists (select from app.sponsorships), 'the wrong person read a sponsorship';
  end loop;
  perform set_config('app.user_id', t1::text, true);
  assert exists (select from app.sponsorships where id = sponsorship), 'the child''s teacher cannot read the sponsorship';

  -- The sponsor's default view: persona name, avatar, age in years, updates (REQ-ORP-002).
  perform set_config('app.user_id', d1::text, true);
  select * into strict seen from app.sponsor_child_view();
  assert seen.sponsorship_id = sponsorship and seen.persona_name = 'Sitara 701'
    and seen.age_years = extract(year from age((now() at time zone 'Asia/Karachi')::date, date '2014-06-15'))
    and seen.updates = '[]', 'the sponsor view is wrong: ' || row_to_json(seen)::text;
  assert row_to_json(seen)::text !~ 'Ayesha|2014-06-15|spn-1', 'the sponsor view shows who the child is';
  foreach changed in array array[1, 2, 3] loop
    perform set_config('app.user_id', (array[d2, s1, t1])[changed]::text, true);
    assert not exists (select from app.sponsor_child_view()), 'someone other than the sponsor got the sponsor view';
  end loop;
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.sponsor_child_view()), 'a visitor got the sponsor view';

  -- A teacher of the child writes an update; it waits for the admin (06-P18).
  perform set_config('app.user_id', t2::text, true);
  begin
    insert into app.sponsorship_updates (institute_id, child_persona_id, body, author_user_id)
    values (tenant, child, '{"en":"Not my student"}', t2);
    assert false, 'a teacher wrote about a child they do not teach';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', t1::text, true);
  begin
    insert into app.sponsorship_updates (institute_id, child_persona_id, body, media_id, author_user_id)
    values (tenant, child, '{"en":"Photo"}', face, t1);
    assert false, 'an update photo showed a face';
  exception when check_violation then null;
  end;
  insert into app.sponsorship_updates (institute_id, child_persona_id, body, media_id, author_user_id, published_at)
  values (tenant, child, '{"en":"Finished juz 3","ur":"تیسرا پارہ مکمل"}', chart, t1, now())
  returning id into teacher_update;
  assert (select published_at is null from app.sponsorship_updates where id = teacher_update),
    'a teacher''s update was published without the admin';
  update app.sponsorship_updates set body = '{"en":"Finished juz 3 with tajweed"}' where id = teacher_update;
  begin
    update app.sponsorship_updates set published_at = now() where id = teacher_update;
    assert false, 'a teacher published their own update';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', d1::text, true);
  assert (select updates from app.sponsor_child_view()) = '[]', 'the sponsor saw an unpublished update';
  -- The admin publishes it; the admin's own update is published at once.
  perform set_config('app.user_id', admin::text, true);
  update app.sponsorship_updates set published_at = now() - interval '1 day' where id = teacher_update;
  assert (select published_at = now() from app.sponsorship_updates where id = teacher_update), 'the admin could not publish';
  insert into app.sponsorship_updates (institute_id, child_persona_id, body, author_user_id)
  values (tenant, child, '{"en":"New uniform"}', admin) returning id into admin_update;
  perform set_config('app.user_id', d1::text, true);
  assert jsonb_array_length((select updates from app.sponsor_child_view())) = 2, 'the sponsor does not see the updates';
  assert (select count(*) from app.sponsorship_updates) = 2, 'the sponsor cannot read the published updates';
  -- Published updates are not edited by their author, and the child never reads them.
  perform set_config('app.user_id', t1::text, true);
  update app.sponsorship_updates set body = '{"en":"Changed"}' where id = teacher_update;
  get diagnostics changed = row_count;
  assert changed = 0, 'a published update was edited by its author';
  perform set_config('app.user_id', s1::text, true);
  assert not exists (select from app.sponsorship_updates), 'the child read the updates';
  -- The admin hides one; the sponsor no longer sees it.
  perform set_config('app.user_id', admin::text, true);
  update app.sponsorship_updates set hidden_at = now() where id = admin_update;
  perform set_config('app.user_id', d1::text, true);
  assert jsonb_array_length((select updates from app.sponsor_child_view())) = 1, 'a hidden update still showed';

  -- Pausing hides the view; ending is final and frees the child for a new match.
  perform set_config('app.user_id', admin::text, true);
  update app.sponsorships set status = 'paused' where id = sponsorship;
  perform set_config('app.user_id', d1::text, true);
  assert not exists (select from app.sponsor_child_view()), 'a paused sponsorship still showed';
  perform set_config('app.user_id', admin::text, true);
  begin
    update app.sponsorships set cause_id = cause where id = sponsorship;
    assert false, 'a sponsorship''s cause was changed';
  exception when insufficient_privilege then null;
  end;
  update app.sponsorships set status = 'ended' where id = sponsorship;
  assert (select ended_on = (now() at time zone 'Asia/Karachi')::date from app.sponsorships where id = sponsorship),
    'the end was not dated';
  begin
    update app.sponsorships set status = 'active' where id = sponsorship;
    assert false, 'an ended sponsorship was restarted';
  exception when object_not_in_prerequisite_state then null;
  end;
  insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
  values (tenant, donor2, child, cause, admin);
end
$test$;

-- A sponsorship gift comes from the sponsor to the sponsorship cause (REQ-ORP-009).
reset role;
set local role tazkiyah_schema_owner;
do $test$
begin
  begin
    insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
      amount_minor, amount_paisa, donation_type, donor_id, cause_id, sponsorship_id, receipt_number, receipt_locale,
      recorded_by)
    select s.institute_id, gen_random_uuid(), 'ad000000-0000-4000-8000-000000000042', 'gift-1', current_date,
      300000, 300000, 'general', 'ad000000-0000-4000-8000-000000000093', s.cause_id, s.id, 'SPN-1', 'en',
      'ad000000-0000-4000-8000-000000000011'
    from app.sponsorships s where s.status = 'active';
    assert false, 'a sponsorship gift came from someone else';
  exception when check_violation then null;
  end;
  insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
    amount_minor, amount_paisa, donation_type, donor_id, cause_id, sponsorship_id, receipt_number, receipt_locale,
    recorded_by)
  select s.institute_id, gen_random_uuid(), 'ad000000-0000-4000-8000-000000000042', 'gift-2', current_date,
    300000, 300000, 'general', s.sponsor_donor_id, s.cause_id, s.id, 'SPN-2', 'en',
    'ad000000-0000-4000-8000-000000000011'
  from app.sponsorships s where s.status = 'active';
  begin
    update app.donations set sponsorship_id = null where receipt_number = 'SPN-2';
    assert false, 'a gift''s sponsorship link changed';
  exception when object_not_in_prerequisite_state then null;
  end;
end
$test$;

rollback;
