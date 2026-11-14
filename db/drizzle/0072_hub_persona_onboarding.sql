SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Class hub completion: persona profile, first-login progress and the alumni
-- class (REQ-STU-002, REQ-STU-003, REQ-STU-009, REQ-STU-010, D-160, D-161, D-164).
-- Preset avatars are numbers 1 to 24. Photo upload needs object storage, so it
-- is not stored here.

alter table app.users add column onboarding_step smallint not null default 1;
--> statement-breakpoint
alter table app.users add column onboarding_skipped text[] not null default '{}';
--> statement-breakpoint
alter table app.users add column public_role text;
--> statement-breakpoint
alter table app.users add constraint users_onboarding_step_check
  check (onboarding_step between 1 and 8);
--> statement-breakpoint
alter table app.users add constraint users_onboarding_skipped_check
  check (onboarding_skipped <@ array['name', 'avatar', 'bio']::text[]);
--> statement-breakpoint
alter table app.users add constraint users_public_role_check
  check (public_role is null or (length(public_role) between 1 and 80 and public_role = btrim(public_role)));
--> statement-breakpoint
alter table app.personas add column avatar_preset smallint;
--> statement-breakpoint
alter table app.personas add column display_name_changed_at timestamptz;
--> statement-breakpoint
alter table app.personas add column reset_note text;
--> statement-breakpoint
alter table app.personas add constraint personas_avatar_preset_check
  check (avatar_preset is null or avatar_preset between 1 and 24);
--> statement-breakpoint
alter table app.personas add constraint personas_reset_note_check
  check (reset_note is null or reset_note = 'reset');
--> statement-breakpoint
alter table app.classes add column kind text not null default 'class';
--> statement-breakpoint
alter table app.classes add constraint classes_kind_check check (kind in ('class', 'alumni'));
--> statement-breakpoint
create unique index classes_one_alumni on app.classes (institute_id) where kind = 'alumni';
--> statement-breakpoint
create table app.persona_names (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references app.institutes (id),
  persona_id uuid not null,
  display_name text not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  unique (institute_id, id),
  foreign key (institute_id, persona_id) references app.personas (institute_id, id),
  check (ended_at is null or ended_at >= started_at),
  check (app.persona_name_ok(display_name))
);
--> statement-breakpoint
create index persona_names_persona on app.persona_names (institute_id, persona_id, started_at);
--> statement-breakpoint
alter table app.persona_names enable row level security;
--> statement-breakpoint
create policy iso on app.persona_names as restrictive for all to tazkiyah_app
  using (institute_id = (select app.current_institute_id()))
  with check (institute_id = (select app.current_institute_id()));
--> statement-breakpoint
insert into app.persona_names (institute_id, persona_id, display_name, started_at)
select institute_id, id, display_name, created_at from app.personas;
--> statement-breakpoint
-- A pen name or bio must not be a real name, a phone number, or an insult
-- (07 §4.2, §12.2, REQ-CHS-001, REQ-CHS-002).
create function app.persona_text_blocked(p_value text) returns boolean
language sql immutable
set search_path = pg_catalog, pg_temp
return lower(p_value) ~ '\m(idiot|stupid|dumb|hate|kill|ugly|loser)\M'
  or p_value ~ '(بیوقوف|احمق|گدھا)';
--> statement-breakpoint
create function app.persona_text_has_real_name(p_institute uuid, p_value text, p_tokens int)
returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return exists (
  select from app.users u
  where u.institute_id = p_institute and length(btrim(u.full_name)) >= 3 and (
    position(lower(btrim(u.full_name)) in lower(p_value)) > 0
    or exists (
      select from regexp_split_to_table(u.full_name, '[[:space:]]+') as token
      where length(token) >= p_tokens and lower(p_value) ~ ('\m' || lower(token) || '\M')
    )
  )
);
--> statement-breakpoint
-- The alumni class stays open, and its kind never changes (07 §4.7).
create function app.classes_kind_guard() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op = 'UPDATE' and new.kind is distinct from old.kind then
    raise exception 'a class keeps its kind' using errcode = 'insufficient_privilege';
  end if;
  if new.kind = 'alumni' and new.archived_at is not null then
    raise exception 'the alumni class stays open' using errcode = 'object_not_in_prerequisite_state';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger classes_kind_guard before insert or update on app.classes
