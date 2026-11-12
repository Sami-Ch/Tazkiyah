-- Messages between a sponsor and the madrasa, with no path to the child
-- (04 §10.3, 06 §12.5, REQ-ORP-007, P4-E3-T40).
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('b0000000-0000-4000-8000-000000000001', 'sponsor-messages-fixture');
insert into app.users (id, institute_id, email, username, full_name, status, is_orphan) values
  ('b0000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000001', 'admin@example.test', null, 'Admin', 'active', false),
  ('b0000000-0000-4000-8000-000000000021', 'b0000000-0000-4000-8000-000000000001', 't1@example.test', null, 'Teacher One', 'active', false),
  ('b0000000-0000-4000-8000-000000000081', 'b0000000-0000-4000-8000-000000000001', 'd1@example.test', null, 'Donor One', 'active', false),
  ('b0000000-0000-4000-8000-000000000082', 'b0000000-0000-4000-8000-000000000001', 'd2@example.test', null, 'Donor Two', 'active', false),
  ('b0000000-0000-4000-8000-000000000031', 'b0000000-0000-4000-8000-000000000001', null, 'msg-1', 'Ayesha Khan', 'active', true),
  ('b0000000-0000-4000-8000-000000000032', 'b0000000-0000-4000-8000-000000000001', null, 'msg-2', 'Student Two', 'active', true);
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules, principal_user_id)
values ('b0000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'MSG',
  array['student_hub'], 'b0000000-0000-4000-8000-000000000011');
insert into app.user_roles (institute_id, user_id, role)
select 'b0000000-0000-4000-8000-000000000001', id::uuid, role from (values
  ('b0000000-0000-4000-8000-000000000011', 'admin'), ('b0000000-0000-4000-8000-000000000021', 'teacher'),
  ('b0000000-0000-4000-8000-000000000081', 'donor'), ('b0000000-0000-4000-8000-000000000082', 'donor'),
  ('b0000000-0000-4000-8000-000000000031', 'student'), ('b0000000-0000-4000-8000-000000000032', 'student')) r(id, role);
insert into app.classes (id, institute_id, name, created_by) values
  ('b0000000-0000-4000-8000-000000000051', 'b0000000-0000-4000-8000-000000000001', '{"en":"A"}', 'b0000000-0000-4000-8000-000000000021');
insert into app.class_members (institute_id, class_id, user_id, member_role) values
  ('b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000051', 'b0000000-0000-4000-8000-000000000031', 'student'),
  ('b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000051', 'b0000000-0000-4000-8000-000000000032', 'student');
insert into app.personas (id, institute_id, display_name) values
  ('b0000000-0000-4000-8000-000000000061', 'b0000000-0000-4000-8000-000000000001', 'Sitara 601'),
  ('b0000000-0000-4000-8000-000000000062', 'b0000000-0000-4000-8000-000000000001', 'Qalam 602');
insert into app.persona_links (institute_id, persona_id, user_id, created_by) values
  ('b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000061', 'b0000000-0000-4000-8000-000000000031', 'b0000000-0000-4000-8000-000000000021'),
  ('b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000062', 'b0000000-0000-4000-8000-000000000032', 'b0000000-0000-4000-8000-000000000021');
insert into app.donors (id, institute_id, email, user_id, email_verified_at, claimed_at) values
  ('b0000000-0000-4000-8000-000000000091', 'b0000000-0000-4000-8000-000000000001', 'd1@example.test', 'b0000000-0000-4000-8000-000000000081', now(), now()),
  ('b0000000-0000-4000-8000-000000000092', 'b0000000-0000-4000-8000-000000000001', 'd2@example.test', 'b0000000-0000-4000-8000-000000000082', now(), now());
insert into app.causes (id, institute_id, slug, cause_type, title, summary, status, target_period) values
  ('b0000000-0000-4000-8000-000000000041', 'b0000000-0000-4000-8000-000000000001', 'orphan-sponsorship', 'ongoing',
    '{"en":"Orphan sponsorship"}', '{"en":"Care for the children"}', 'active', 'monthly');
insert into app.sponsorships (id, institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by) values
  ('b0000000-0000-4000-8000-000000000071', 'b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000091',
    'b0000000-0000-4000-8000-000000000061', 'b0000000-0000-4000-8000-000000000041', 'b0000000-0000-4000-8000-000000000011'),
  ('b0000000-0000-4000-8000-000000000072', 'b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000092',
    'b0000000-0000-4000-8000-000000000062', 'b0000000-0000-4000-8000-000000000041', 'b0000000-0000-4000-8000-000000000011');

-- No column of the table can name a child or a student (REQ-ORP-007).
do $test$
begin
  assert not exists (select from pg_constraint c
    where c.conrelid = 'app.sponsor_messages'::regclass and c.contype = 'f'
      and c.confrelid in ('app.personas'::regclass, 'app.persona_links'::regclass)),
    'a message can point at a persona';
  assert not exists (select from pg_attribute a
    where a.attrelid = 'app.sponsor_messages'::regclass and a.attnum > 0 and not a.attisdropped
      and a.attname ~ '(child|persona|student|recipient)'),
    'a message has a column for a child';
