SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Classes for teachers and admins (07 §4, P3-E1-T06, P3-E1-T07, D-129).
-- A class teacher adds and ends student memberships only. Teacher memberships
-- are added and ended by an admin. Real names leave the function only for an
-- admin or a teacher of that student.
create function identity.class_workspace(p_session_id uuid)
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
create function identity.save_class(
  p_session_id uuid, p_class_id uuid, p_name jsonb, p_year_label text, p_archived boolean
) returns table (code text, class_id uuid)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  year_label text := nullif(btrim(p_year_label), '');
  saved uuid;
begin
  if not identity.staff_session_ok(p_session_id)
    or not (app.has_role('admin') or app.has_role('teacher'))
  then
    return query select 'denied'::text, null::uuid;
    return;
  end if;
  if p_name is null or not app.valid_localized_text(p_name)
    or exists (
      select from jsonb_each(p_name) as item(language, body)
      where language not in ('en', 'ur') or length(body #>> '{}') > 80
        or (body #>> '{}') ~ '[[:cntrl:]]'
    )
    or (year_label is not null and length(year_label) > 40)
    or p_archived is null
  then
    return query select 'invalid'::text, null::uuid;
    return;
  end if;
  if p_class_id is null then
    insert into app.classes as c (institute_id, name, year_label, created_by)
    values (tenant, p_name, year_label, actor)
    returning c.id into saved;
    return query select 'saved'::text, saved;
    return;
  end if;
  if not (app.has_role('admin') or app.is_class_teacher(p_class_id)) then
    return query select 'denied'::text, null::uuid;
    return;
  end if;
  update app.classes c set
    name = p_name,
    year_label = year_label,
    archived_at = case
      when p_archived and c.archived_at is null then now()
      when not p_archived then null
      else c.archived_at
    end
  where c.institute_id = tenant and c.id = p_class_id
  returning c.id into saved;
  if saved is null then
    return query select 'not_found'::text, null::uuid;
  else
    return query select 'saved'::text, saved;
  end if;
end
$function$;
--> statement-breakpoint
create function identity.set_class_member(
  p_session_id uuid, p_class_id uuid, p_user_id uuid, p_member_role text, p_action text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  is_admin boolean := app.has_role('admin');
begin
  if not identity.staff_session_ok(p_session_id) then
    return 'denied';
  end if;
  if p_class_id is null or p_user_id is null
    or p_member_role not in ('student', 'teacher')
    or p_action not in ('add', 'end')
  then
    return 'invalid';
  end if;
  -- D-129: a class teacher never grants another adult access to children.
  if p_member_role = 'teacher' and not is_admin then
    return 'denied';
  end if;
  if p_member_role = 'student' and not (is_admin or app.is_class_teacher(p_class_id)) then
    return 'denied';
  end if;
  if p_action = 'add' and exists (
    select from app.classes c
    where c.institute_id = tenant and c.id = p_class_id and c.archived_at is not null
  ) then
    return 'archived';
  end if;
  begin
    if p_action = 'add' then
      insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
      values (tenant, p_class_id, p_user_id, p_member_role, actor);
      return 'added';
    end if;
    update app.class_members set ended_at = (now() at time zone 'Asia/Karachi')::date
    where institute_id = tenant and class_id = p_class_id and user_id = p_user_id
      and member_role = p_member_role and ended_at is null;
    if not found then
      return 'not_found';
    end if;
    return 'ended';
  exception
    when unique_violation then return 'already_member';
    when check_violation then return 'unavailable';
  end;
end
$function$;
--> statement-breakpoint
revoke all on function identity.class_workspace(uuid),
  identity.save_class(uuid, uuid, jsonb, text, boolean),
  identity.set_class_member(uuid, uuid, uuid, text, text) from public;
--> statement-breakpoint
grant execute on function identity.class_workspace(uuid),
  identity.save_class(uuid, uuid, jsonb, text, boolean),
  identity.set_class_member(uuid, uuid, uuid, text, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