for each row execute function app.classes_kind_guard();
--> statement-breakpoint
-- Checks a new pen name or bio before it is saved (07 §4.2, §12.2).
create function app.personas_profile_guard() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op = 'UPDATE' and new.display_name is distinct from old.display_name then
    if not app.persona_name_ok(new.display_name)
      or app.persona_text_blocked(new.display_name)
      or app.persona_text_has_real_name(new.institute_id, new.display_name, 3)
    then
      raise exception 'this pen name is not allowed' using errcode = 'check_violation';
    end if;
    if new.display_name_changed_at is not distinct from old.display_name_changed_at then
      new.display_name_changed_at := now();
    end if;
  end if;
  if tg_op = 'UPDATE' and new.bio is distinct from old.bio and new.bio is not null and (
    app.persona_text_blocked(new.bio)
    or app.persona_text_has_real_name(new.institute_id, new.bio, 4)
  ) then
    raise exception 'this bio is not allowed' using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger personas_profile_guard before update on app.personas
for each row execute function app.personas_profile_guard();
--> statement-breakpoint
-- Keeps every past pen name (07 §4.2). After the row exists, so the history
-- key can point at it. Runs as the owner whoever updated the persona.
create function app.persona_names_record() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op = 'INSERT' or new.display_name is distinct from old.display_name then
    if tg_op = 'UPDATE' then
      update app.persona_names set ended_at = now()
      where institute_id = new.institute_id and persona_id = new.id and ended_at is null;
    end if;
    insert into app.persona_names (institute_id, persona_id, display_name, started_at)
    values (new.institute_id, new.id, new.display_name, coalesce(new.created_at, now()));
  end if;
  return null;
end
$function$;
--> statement-breakpoint
create trigger persona_names_record after insert or update of display_name on app.personas
for each row execute function app.persona_names_record();
--> statement-breakpoint
-- A student who has left posts only in the alumni class or the madrasa
-- (REQ-STU-009). Public posts that started there may still be published.
create or replace function app.hub_author_rules(p_institute_id uuid, p_scope text, p_class_id uuid,
  p_author_persona_id uuid, p_author_user_id uuid) returns void
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if p_scope = 'community' and not exists (select from app.institute_settings s
    where s.institute_id = p_institute_id and s.community_enabled)
  then
    raise exception 'the community scope is reserved' using errcode = 'check_violation';
  end if;
  if p_class_id is not null and exists (select from app.classes c
    where c.institute_id = p_institute_id and c.id = p_class_id and c.archived_at is not null)
  then
    raise exception 'an archived class is read-only' using errcode = 'object_not_in_prerequisite_state';
  end if;
  if p_author_user_id is not null and exists (select from app.user_roles r
    where r.institute_id = p_institute_id and r.user_id = p_author_user_id and r.role = 'student')
  then
    raise exception 'a student posts as their persona' using errcode = 'check_violation';
  end if;
  if p_author_persona_id is not null and not exists (select from app.personas p
    where p.institute_id = p_institute_id and p.id = p_author_persona_id and p.is_active)
  then
    raise exception 'this persona cannot post' using errcode = 'check_violation';
  end if;
  if p_author_persona_id is not null and exists (
    select from app.persona_links l
    join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
    where l.institute_id = p_institute_id and l.persona_id = p_author_persona_id and u.status = 'left'
  ) and p_scope <> 'madrasa' and p_class_id is not null and not exists (
    select from app.classes c
    where c.institute_id = p_institute_id and c.id = p_class_id and c.kind = 'alumni'
  ) and p_scope <> 'public'
  then
    raise exception 'a student who has left posts in the alumni class or the madrasa'
      using errcode = 'insufficient_privilege';
  end if;
end
$function$;
--> statement-breakpoint
-- One alumni class per institute (07 §4.5). The admin who first marks a
-- student as left creates it.
create function app.ensure_alumni_class() returns uuid
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  existing uuid;
  created uuid;
begin
  select c.id into existing from app.classes c
  where c.institute_id = tenant and c.kind = 'alumni';
  if existing is not null then
    return existing;
  end if;
  insert into app.classes (institute_id, name, created_by, kind)
  values (tenant, '{"ur":"سابق طلبہ","en":"Alumni"}'::jsonb, app.current_user_id(), 'alumni')
  returning id into created;
  return created;
