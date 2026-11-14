SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The stored guardian list gains the principal, who is the guardian for the
-- orphans (07 §5.1). A paper scan still needs private storage, so the form
-- leaves form_media_id empty (D-165).
ALTER TABLE "app"."consent_records" DROP CONSTRAINT "consent_records_guardian_check";
--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_guardian_check" CHECK (length(guardian_name) between 1 and 120 and guardian_name = btrim(guardian_name)
          and guardian_relation in ('father', 'mother', 'guardian', 'other', 'principal'));
--> statement-breakpoint
-- Staff consent form (07 §5, REQ-CHS-006). Teachers see their own students.
-- The assigned second signer sees that record even when they do not teach
-- the student. The principal also sees the teachers they may assign.
create function identity.consent_workspace(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  is_admin boolean := app.has_role('admin');
  is_principal boolean := is_admin and exists (
    select from app.institute_settings s
    where s.institute_id = tenant and s.principal_user_id = actor);
begin
  if not identity.staff_session_ok(p_session_id) or not (is_admin or app.has_role('teacher')) then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'is_principal', is_principal,
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', u.id,
        'real_name', u.full_name,
        'persona', p.display_name,
        'is_orphan', u.is_orphan
      ) order by u.full_name, u.id)
      from app.users u
      join app.user_roles r on r.institute_id = u.institute_id and r.user_id = u.id and r.role = 'student'
      left join app.persona_links l on l.institute_id = u.institute_id and l.user_id = u.id
      left join app.personas p on p.institute_id = l.institute_id and p.id = l.persona_id
      where u.institute_id = tenant and u.status in ('active', 'left')
        and (is_admin or app.is_teacher_of(u.id))
    ), '[]'::jsonb),
    'teachers', case when is_principal then coalesce((
      select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.full_name) order by u.full_name, u.id)
      from app.users u
      join app.user_roles r on r.institute_id = u.institute_id and r.user_id = u.id and r.role = 'teacher'
      where u.institute_id = tenant and u.status = 'active' and u.id <> actor
    ), '[]'::jsonb) else '[]'::jsonb end,
    'sponsorships', case when is_principal then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id,
        'student_id', u.id,
        'persona', p.display_name,
        'real_name', u.full_name
      ) order by p.display_name, s.id)
      from app.sponsorships s
      join app.personas p on p.institute_id = s.institute_id and p.id = s.child_persona_id
      join app.persona_links l on l.institute_id = p.institute_id and l.persona_id = p.id
      join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
      where s.institute_id = tenant and s.status = 'active'
    ), '[]'::jsonb) else '[]'::jsonb end,
    'records', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'student_id', c.student_user_id,
        'real_name', u.full_name,
        'persona', p.display_name,
        'kind', c.kind,
        'guardian_name', c.guardian_name,
        'relation', c.guardian_relation,
        'method', c.method,
        'given_on', to_char(c.given_on, 'YYYY-MM-DD'),
        'notes', c.notes,
        'sponsorship_id', c.sponsorship_id,
        'status', app.consent_status(c.id),
        'second_signer', signer.full_name,
        'can_sign_principal', is_principal and c.withdrawn_at is null and c.principal_signed_at is null
          and (c.kind = 'orphan_full_profile' or u.is_orphan),
        'can_sign_second', c.withdrawn_at is null and c.second_signed_at is null
          and c.second_signer_assigned = actor and app.has_role('teacher')
          and (c.kind = 'orphan_full_profile' or c.principal_signed_at is not null),
        'can_assign', is_principal and c.withdrawn_at is null and c.second_signed_at is null
          and (c.kind = 'orphan_full_profile' or u.is_orphan),
        'can_withdraw', c.withdrawn_at is null and (is_admin or app.is_teacher_of(c.student_user_id)
          or actor is not distinct from c.principal_signed_by
          or actor is not distinct from c.second_signer_assigned)
      ) order by c.recorded_at desc, c.id)
      from app.consent_records c
      join app.users u on u.institute_id = c.institute_id and u.id = c.student_user_id
      left join app.persona_links l on l.institute_id = u.institute_id and l.user_id = u.id
      left join app.personas p on p.institute_id = l.institute_id and p.id = l.persona_id
      left join app.users signer on signer.institute_id = c.institute_id and signer.id = c.second_signer_assigned
      where c.institute_id = tenant
        and (is_admin or app.is_teacher_of(c.student_user_id)
          or c.second_signer_assigned = actor)
    ), '[]'::jsonb)
  );