end
$test$;

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'b0000000-0000-4000-8000-000000000001';
  admin constant uuid := 'b0000000-0000-4000-8000-000000000011';
  t1 constant uuid := 'b0000000-0000-4000-8000-000000000021';
  d1 constant uuid := 'b0000000-0000-4000-8000-000000000081';
  d2 constant uuid := 'b0000000-0000-4000-8000-000000000082';
  s1 constant uuid := 'b0000000-0000-4000-8000-000000000031';
  donor1 constant uuid := 'b0000000-0000-4000-8000-000000000091';
  donor2 constant uuid := 'b0000000-0000-4000-8000-000000000092';
  sponsorship constant uuid := 'b0000000-0000-4000-8000-000000000071';
  other_sponsorship constant uuid := 'b0000000-0000-4000-8000-000000000072';
  question uuid;
  reply uuid;
  changed bigint;
begin
  perform set_config('app.institute_id', tenant::text, true);

  -- The sponsor writes to the madrasa about their child (REQ-ORP-007).
  perform set_config('app.user_id', d1::text, true);
  insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_donor_id, read_at)
  values (tenant, sponsorship, 'to_madrasa', 'How is she doing in Quran class?', 'en', donor1, now())
  returning id into question;
  assert (select read_at from app.sponsor_messages where id = question) is null, 'a new message arrived read';
  begin
    insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_donor_id)
    values (tenant, other_sponsorship, 'to_madrasa', 'Pretending', 'en', donor2);
    assert false, 'a sponsor wrote as another donor';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_user_id)
    values (tenant, sponsorship, 'to_sponsor', 'Fake reply', 'en', d1);
    assert false, 'a sponsor wrote a madrasa reply';
  exception when insufficient_privilege or check_violation then null;
  end;

  -- Another sponsor can neither read nor write on that sponsorship.
  perform set_config('app.user_id', d2::text, true);
  assert not exists (select from app.sponsor_messages), 'another sponsor read the messages';
  begin
    insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_donor_id)
    values (tenant, sponsorship, 'to_madrasa', 'Not my sponsorship', 'en', donor2);
    assert false, 'a sponsor wrote on someone else''s sponsorship';
  exception when check_violation then null;
  end;

  -- The child and the child's teacher have no path to the messages.
  foreach changed in array array[1, 2] loop
    perform set_config('app.user_id', (case changed when 1 then s1 else t1 end)::text, true);
    assert not exists (select from app.sponsor_messages), 'a student or teacher read sponsor messages';
    begin
      insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_user_id)
      values (tenant, sponsorship, 'to_sponsor', 'Hello', 'en', case changed when 1 then s1 else t1 end);
      assert false, 'a student or teacher wrote to a sponsor';
    exception when insufficient_privilege or check_violation then null;
    end;
  end loop;

  -- An admin reads and replies under their own name.
  perform set_config('app.user_id', admin::text, true);
  assert (select count(*) from app.sponsor_messages) = 1, 'the admin does not see the message';
  begin
    insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_user_id)
    values (tenant, sponsorship, 'to_sponsor', 'As someone else', 'en', t1);
    assert false, 'an admin replied in another person''s name';
  exception when insufficient_privilege or check_violation then null;
  end;
  insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_user_id)
  values (tenant, sponsorship, 'to_sponsor', 'She is learning well.', 'en', admin) returning id into reply;

  -- Each side marks only what it received, once.
  with t as (update app.sponsor_messages set read_at = now() where id = reply returning 1) select count(*) into changed from t;
  assert changed = 0, 'the admin marked their own reply read';
  with t as (update app.sponsor_messages set read_at = now() where id = question returning 1) select count(*) into changed from t;
  assert changed = 1, 'the admin could not mark the message read';
  begin
    update app.sponsor_messages set read_at = now() where id = question;
    assert false, 'a message was marked read twice';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.sponsor_messages set body = 'Changed' where id = question;
    assert false, 'a message body changed';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from app.sponsor_messages where id = question;
    assert false, 'a message was deleted';
  exception when insufficient_privilege then null;
  end;
  perform set_config('app.user_id', d1::text, true);
  assert (select count(*) from app.sponsor_messages) = 2, 'the sponsor does not see the reply';
  with t as (update app.sponsor_messages set read_at = now() where id = reply returning 1) select count(*) into changed from t;
  assert changed = 1, 'the sponsor could not mark the reply read';

  -- While paused the sponsor cannot write, but the madrasa can still reply;
  -- once ended, nobody writes, and the sponsor keeps the history.
  perform set_config('app.user_id', admin::text, true);
  update app.sponsorships set status = 'paused' where id = sponsorship;
  perform set_config('app.user_id', d1::text, true);
  begin
    insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_donor_id)
    values (tenant, sponsorship, 'to_madrasa', 'Still there?', 'en', donor1);
    assert false, 'a sponsor wrote on a paused sponsorship';
  exception when check_violation then null;
  end;
  perform set_config('app.user_id', admin::text, true);
  insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_user_id)
  values (tenant, sponsorship, 'to_sponsor', 'The sponsorship is paused for now.', 'en', admin);
  update app.sponsorships set status = 'ended' where id = sponsorship;
  begin
    insert into app.sponsor_messages (institute_id, sponsorship_id, direction, body, language, sender_user_id)
    values (tenant, sponsorship, 'to_sponsor', 'After the end', 'en', admin);
    assert false, 'a reply was written on an ended sponsorship';
  exception when check_violation then null;
  end;
  perform set_config('app.user_id', d1::text, true);
  assert (select count(*) from app.sponsor_messages) = 3, 'the sponsor lost the message history';

  -- Visitors see nothing.
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.sponsor_messages), 'a visitor read sponsor messages';
end
$test$;

rollback;