end
$function$;
--> statement-breakpoint
-- Teachers who accept an invitation still need the short walkthrough.
-- Editors and finance officers do not (02 §13).
create or replace function identity.accept_staff_invitation(invitation_hash text, password_hash text)
returns boolean
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  staff_id uuid;
  teacher boolean;
begin
  if password_hash is null or length(password_hash) not between 64 and 255 then return false; end if;

  select u.id into staff_id from identity.staff_invitations i
  join app.users u on (u.institute_id, u.id) = (i.institute_id, i.user_id)
  where i.institute_id = tenant and i.token_hash = invitation_hash
    and i.expires_at > now() and u.status = 'invited'
    and exists (
      select 1 from app.user_roles r where r.institute_id = tenant and r.user_id = u.id
        and r.role in ('teacher', 'editor', 'finance_officer')
    )
  for update of u;
  if staff_id is null then return false; end if;

  delete from identity.staff_invitations
  where institute_id = tenant and user_id = staff_id
    and token_hash = invitation_hash and expires_at > clock_timestamp();
  if not found then return false; end if;

  select exists (
    select from app.user_roles r
    where r.institute_id = tenant and r.user_id = staff_id and r.role = 'teacher'
  ) into teacher;
  insert into identity.accounts (institute_id, user_id, provider_id, account_id, password)
  values (tenant, staff_id, 'credential', staff_id::text, password_hash);
  update app.users
  set status = 'active', must_change_password = false,
    onboarded_at = case when teacher then null else now() end,
    updated_at = now()
  where institute_id = tenant and id = staff_id;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, action, entity_table, entity_id)
  values (tenant, staff_id, 'user', 'staff.invitation.accepted', 'users', staff_id::text);
  return true;