end
$function$;
--> statement-breakpoint
create function identity.record_consent(
  p_session_id uuid, p_student_id uuid, p_kind text, p_guardian text, p_relation text,
  p_method text, p_given_on date, p_notes text, p_sponsorship_id uuid
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  guardian text := btrim(p_guardian);
  notes text := nullif(btrim(p_notes), '');
  is_principal boolean := app.has_role('admin') and exists (
    select from app.institute_settings s
    where s.institute_id = tenant and s.principal_user_id = actor);
begin
  if not identity.staff_session_ok(p_session_id) then return 'denied'; end if;
  if p_student_id is null or p_kind not in ('public_work', 'real_name', 'face', 'orphan_full_profile')
    or p_relation not in ('father', 'mother', 'guardian', 'other', 'principal')
    or p_method not in ('paper_form', 'in_person', 'phone', 'other')
    or p_given_on is null or guardian is null or length(guardian) not between 1 and 120
    or guardian ~ '[[:cntrl:]]'
    or (notes is not null and (length(notes) > 1000 or notes ~ '[[:cntrl:]]'))
    or (p_kind = 'orphan_full_profile') <> (p_sponsorship_id is not null)
    or app.has_contact_details(guardian) or (notes is not null and app.has_contact_details(notes))
  then
    return 'invalid';
  end if;
  if p_kind = 'orphan_full_profile' then
    if not is_principal then return 'denied'; end if;
    if exists (
      select from app.consent_records c
      where c.institute_id = tenant and c.sponsorship_id = p_sponsorship_id
        and c.kind = 'orphan_full_profile' and c.withdrawn_at is null
    ) then
      return 'already';
    end if;
  elsif not (app.has_role('admin') or app.is_teacher_of(p_student_id)) then
    return 'denied';
  end if;
  begin
    insert into app.consent_records (
      institute_id, student_user_id, kind, guardian_name, guardian_relation, method,
      given_on, notes, recorded_by, sponsorship_id
    ) values (
      tenant, p_student_id, p_kind, guardian, p_relation, p_method,
      p_given_on, notes, actor, p_sponsorship_id
    );
  exception
    when insufficient_privilege then return 'denied';
    when check_violation then return 'invalid';
    when foreign_key_violation then return 'unavailable';
  end;
  return 'recorded';
end
$function$;
--> statement-breakpoint
create function identity.consent_action(
  p_session_id uuid, p_consent_id uuid, p_action text, p_teacher_id uuid, p_reason text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if not identity.staff_session_ok(p_session_id) then return 'denied'; end if;
  if p_consent_id is null or p_action not in ('sign', 'assign', 'withdraw') then
    return 'invalid';
  end if;
  if p_action = 'sign' then
    return app.sign_consent(p_consent_id);
  elsif p_action = 'assign' then
    return app.assign_second_signer(p_consent_id, p_teacher_id);
  end if;
  return app.withdraw_consent(p_consent_id, p_reason);
end
$function$;
--> statement-breakpoint
-- The sponsorship board gains the second sign-off and the staff inbox
-- (REQ-ORP-004, REQ-ORP-007). Only an admin opens it. Messages are marked
-- read for the madrasa when the inbox is opened. A child is never a party.
create or replace function identity.sponsorship_workspace(p_session_id uuid)
returns jsonb
language plpgsql volatile security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  is_principal boolean;
  unread integer;
begin
  if not identity.staff_session_ok(p_session_id) or not app.has_role('admin') then
    return jsonb_build_object('allowed', false);
  end if;
  is_principal := exists (
    select from app.institute_settings s
    where s.institute_id = tenant and s.principal_user_id = actor);
  select count(*) into unread from app.sponsor_messages m
  where m.institute_id = tenant and m.direction = 'to_madrasa' and m.read_at is null;
  update app.sponsor_messages set read_at = clock_timestamp()
  where institute_id = tenant and direction = 'to_madrasa' and read_at is null;
  return jsonb_build_object(
    'allowed', true,
    'is_principal', is_principal,
    'unread', unread,
    'matches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id,
        'persona', p.display_name,
        'real_name', u.full_name,
        'student_id', u.id,
        'status', s.status,
        'started_on', to_char(s.started_on, 'YYYY-MM-DD'),
        'sponsor', sponsor.full_name,
        'consent_id', consent.id,
        'consent_status', case when consent.id is not null then app.consent_status(consent.id) end,
        'second_signer', signer.full_name
      ) order by s.started_on desc, s.id)
      from app.sponsorships s
      join app.personas p on p.institute_id = s.institute_id and p.id = s.child_persona_id
      join app.persona_links l on l.institute_id = s.institute_id and l.persona_id = p.id
      join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
      join app.donors d on d.institute_id = s.institute_id and d.id = s.sponsor_donor_id
      left join app.users sponsor on sponsor.institute_id = d.institute_id and sponsor.id = d.user_id
      left join lateral (
        select c.id, c.second_signer_assigned from app.consent_records c
        where c.institute_id = s.institute_id and c.sponsorship_id = s.id
          and c.kind = 'orphan_full_profile'
        order by c.recorded_at desc, c.id desc
        limit 1
      ) consent on true
      left join app.users signer on signer.institute_id = s.institute_id
        and signer.id = consent.second_signer_assigned
      where s.institute_id = tenant and s.status <> 'ended'
    ), '[]'::jsonb),
    'orphans', coalesce((
      select jsonb_agg(jsonb_build_object(
        'persona_id', p.id,
        'persona', p.display_name,
        'real_name', u.full_name
      ) order by p.display_name)
      from app.personas p
      join app.persona_links l on l.institute_id = p.institute_id and l.persona_id = p.id
      join app.users u on u.institute_id = l.institute_id and u.id = l.user_id and u.is_orphan
      where p.institute_id = tenant
        and not exists (
          select from app.sponsorships s
          where s.institute_id = tenant and s.child_persona_id = p.id and s.status <> 'ended'
        )
    ), '[]'::jsonb),
    'sponsors', coalesce((
      select jsonb_agg(jsonb_build_object('id', d.id, 'name', u.full_name) order by u.full_name)
      from app.donors d
      join app.users u on u.institute_id = d.institute_id and u.id = d.user_id
      where d.institute_id = tenant and d.erased_at is null and u.status = 'active'
    ), '[]'::jsonb),
    'causes', coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title) order by c.display_order, c.slug)
      from app.causes c
      where c.institute_id = tenant and c.status = 'active'
    ), '[]'::jsonb),
    'teachers', case when is_principal then coalesce((
      select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.full_name) order by u.full_name)
      from app.users u
      join app.user_roles r on r.institute_id = u.institute_id and r.user_id = u.id and r.role = 'teacher'
      where u.institute_id = tenant and u.status = 'active' and u.id <> actor
    ), '[]'::jsonb) else '[]'::jsonb end,
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id,
        'sponsorship_id', m.sponsorship_id,
        'persona', p.display_name,
        'direction', m.direction,
        'body', m.body,
        'language', m.language,
        'created_at', m.created_at
      ) order by m.created_at, m.id)
      from (
        select * from app.sponsor_messages
        where institute_id = tenant
        order by created_at desc, id desc
        limit 80
      ) m
      join app.sponsorships s on s.institute_id = m.institute_id and s.id = m.sponsorship_id
      join app.personas p on p.institute_id = s.institute_id and p.id = s.child_persona_id
    ), '[]'::jsonb)
  );
