-- Sponsor page and class hub for the signed-in donor and student.
-- A child's real name stays out of the sponsor payload until consent, and a
-- phone number cannot be posted or sent.
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('9c000000-0000-4000-8000-000000000001', 'community-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix, enabled_modules)
values ('9c000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'HUB',
  array['student_hub', 'teacher_hub']);
insert into app.users (id, institute_id, email, full_name, status, email_verified) values
  ('9c000000-0000-4000-8000-000000000011', '9c000000-0000-4000-8000-000000000001', 'staff@hub.test', 'Moazam', 'active', true),
  ('9c000000-0000-4000-8000-000000000012', '9c000000-0000-4000-8000-000000000001', 'sponsor@hub.test', 'Amina Donor', 'active', true);
update app.users set must_change_password = false
where id = '9c000000-0000-4000-8000-000000000012';
update app.institute_settings set principal_user_id = '9c000000-0000-4000-8000-000000000011'
where institute_id = '9c000000-0000-4000-8000-000000000001';
insert into app.user_roles (institute_id, user_id, role) values
  ('9c000000-0000-4000-8000-000000000001', '9c000000-0000-4000-8000-000000000011', 'admin'),
  ('9c000000-0000-4000-8000-000000000001', '9c000000-0000-4000-8000-000000000011', 'teacher'),
  ('9c000000-0000-4000-8000-000000000001', '9c000000-0000-4000-8000-000000000012', 'donor');
insert into app.classes (id, institute_id, name, created_by) values
  ('9c000000-0000-4000-8000-000000000021', '9c000000-0000-4000-8000-000000000001',
    '{"en":"Hifz 1","ur":"حفظ ۱"}', '9c000000-0000-4000-8000-000000000011');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status) values
  ('9c000000-0000-4000-8000-000000000041', '9c000000-0000-4000-8000-000000000001', 'orphans', 'ongoing',
    '{"en":"Orphan sponsorship"}', '{"en":"Care"}', 'monthly', 'active');
insert into app.donors (id, institute_id, user_id, preferred_language) values
  ('9c000000-0000-4000-8000-000000000051', '9c000000-0000-4000-8000-000000000001',
    '9c000000-0000-4000-8000-000000000012', 'ur');

set constraints all immediate;
do $test$
declare
  tenant constant uuid := '9c000000-0000-4000-8000-000000000001';
  staff constant uuid := '9c000000-0000-4000-8000-000000000011';
  sponsor_user constant uuid := '9c000000-0000-4000-8000-000000000012';
  sponsor_donor constant uuid := '9c000000-0000-4000-8000-000000000051';
  class_id constant uuid := '9c000000-0000-4000-8000-000000000021';
  student uuid;
  persona uuid;
  persona_name text;
  sponsorship uuid;
  sponsor_session constant uuid := '9c000000-0000-4000-8000-000000000061';
  student_session constant uuid := '9c000000-0000-4000-8000-000000000062';
  children jsonb;
  started jsonb;
  thread_id uuid;
  thread_view jsonb;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', staff::text, true);
  student := app.create_student_account('Yusuf Lateef', 'hub-2016-0001', class_id, true);
  assert student is not null, 'the admin created the orphan account';
  update app.users set must_change_password = false, date_of_birth = '2016-04-02'
  where id = student;
  select l.persona_id, p.display_name into persona, persona_name
  from app.persona_links l
  join app.personas p on p.institute_id = l.institute_id and p.id = l.persona_id
  where l.user_id = student;

  insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
  values (tenant, sponsor_donor, persona, '9c000000-0000-4000-8000-000000000041', staff)
  returning id into sponsorship;

  perform set_config('app.user_id', sponsor_user::text, true);
  insert into identity.sessions (id, user_id, token, expires_at)
  values (sponsor_session, sponsor_user, 'sponsor-session-token', now() + interval '1 day');
  children := identity.read_sponsor_children(sponsor_session);
  assert children->>'code' = 'ok', 'the sponsor can open the page';
  assert children->'children'->0->>'persona_name' = persona_name, 'the pen name is shown';
  assert (children->'children'->0->>'full_profile')::boolean = false, 'consent is off';
  assert children->'children'->0->>'full_name' is null, 'the real name stays hidden';
  assert children::text not like '%Yusuf%', 'the payload does not contain the real name';
  assert identity.send_sponsor_message(sponsor_session, sponsorship,
    'Please call 03001234567', 'en') = 'contact_details', 'a phone number is refused';
  assert identity.send_sponsor_message(sponsor_session, sponsorship,
    'How is the child doing in class?', 'ur') = 'sent', 'a plain message is accepted';
  assert identity.read_sponsor_messages(sponsor_session, sponsorship)::text like '%How is the child doing in class?%',
    'the sponsor can read the message back';
  assert identity.read_sponsor_messages(sponsor_session, sponsorship)::text not like '%Yusuf%',
    'messages do not name the child';

  perform set_config('app.user_id', student::text, true);
  insert into identity.sessions (id, user_id, token, expires_at)
  values (student_session, student, 'student-session-token', now() + interval '1 day');
  assert identity.start_hub_thread(student_session, 'class', class_id, 'message', 'ur',
    null, 'My number is 03001234567')->>'code' = 'contact_details',
    'a student cannot post a phone number';
  started := identity.start_hub_thread(student_session, 'class', class_id, 'question', 'ur',
    'نماز کا سوال', 'استاد، نماز کے اوقات کیسے یاد رکھوں؟');
  assert started->>'code' = 'posted', started::text;
  thread_id := (started->>'thread_id')::uuid;
  assert identity.reply_hub_thread(student_session, thread_id, null, 'message', 'ur',
    'السلام علیکم') = 'posted', 'a reply appears at once';
  thread_view := identity.read_hub(student_session, null, null, thread_id);
  assert thread_view->'posts'->0->>'author_name' = persona_name, 'classmates see the pen name';
  assert thread_view::text not like '%Yusuf%', 'the thread does not contain the real name';
  assert thread_view::text not like '%user_id%', 'the thread does not contain a user id field';
end
$test$;
rollback;