end
$function$;
--> statement-breakpoint
create or replace function identity.save_onboarding(
  p_session uuid, p_command text, p_step int, p_value text, p_avatar smallint
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  student boolean;
  steps int;
  persona uuid;
  current_step int;
  skipped text[];
  cleaned text;
  bio_language text;
  room_id uuid;
  thread_id uuid;
  post_language text;
begin
  if not identity.is_hub_session(p_session) then
    return jsonb_build_object('code', 'denied');
  end if;
  student := app.has_role('student') and not app.has_role('teacher') and not app.has_role('admin');
  if not student and not app.has_role('teacher') then
    return jsonb_build_object('code', 'denied');
  end if;
  steps := case when student then 8 else 4 end;
  select u.onboarding_step, u.onboarding_skipped, l.persona_id
    into current_step, skipped, persona
  from app.users u
  left join app.persona_links l on l.institute_id = u.institute_id and l.user_id = u.id
  where u.institute_id = tenant and u.id = actor
  for update of u;
  if p_command = 'replay' then
    update app.users set onboarded_at = null, onboarding_step = 1, onboarding_skipped = '{}'
    where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok', 'step', 1, 'onboarded', false);
  end if;
  if p_command = 'back' then
    update app.users set onboarding_step = greatest(1, current_step - 1)
    where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok', 'step', greatest(1, current_step - 1));
  end if;
  if p_command = 'suggest' and student then
    return jsonb_build_object('code', 'ok', 'names', jsonb_build_array(
      app.generate_persona_name(tenant), app.generate_persona_name(tenant), app.generate_persona_name(tenant)));
  end if;
  if p_step is null or p_step <> current_step or p_step > steps then
    return jsonb_build_object('code', 'invalid');
  end if;

  if p_command = 'language' then
    if p_value not in ('ur', 'en') then return jsonb_build_object('code', 'invalid'); end if;
    update app.users set preferred_language = p_value, onboarding_step = least(steps, 2)
    where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok', 'step', least(steps, 2));
  end if;

  if p_command = 'name' and student then
    cleaned := btrim(p_value);
    if cleaned is null or cleaned = '' then
      return jsonb_build_object('code', 'rejected');
    end if;
    if exists (
      select from app.personas
      where institute_id = tenant and id = persona
        and lower(display_name) is distinct from lower(cleaned)
        and display_name_changed_at > now() - interval '30 days'
    ) then
      return jsonb_build_object('code', 'too_soon');
    end if;
    begin
      update app.personas set display_name = cleaned, reset_note = null
      where institute_id = tenant and id = persona;
    exception
      when check_violation then
        return jsonb_build_object('code', case when sqlerrm like '%30 days%' then 'too_soon' else 'rejected' end);
      when unique_violation then return jsonb_build_object('code', 'taken');
    end;
    update app.users set onboarding_step = 3, onboarding_skipped = array_remove(skipped, 'name')
    where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok', 'step', 3);
  end if;

  if p_command = 'avatar' and student then
    if p_avatar is null or p_avatar not between 1 and 24 then
      return jsonb_build_object('code', 'invalid');
    end if;
    update app.personas set avatar_preset = p_avatar where institute_id = tenant and id = persona;
    update app.users set onboarding_step = 4, onboarding_skipped = array_remove(skipped, 'avatar')
    where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok', 'step', 4);
  end if;

  if p_command = 'bio' and student then
    bio_language := case when p_value like 'en:%' then 'en' when p_value like 'ur:%' then 'ur' else null end;
    cleaned := nullif(btrim(case when bio_language is null then p_value else substr(p_value, 4) end), '');
    if bio_language is null and cleaned is not null then
      return jsonb_build_object('code', 'invalid');
    end if;
    begin
      update app.personas set bio = cleaned,
        bio_language = case when cleaned is null then null else bio_language end
      where institute_id = tenant and id = persona;
    exception when check_violation then
      return jsonb_build_object('code', 'rejected');
    end;
    update app.users set onboarding_step = 5, onboarding_skipped = array_remove(skipped, 'bio')
    where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok', 'step', 5);
  end if;

  if p_command = 'post' and student then
    post_language := case when p_avatar = 1 then 'en' else 'ur' end;
    cleaned := btrim(p_value);
    if cleaned is null or length(cleaned) not between 1 and 1000 then
      return jsonb_build_object('code', 'invalid');
    end if;
    if app.has_contact_details(cleaned) or cleaned ~* 'https?://|\ywww\.' then
      return jsonb_build_object('code', 'contact_details');
    end if;
    select m.class_id into room_id from app.class_members m
    join app.classes c on c.institute_id = m.institute_id and c.id = m.class_id
    where m.institute_id = tenant and m.user_id = actor and m.member_role = 'student'
      and m.ended_at is null and c.archived_at is null
    order by c.kind, m.joined_at
    limit 1;
    if room_id is null then return jsonb_build_object('code', 'no_class'); end if;
    insert into app.threads (institute_id, class_id, scope, language, author_persona_id)
    values (tenant, room_id, 'class', post_language, persona)
    returning id into thread_id;
    insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id)
    values (tenant, thread_id, 'message', post_language, cleaned, persona);
    update app.users set onboarding_step = 8 where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok', 'step', 8, 'thread_id', thread_id);
  end if;

  if p_command = 'skip' then
    skipped := case p_step
      when 2 then skipped || array['name']
      when 3 then skipped || array['avatar']
      when 4 then skipped || array['bio']
      else skipped
    end;
    update app.users set
      onboarding_skipped = (select coalesce(array_agg(distinct item), '{}') from unnest(skipped) item),
      onboarding_step = case when p_step >= steps then p_step else p_step + 1 end,
      onboarded_at = case when p_step >= steps then now() else onboarded_at end
    where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok', 'step', case when p_step >= steps then p_step else p_step + 1 end,
      'onboarded', p_step >= steps);
  end if;

  if p_command in ('next', 'finish') then
    update app.users set
      onboarding_step = case when p_command = 'finish' or p_step >= steps then steps else p_step + 1 end,
      onboarded_at = case when p_command = 'finish' or p_step >= steps then coalesce(onboarded_at, now()) else onboarded_at end
    where institute_id = tenant and id = actor;
    return jsonb_build_object('code', 'ok',
      'step', case when p_command = 'finish' or p_step >= steps then steps else p_step + 1 end,
      'onboarded', p_command = 'finish' or p_step >= steps);
  end if;
  return jsonb_build_object('code', 'invalid');