end
$function$;
--> statement-breakpoint
create function identity.reply_sponsor_message(
  p_session_id uuid, p_sponsorship_id uuid, p_body text, p_language text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  message text := btrim(p_body);
begin
  if not identity.staff_session_ok(p_session_id) or not app.has_role('admin') then
    return 'denied';
  end if;
  if p_sponsorship_id is null or p_language not in ('ur', 'en')
    or message is null or length(message) not between 1 and 2000 or message ~ '[[:cntrl:]]'
  then
    return 'invalid';
  end if;
  if app.has_contact_details(message) then return 'contact_details'; end if;
  begin
    insert into app.sponsor_messages (
      institute_id, sponsorship_id, direction, body, language, sender_user_id
    ) values (
      tenant, p_sponsorship_id, 'to_sponsor', message, p_language, actor
    );
  exception
    when insufficient_privilege then return 'denied';
    when check_violation then return 'unavailable';
    when foreign_key_violation then return 'unavailable';
  end;
  return 'sent';
end
$function$;
--> statement-breakpoint
-- Progress updates are text in Urdu, English, or both. No photograph is
-- stored: private media addresses do not exist yet (D-146, D-168). An admin's
-- update is published by the existing trigger. A teacher's waits.
create function identity.progress_workspace(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  is_admin boolean := app.has_role('admin');
begin
  if not identity.staff_session_ok(p_session_id) or not (is_admin or app.has_role('teacher')) then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'is_admin', is_admin,
    'children', coalesce((
      select jsonb_agg(jsonb_build_object(
        'persona_id', p.id,
        'persona', p.display_name,
        'real_name', case when is_admin or app.teaches_persona(p.id) then u.full_name end
      ) order by p.display_name, p.id)
      from app.personas p
      join app.persona_links l on l.institute_id = p.institute_id and l.persona_id = p.id
      join app.users u on u.institute_id = l.institute_id and u.id = l.user_id and u.is_orphan
      where p.institute_id = tenant
        and (is_admin or app.teaches_persona(p.id))
        and exists (
          select from app.sponsorships s
          where s.institute_id = tenant and s.child_persona_id = p.id and s.status <> 'ended'
        )
    ), '[]'::jsonb),
    'updates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', su.id,
        'persona_id', su.child_persona_id,
        'persona', p.display_name,
        'body', su.body,
        'published', su.published_at is not null,
        'hidden', su.hidden_at is not null,
        'own', su.author_user_id = actor
      ) order by su.created_at desc, su.id)
      from (
        select * from app.sponsorship_updates
        where institute_id = tenant
        order by created_at desc, id desc
        limit 40
      ) su
      join app.personas p on p.institute_id = su.institute_id and p.id = su.child_persona_id
      where is_admin or app.teaches_persona(su.child_persona_id) or su.author_user_id = actor
    ), '[]'::jsonb)
  );
