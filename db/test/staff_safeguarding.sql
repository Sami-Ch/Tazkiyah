-- Staff consent, second sign-off, sponsor inbox and progress notes
-- (REQ-CHS-006, REQ-ORP-004, REQ-ORP-007, REQ-ORP-008).
begin;
grant tazkiyah_auth to current_user;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('c1000000-0000-4000-8000-000000000001', 'safeguard-a'),
  ('c1000000-0000-4000-8000-000000000002', 'safeguard-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix) values
  ('c1000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SFA'),
  ('c1000000-0000-4000-8000-000000000002', '{"en":"Other"}', '{"en":"B"}', '{}', 'SFB');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('c1000000-0000-4000-8000-000000000011', 'c1000000-0000-4000-8000-000000000001', 'principal@safeguard.test', 'Principal', 'active', true, false),
  ('c1000000-0000-4000-8000-000000000012', 'c1000000-0000-4000-8000-000000000001', 'admin2@safeguard.test', 'Other Admin', 'active', true, false),
  ('c1000000-0000-4000-8000-000000000021', 'c1000000-0000-4000-8000-000000000001', 't1@safeguard.test', 'Teacher One', 'active', false, false),
  ('c1000000-0000-4000-8000-000000000022', 'c1000000-0000-4000-8000-000000000001', 't2@safeguard.test', 'Teacher Two', 'active', false, false),
  ('c1000000-0000-4000-8000-000000000031', 'c1000000-0000-4000-8000-000000000001', 'sponsor@safeguard.test', 'Sponsor', 'active', false, false),
  ('c1000000-0000-4000-8000-000000000091', 'c1000000-0000-4000-8000-000000000002', 'other@safeguard.test', 'Other Admin', 'active', true, false);
update app.institute_settings set principal_user_id = 'c1000000-0000-4000-8000-000000000011'
where institute_id = 'c1000000-0000-4000-8000-000000000001';
update app.institute_settings set principal_user_id = 'c1000000-0000-4000-8000-000000000091'
where institute_id = 'c1000000-0000-4000-8000-000000000002';
insert into app.user_roles (institute_id, user_id, role) values
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000011', 'admin'),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000012', 'admin'),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000021', 'teacher'),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000022', 'teacher'),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000031', 'donor'),
  ('c1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000091', 'admin');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000011', 'secret', 'codes', true),
  ('c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000012', 'secret', 'codes', true),
  ('c1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000091', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('c1000000-0000-4000-8000-000000000061', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000011', 'principal-session', now() + interval '1 hour', now(), now()),
  ('c1000000-0000-4000-8000-000000000062', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000012', 'admin-session', now() + interval '1 hour', now(), now()),
  ('c1000000-0000-4000-8000-000000000063', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000021', 'teacher-session', now() + interval '1 hour', now(), null),
  ('c1000000-0000-4000-8000-000000000064', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000022', 'other-teacher', now() + interval '1 hour', now(), null),
  ('c1000000-0000-4000-8000-000000000065', 'c1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000091', 'other-admin', now() + interval '1 hour', now(), now());
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status) values
  ('c1000000-0000-4000-8000-000000000041', 'c1000000-0000-4000-8000-000000000001', 'orphans', 'ongoing',
    '{"en":"Orphan care"}', '{"en":"Care"}', 'monthly', 'active');
insert into app.donors (id, institute_id, user_id, preferred_language) values
  ('c1000000-0000-4000-8000-000000000051', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000031', 'en');

select set_config('app.institute_id', 'c1000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'c1000000-0000-4000-8000-000000000021', true);
insert into app.classes (id, institute_id, name, created_by) values
  ('c1000000-0000-4000-8000-000000000071', 'c1000000-0000-4000-8000-000000000001', '{"en":"Hifz"}',
    'c1000000-0000-4000-8000-000000000021');
select app.create_student_account('Sample Student', 'safe-student', 'c1000000-0000-4000-8000-000000000071', false);
select app.create_student_account('Sample Orphan', 'safe-orphan', 'c1000000-0000-4000-8000-000000000071', true);
create temp table safeguard_ids (student uuid, orphan uuid, persona uuid);
insert into safeguard_ids
select student.id, orphan.id, link.persona_id
from app.users student
join app.users orphan on orphan.username = 'safe-orphan'
join app.persona_links link on link.user_id = orphan.id
where student.username = 'safe-student';
grant select on safeguard_ids to tazkiyah_auth, tazkiyah_app;
create temp table safeguard_flow (match_id uuid, consent_id uuid, update_id uuid);
grant select, insert, update on safeguard_flow to tazkiyah_auth, tazkiyah_app;

reset role;
set local role tazkiyah_auth;
select set_config('app.institute_id', 'c1000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'c1000000-0000-4000-8000-000000000021', true);

do $test$
declare
  tenant constant uuid := 'c1000000-0000-4000-8000-000000000001';
  other constant uuid := 'c1000000-0000-4000-8000-000000000002';
  principal constant uuid := 'c1000000-0000-4000-8000-000000000011';
  admin2 constant uuid := 'c1000000-0000-4000-8000-000000000012';
  teacher constant uuid := 'c1000000-0000-4000-8000-000000000021';
  teacher2 constant uuid := 'c1000000-0000-4000-8000-000000000022';
  donor constant uuid := 'c1000000-0000-4000-8000-000000000051';
  cause constant uuid := 'c1000000-0000-4000-8000-000000000041';
  principal_session constant uuid := 'c1000000-0000-4000-8000-000000000061';
  admin_session constant uuid := 'c1000000-0000-4000-8000-000000000062';
  teacher_session constant uuid := 'c1000000-0000-4000-8000-000000000063';
  other_teacher constant uuid := 'c1000000-0000-4000-8000-000000000064';
  other_session constant uuid := 'c1000000-0000-4000-8000-000000000065';
  student uuid;
  orphan uuid;
  persona uuid;
  decision text;
  workspace jsonb;
  consent_id uuid;
  match_id uuid;
  media uuid;
begin
  select safeguard_ids.student, safeguard_ids.orphan, safeguard_ids.persona
    into student, orphan, persona from safeguard_ids;

  perform set_config('app.user_id', teacher2::text, true);
  decision := identity.record_consent(other_teacher, student, 'public_work', 'Guardian', 'father',
    'in_person', current_date, null, null);
  assert decision = 'denied', decision;

  perform set_config('app.user_id', teacher::text, true);
  decision := identity.record_consent(teacher_session, student, 'public_work', 'Guardian', 'father',
    'in_person', current_date, null, null);
  assert decision = 'recorded', decision;
  workspace := identity.consent_workspace(teacher_session);
  assert exists (
    select from jsonb_array_elements(workspace -> 'records') item
    where item ->> 'student_id' = student::text and item ->> 'kind' = 'public_work'
      and item ->> 'status' = 'active'
  ), workspace::text;

  decision := identity.record_consent(teacher_session, student, 'public_work', '03001234567', 'father',
    'phone', current_date, null, null);
  assert decision = 'invalid', decision;

  perform set_config('app.institute_id', other::text, true);
  perform set_config('app.user_id', 'c1000000-0000-4000-8000-000000000091', true);
  workspace := identity.consent_workspace(other_session);
  assert workspace ->> 'allowed' = 'true', 'other institute admin was refused their own screen';
  assert jsonb_array_length(workspace -> 'records') = 0, 'other institute saw this consent';
  assert jsonb_array_length(workspace -> 'students') = 0, 'other institute saw this student';
  perform set_config('app.institute_id', tenant::text, true);

  perform set_config('app.user_id', admin2::text, true);
  decision := identity.match_sponsorship(admin_session, donor, persona, cause);
  assert decision = 'matched', decision;
  workspace := identity.sponsorship_workspace(admin_session);
  select (item ->> 'id')::uuid into match_id
  from jsonb_array_elements(workspace -> 'matches') item
  where item ->> 'student_id' = orphan::text;
  assert match_id is not null, workspace::text;
  decision := identity.record_consent(admin_session, orphan, 'orphan_full_profile', 'Principal', 'principal',
    'in_person', current_date, null, match_id);
  assert decision = 'denied', 'a non-principal opened full-profile consent';

  perform set_config('app.user_id', principal::text, true);
  decision := identity.record_consent(principal_session, orphan, 'orphan_full_profile', 'Principal', 'principal',
    'in_person', current_date, null, match_id);
  assert decision = 'recorded', decision;
  workspace := identity.consent_workspace(principal_session);
  select (item ->> 'id')::uuid into consent_id
  from jsonb_array_elements(workspace -> 'records') item
  where item ->> 'kind' = 'orphan_full_profile' and item ->> 'student_id' = orphan::text;
  perform set_config('app.user_id', admin2::text, true);
  decision := identity.consent_action(admin_session, consent_id, 'assign', teacher2, null);
  assert decision = 'denied', decision;
  perform set_config('app.user_id', principal::text, true);
  decision := identity.consent_action(principal_session, consent_id, 'assign', teacher, null);
  assert decision = 'assigned', decision;
  decision := identity.consent_action(principal_session, consent_id, 'sign', null, null);
  assert decision = 'principal_signed', decision;

  perform set_config('app.user_id', teacher2::text, true);
  decision := identity.consent_action(other_teacher, consent_id, 'sign', null, null);
  assert decision = 'denied', 'the unassigned teacher signed';
  perform set_config('app.user_id', teacher::text, true);
  decision := identity.consent_action(teacher_session, consent_id, 'sign', null, null);
  assert decision = 'second_signed', decision;

  perform set_config('app.user_id', principal::text, true);
  workspace := identity.sponsorship_workspace(principal_session);
  assert workspace ->> 'is_principal' = 'true', 'principal flag missing';
  assert exists (
    select from jsonb_array_elements(workspace -> 'matches') item
    where item ->> 'consent_status' = 'active' and item ->> 'second_signer' = 'Teacher One'
  ), workspace::text;
  assert not exists (
    select from jsonb_array_elements(workspace -> 'messages') item
    where item ? 'child' or item ? 'student'
  ), 'a message named a child as a party';

  perform set_config('app.user_id', teacher::text, true);
  decision := identity.reply_sponsor_message(teacher_session, match_id, 'We received it', 'en');
  assert decision = 'denied', decision;
  perform set_config('app.user_id', principal::text, true);
  decision := identity.reply_sponsor_message(principal_session, match_id, 'Call 03001234567', 'en');
  assert decision = 'contact_details', decision;
  decision := identity.reply_sponsor_message(principal_session, match_id, 'The madrasa received the note', 'ur');
  assert decision = 'sent', decision;
  assert not exists (
    select from information_schema.columns
    where table_schema = 'app' and table_name = 'sponsor_messages'
      and column_name ~* 'child|persona|student'
  ), 'sponsor messages gained a child column';

  perform set_config('app.user_id', teacher::text, true);
  decision := identity.write_progress_update(teacher_session, persona, 'اس ہفتے سبق مکمل ہوا', null);
  assert decision = 'waiting', decision;
  workspace := identity.progress_workspace(teacher_session);
  assert exists (
    select from jsonb_array_elements(workspace -> 'updates') item
    where item ->> 'persona_id' = persona::text and (item ->> 'published')::boolean = false
      and not (item -> 'body' ? 'media')
  ), workspace::text;
  select (item ->> 'id')::uuid into media
  from jsonb_array_elements(workspace -> 'updates') item
  where item ->> 'persona_id' = persona::text;
  decision := identity.write_progress_update(teacher_session, persona, null, 'Sample Orphan finished the lesson');
  assert decision = 'real_name', decision;
  decision := identity.progress_action(teacher_session, media, 'publish');
  assert decision = 'denied', decision;

  perform set_config('app.user_id', principal::text, true);
  decision := identity.progress_action(principal_session, media, 'publish');
  assert decision = 'published', decision;
  insert into safeguard_flow values (match_id, consent_id, media);
end
$test$;

set local role tazkiyah_app;
select set_config('app.institute_id', 'c1000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'c1000000-0000-4000-8000-000000000031', true);
do $sponsor$
declare
  match_id uuid;
begin
  select safeguard_flow.match_id into match_id from safeguard_flow;
  assert exists (
    select from app.sponsor_child_view() v
    where v.sponsorship_id = match_id and v.updates <> '[]'::jsonb and v.full_profile
  ), 'the sponsor could not read the published note or the full profile';
end
$sponsor$;

set local role tazkiyah_auth;
select set_config('app.user_id', 'c1000000-0000-4000-8000-000000000011', true);
do $withdraw$
declare
  decision text;
begin
  decision := identity.consent_action(
    'c1000000-0000-4000-8000-000000000061',
    (select consent_id from safeguard_flow), 'withdraw', null, 'Guardian asked');
  assert decision = 'withdrawn_now', decision;
end
$withdraw$;

set local role tazkiyah_app;
select set_config('app.user_id', 'c1000000-0000-4000-8000-000000000031', true);
do $hidden$
begin
  assert exists (
    select from app.sponsor_child_view() v
    where v.sponsorship_id = (select match_id from safeguard_flow) and not v.full_profile
  ), 'withdrawal did not hide the full profile';
end
$hidden$;