end
$function$;
--> statement-breakpoint
create function identity.update_persona(
  p_session uuid, p_name text, p_avatar smallint, p_bio text, p_language text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  persona uuid := app.current_persona_id();
  cleaned_name text := nullif(btrim(p_name), '');
  cleaned_bio text := nullif(btrim(p_bio), '');
begin
  if not identity.is_hub_session(p_session) or persona is null then return 'denied'; end if;
  if p_language not in ('ur', 'en') then return 'invalid'; end if;
  if p_avatar is not null and p_avatar not between 1 and 24 then return 'invalid'; end if;
  if cleaned_name is not null and exists (
    select from app.personas
    where institute_id = tenant and id = persona
      and lower(display_name) is distinct from lower(cleaned_name)
      and display_name_changed_at > now() - interval '30 days'
  ) then
    return 'too_soon';
  end if;
  if cleaned_bio is not null and length(cleaned_bio) > 160 then return 'invalid'; end if;
  begin
    update app.personas set
      display_name = coalesce(cleaned_name, display_name),
      avatar_preset = coalesce(p_avatar, avatar_preset),
      bio = case when p_bio is null then bio else cleaned_bio end,
      bio_language = case when p_bio is null then bio_language when cleaned_bio is null then null else p_language end,
      reset_note = case when cleaned_name is null then reset_note else null end
    where institute_id = tenant and id = persona;
  exception
    when check_violation then
      return case when sqlerrm like '%30 days%' then 'too_soon' else 'rejected' end;
    when unique_violation then return 'taken';
  end;
  return 'saved';
end
$function$;
--> statement-breakpoint
create function identity.reset_persona(p_session uuid, p_student uuid) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  persona uuid;
begin
  if not identity.staff_session_ok(p_session) then return 'denied'; end if;
  if not (app.has_role('admin') or app.is_teacher_of(p_student)) then return 'denied'; end if;
  select l.persona_id into persona from app.persona_links l
  where l.institute_id = tenant and l.user_id = p_student;
  if persona is null then return 'not_found'; end if;
  update app.personas set display_name = app.generate_persona_name(tenant),
    display_name_changed_at = null, reset_note = 'reset'
  where institute_id = tenant and id = persona;
  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, reason)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'personas.reset_name', 'personas', persona::text, 'reset'
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return 'reset';
end
$function$;
--> statement-breakpoint
create function identity.mark_student_left(p_session uuid, p_student uuid) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  alumni uuid;
begin
  if not identity.staff_session_ok(p_session) or not app.has_role('admin') then
    return 'denied';
  end if;
  if p_student is null or not exists (
    select from app.user_roles r
    join app.users u on u.institute_id = r.institute_id and u.id = r.user_id
    where r.institute_id = tenant and r.user_id = p_student and r.role = 'student' and u.status = 'active'
  ) then
    if exists (
      select from app.users u where u.institute_id = tenant and u.id = p_student and u.status = 'left'
    ) then return 'already_left'; end if;
    return 'not_found';
  end if;
  update app.users set status = 'left', left_at = current_date where institute_id = tenant and id = p_student;
  update app.class_members set ended_at = current_date
  where institute_id = tenant and user_id = p_student and member_role = 'student' and ended_at is null;
  alumni := app.ensure_alumni_class();
  insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
  values (tenant, alumni, p_student, 'student', actor);
  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, reason)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'students.left', 'users', p_student::text, 'alumni'
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return 'left';
end
$function$;
--> statement-breakpoint
-- Admin home checklist (02 §13). Each item is true only when the institute
-- already has that record. Nothing here invents a phone number or a bank.
create function identity.admin_setup_checklist(p_session uuid) returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  settings app.institute_settings;
begin
  if not identity.is_hub_session(p_session) or not app.has_role('admin') then
    return jsonb_build_object('code', 'denied');
  end if;
  select * into settings from app.institute_settings s where s.institute_id = tenant;
  return jsonb_build_object('code', 'ok', 'items', jsonb_build_array(
    jsonb_build_object('id', 'name', 'done', settings.name is not null),
    jsonb_build_object('id', 'logo', 'done', settings.logo_media_id is not null),
    jsonb_build_object('id', 'bank', 'done', exists (
      select from app.institute_bank_accounts b where b.institute_id = tenant and b.is_active)),
    jsonb_build_object('id', 'contact', 'done',
      coalesce(settings.contact->>'phone', '') <> '' or coalesce(settings.contact->>'email', '') <> ''),
    jsonb_build_object('id', 'cause', 'done', exists (
      select from app.causes c where c.institute_id = tenant)),
    jsonb_build_object('id', 'teacher', 'done', exists (
      select from app.user_roles r where r.institute_id = tenant and r.role = 'teacher'))
  ));
