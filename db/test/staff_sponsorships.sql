-- An admin matches one sponsor to one orphan (P4-E1-T01).
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('b9000000-0000-4000-8000-000000000001', 'staff-sponsor');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('b9000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SSP');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('b9000000-0000-4000-8000-000000000011', 'b9000000-0000-4000-8000-000000000001', 'admin@staff-sponsor.test', 'Admin', 'active', true, false),
  ('b9000000-0000-4000-8000-000000000021', 'b9000000-0000-4000-8000-000000000001', 'teacher@staff-sponsor.test', 'Teacher', 'active', false, false),
  ('b9000000-0000-4000-8000-000000000031', 'b9000000-0000-4000-8000-000000000001', 'sponsor@staff-sponsor.test', 'Ayesha Khan', 'active', false, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('b9000000-0000-4000-8000-000000000001', 'b9000000-0000-4000-8000-000000000011', 'admin'),
  ('b9000000-0000-4000-8000-000000000001', 'b9000000-0000-4000-8000-000000000021', 'teacher'),
  ('b9000000-0000-4000-8000-000000000001', 'b9000000-0000-4000-8000-000000000031', 'donor');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('b9000000-0000-4000-8000-000000000001', 'b9000000-0000-4000-8000-000000000011', 'secret', 'codes', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('b9000000-0000-4000-8000-000000000061', 'b9000000-0000-4000-8000-000000000001', 'b9000000-0000-4000-8000-000000000011', 'admin-session', now() + interval '1 hour', now(), now()),
  ('b9000000-0000-4000-8000-000000000062', 'b9000000-0000-4000-8000-000000000001', 'b9000000-0000-4000-8000-000000000021', 'teacher-session', now() + interval '1 hour', now(), null);
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status) values
  ('b9000000-0000-4000-8000-000000000041', 'b9000000-0000-4000-8000-000000000001', 'orphans', 'ongoing',
    '{"en":"Orphan sponsorship"}', '{"en":"Care"}', 'monthly', 'active');
insert into app.donors (id, institute_id, user_id, preferred_language) values
  ('b9000000-0000-4000-8000-000000000051', 'b9000000-0000-4000-8000-000000000001', 'b9000000-0000-4000-8000-000000000031', 'en');
select set_config('app.institute_id', 'b9000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'b9000000-0000-4000-8000-000000000021', true);
insert into app.classes (id, institute_id, name, created_by) values
  ('b9000000-0000-4000-8000-000000000071', 'b9000000-0000-4000-8000-000000000001', '{"en":"Hifz"}', 'b9000000-0000-4000-8000-000000000021');
select app.create_student_account('Yusuf Ali', 'sponsor-child', 'b9000000-0000-4000-8000-000000000071', true);
create temp table fixture_persona (id uuid);
insert into fixture_persona select l.persona_id from app.persona_links l
join app.users u on u.id = l.user_id where u.username = 'sponsor-child';
grant select on fixture_persona to tazkiyah_auth;

reset role;
set local role tazkiyah_auth;
select set_config('app.institute_id', 'b9000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'b9000000-0000-4000-8000-000000000021', true);

do $test$
declare
  teacher_session constant uuid := 'b9000000-0000-4000-8000-000000000062';
  admin_session constant uuid := 'b9000000-0000-4000-8000-000000000061';
  donor constant uuid := 'b9000000-0000-4000-8000-000000000051';
  cause constant uuid := 'b9000000-0000-4000-8000-000000000041';
  persona uuid;
  decision text;
  workspace jsonb;
  match_id uuid;
begin
  select id into persona from fixture_persona;
  decision := identity.match_sponsorship(teacher_session, donor, persona, cause);
  assert decision = 'denied', decision;

  perform set_config('app.user_id', 'b9000000-0000-4000-8000-000000000011', true);
  decision := identity.match_sponsorship(admin_session, donor, persona, cause);
  assert decision = 'matched', decision;
  decision := identity.match_sponsorship(admin_session, donor, persona, cause);
  assert decision = 'already_matched', decision;

  workspace := identity.sponsorship_workspace(admin_session);
  assert exists (
    select from jsonb_array_elements(workspace -> 'matches') item
    where item ->> 'real_name' = 'Yusuf Ali' and item ->> 'sponsor' = 'Ayesha Khan'
  ), workspace::text;
  select (item ->> 'id')::uuid into match_id
  from jsonb_array_elements(workspace -> 'matches') item;
  assert identity.end_sponsorship(admin_session, match_id) = 'ended', 'could not end';
  workspace := identity.sponsorship_workspace(admin_session);
  assert jsonb_array_length(workspace -> 'matches') = 0, 'ended match still listed';
  assert jsonb_array_length(workspace -> 'orphans') = 1, 'orphan did not return to the list';
end
$test$;