end
$function$;
--> statement-breakpoint
create function identity.write_progress_update(
  p_session_id uuid, p_persona_id uuid, p_ur text, p_en text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  urdu text := nullif(btrim(p_ur), '');
  english text := nullif(btrim(p_en), '');
  body jsonb := '{}'::jsonb;
  child_name text;
  is_admin boolean := app.has_role('admin');
begin
  if not identity.staff_session_ok(p_session_id) or not (is_admin or app.has_role('teacher')) then
    return 'denied';
  end if;
  if p_persona_id is null or (urdu is null and english is null)
    or (urdu is not null and (length(urdu) > 2000 or urdu ~ '[[:cntrl:]]'))
    or (english is not null and (length(english) > 2000 or english ~ '[[:cntrl:]]'))
  then
    return 'invalid';
  end if;
  if (urdu is not null and app.has_contact_details(urdu))
    or (english is not null and app.has_contact_details(english))
  then
    return 'contact_details';
  end if;
  if not (is_admin or app.teaches_persona(p_persona_id)) then return 'denied'; end if;
  if not exists (
    select from app.sponsorships s
    where s.institute_id = tenant and s.child_persona_id = p_persona_id and s.status <> 'ended'
  ) then
    return 'unavailable';
  end if;
  select u.full_name into child_name
  from app.persona_links l
  join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
  where l.institute_id = tenant and l.persona_id = p_persona_id;
  if child_name is not null and length(btrim(child_name)) >= 3 and (
    (urdu is not null and position(lower(btrim(child_name)) in lower(urdu)) > 0)
    or (english is not null and position(lower(btrim(child_name)) in lower(english)) > 0)
  ) then
    return 'real_name';
  end if;
  if urdu is not null then body := body || jsonb_build_object('ur', urdu); end if;
  if english is not null then body := body || jsonb_build_object('en', english); end if;
  begin
    insert into app.sponsorship_updates (institute_id, child_persona_id, body, author_user_id)
    values (tenant, p_persona_id, body, actor);
  exception
    when insufficient_privilege then return 'denied';
    when check_violation then return 'invalid';
    when foreign_key_violation then return 'unavailable';
  end;
  return case when is_admin then 'published' else 'waiting' end;
end
$function$;
--> statement-breakpoint
create function identity.progress_action(p_session_id uuid, p_update_id uuid, p_action text)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
begin
  if not identity.staff_session_ok(p_session_id) or not app.has_role('admin') then
    return 'denied';
  end if;
  if p_update_id is null or p_action not in ('publish', 'hide') then return 'invalid'; end if;
  begin
    if p_action = 'publish' then
      update app.sponsorship_updates set published_at = clock_timestamp()
      where institute_id = tenant and id = p_update_id and published_at is null and hidden_at is null;
    else
      update app.sponsorship_updates set hidden_at = clock_timestamp()
      where institute_id = tenant and id = p_update_id and hidden_at is null and published_at is not null;
    end if;
  exception
    when insufficient_privilege then return 'denied';
    when object_not_in_prerequisite_state then return 'blocked';
    when check_violation then return 'invalid';
  end;
  if not found then return 'not_found'; end if;
  return case when p_action = 'publish' then 'published' else 'hidden' end;
end
$function$;
--> statement-breakpoint
revoke all on function identity.consent_workspace(uuid),
  identity.record_consent(uuid, uuid, text, text, text, text, date, text, uuid),
  identity.consent_action(uuid, uuid, text, uuid, text),
  identity.reply_sponsor_message(uuid, uuid, text, text),
  identity.progress_workspace(uuid),
  identity.write_progress_update(uuid, uuid, text, text),
  identity.progress_action(uuid, uuid, text) from public;
--> statement-breakpoint
grant execute on function identity.consent_workspace(uuid),
  identity.record_consent(uuid, uuid, text, text, text, text, date, text, uuid),
  identity.consent_action(uuid, uuid, text, uuid, text),
  identity.reply_sponsor_message(uuid, uuid, text, text),
  identity.progress_workspace(uuid),
  identity.write_progress_update(uuid, uuid, text, text),
  identity.progress_action(uuid, uuid, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