end
$function$;
--> statement-breakpoint
revoke all on function app.persona_text_blocked(text), app.persona_text_has_real_name(uuid, text, int),
  app.classes_kind_guard(), app.personas_profile_guard(), app.persona_names_record(), app.ensure_alumni_class(),
  identity.save_onboarding(uuid, text, int, text, smallint),
  identity.update_persona(uuid, text, smallint, text, text),
  identity.reset_persona(uuid, uuid), identity.mark_student_left(uuid, uuid),
  identity.admin_setup_checklist(uuid) from public;
--> statement-breakpoint
grant execute on function identity.save_onboarding(uuid, text, int, text, smallint),
  identity.update_persona(uuid, text, smallint, text, text),
  identity.admin_setup_checklist(uuid) to tazkiyah_auth;
--> statement-breakpoint
grant execute on function identity.reset_persona(uuid, uuid),
  identity.mark_student_left(uuid, uuid) to tazkiyah_auth;
--> statement-breakpoint
create or replace function identity.class_workspace(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  is_admin boolean := app.has_role('admin');
begin
  if not identity.staff_session_ok(p_session_id)
    or not (is_admin or app.has_role('teacher'))
  then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'is_admin', is_admin,
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'year_label', c.year_label,
        'kind', c.kind,
        'archived', c.archived_at is not null,
        'manage_students', is_admin or app.is_class_teacher(c.id),
        'manage_teachers', is_admin,
        'teachers', coalesce((
          select jsonb_agg(jsonb_build_object('user_id', u.id, 'name', u.full_name)
            order by u.full_name)
          from app.class_members m
          join app.users u on u.institute_id = m.institute_id and u.id = m.user_id
          where m.institute_id = tenant and m.class_id = c.id
            and m.member_role = 'teacher' and m.ended_at is null
        ), '[]'::jsonb),
        'students', coalesce((
          select jsonb_agg(jsonb_build_object(
            'user_id', u.id,
            'persona', p.display_name,
            'status', u.status,
            'real_name', case when is_admin or app.is_class_teacher(c.id) then u.full_name end
          ) order by p.display_name)
          from app.class_members m
          join app.users u on u.institute_id = m.institute_id and u.id = m.user_id
          left join app.persona_links l on l.institute_id = u.institute_id and l.user_id = u.id
          left join app.personas p on p.institute_id = l.institute_id and p.id = l.persona_id
          where m.institute_id = tenant and m.class_id = c.id
            and m.member_role = 'student' and m.ended_at is null
        ), '[]'::jsonb)
      ) order by c.created_at, c.id)
      from app.classes c
      where c.institute_id = tenant
        and (is_admin or app.is_class_teacher(c.id) or c.created_by = actor)
    ), '[]'::jsonb),
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', u.id,
        'persona', p.display_name,
        'real_name', case when is_admin or app.is_teacher_of(u.id) then u.full_name end,
        'class_ids', coalesce((
          select jsonb_agg(m.class_id) from app.class_members m
          where m.institute_id = tenant and m.user_id = u.id
            and m.member_role = 'student' and m.ended_at is null
        ), '[]'::jsonb)
      ) order by p.display_name)
      from app.users u
      join app.user_roles r on r.institute_id = u.institute_id and r.user_id = u.id and r.role = 'student'
      left join app.persona_links l on l.institute_id = u.institute_id and l.user_id = u.id
      left join app.personas p on p.institute_id = l.institute_id and p.id = l.persona_id
      where u.institute_id = tenant and u.status = 'active'
        and (is_admin or app.is_teacher_of(u.id))
    ), '[]'::jsonb),
    'teachers', case when is_admin then coalesce((
      select jsonb_agg(jsonb_build_object('user_id', u.id, 'name', u.full_name) order by u.full_name)
      from app.users u
      join app.user_roles r on r.institute_id = u.institute_id and r.user_id = u.id and r.role = 'teacher'
      where u.institute_id = tenant and u.status = 'active'
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end
$function$;
--> statement-breakpoint
RESET ROLE;
