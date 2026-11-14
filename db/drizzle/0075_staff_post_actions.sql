SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Hide, remove, takedown, restore and the public-state list (REQ-MOD-002,
-- REQ-CHS-004, REQ-MOD-004). Removal is a takedown: that is the transition
-- the moderation trigger allows, and it is what hides a post from its author
-- (D-169). Scope widening is still an approval of a madrasa request, plus the
-- admin's list of chosen teachers (REQ-MOD-007). Choosing a teacher changes
-- a flag on the role they already hold, so it does not end their session.
create or replace function identity.revoke_user_sessions() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_table_schema = 'app' and tg_table_name = 'users' then
    delete from identity.sessions
      where institute_id = new.institute_id and user_id = new.id;
  else
    if tg_op = 'DELETE' or (
      tg_op = 'UPDATE' and (new.institute_id, new.user_id, new.role)
        is distinct from (old.institute_id, old.user_id, old.role)
    ) then
      delete from identity.sessions
        where institute_id = old.institute_id and user_id = old.user_id;
    end if;
    if tg_op = 'INSERT' or (
      tg_op = 'UPDATE' and (new.institute_id, new.user_id)
        is distinct from (old.institute_id, old.user_id)
    ) then
      delete from identity.sessions
        where institute_id = new.institute_id and user_id = new.user_id;
    end if;
  end if;
  return null;
end
$function$;
--> statement-breakpoint
create function identity.moderation_board(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  is_admin boolean := app.has_role('admin');
  is_editor boolean := app.has_role('editor');
begin
  if not identity.staff_session_ok(p_session_id)
    or not (is_admin or app.has_role('teacher') or is_editor)
  then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'is_admin', is_admin,
    'can_widen', is_admin or app.can_widen_scope(),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'title', p.title,
        'body', left(p.body, 280),
        'language', p.language,
        'scope', p.scope,
        'target_scope', p.target_scope,
        'state', p.moderation_state,
        'hidden', p.hidden_at is not null,
        'persona', persona.display_name,
        'class_name', room.name,
        'real_name', case
          when student.user_id is not null and (is_admin or app.is_teacher_of(student.user_id))
          then student.full_name end,
        'shows_face', exists (
          select from app.post_media pm
          join app.media_assets m on m.institute_id = pm.institute_id and m.id = pm.media_asset_id
          where pm.institute_id = p.institute_id and pm.post_id = p.id and m.shows_face
            and m.status <> 'deleted'
        ),
        'needs_public_consent', student.user_id is not null and p.target_scope = 'public',
        'public_consent', student.user_id is not null and app.consent_active(student.user_id, 'public_work'),
        'face_consent', student.user_id is not null and app.consent_active(student.user_id, 'face'),
        'can_approve', app.may_approve_post(p, student.user_id)
      ) order by p.submitted_at, p.id)
      from app.posts p
      left join lateral (
        select l.user_id, u.full_name from app.persona_links l
        join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
        where l.institute_id = p.institute_id and l.persona_id = p.author_persona_id
      ) student on true
      left join app.personas persona on persona.institute_id = p.institute_id and persona.id = p.author_persona_id
      left join app.classes room on room.institute_id = p.institute_id and room.id = p.class_id
      where p.institute_id = tenant and p.moderation_state = 'submitted'
        and app.may_approve_post(p, student.user_id)
    ), '[]'::jsonb),
    'posts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'title', p.title,
        'body', left(p.body, 280),
        'scope', p.scope,
        'state', p.moderation_state,
        'hidden', p.hidden_at is not null,
        'persona', persona.display_name,
        'class_name', room.name,
        'reason', p.hidden_reason,
        'can_hide', p.hidden_at is null and p.moderation_state <> 'taken_down'
          and (is_admin or app.has_role('teacher')),
        'can_unhide', p.hidden_at is not null and p.moderation_state <> 'taken_down'
          and (is_admin or (p.class_id is not null and app.has_role('teacher') and app.is_class_teacher(p.class_id))),
        'can_remove', p.moderation_state <> 'taken_down' and p.scope in ('class', 'madrasa')
          and (is_admin or app.has_role('teacher')),
        'can_takedown', false
      ) order by p.created_at desc, p.id)
      from (
        select * from app.posts
        where institute_id = tenant and moderation_state <> 'taken_down'
          and scope in ('class', 'madrasa')
          and (
            is_admin
            or (app.has_role('teacher') and (
              scope = 'madrasa' or (class_id is not null and app.is_class_teacher(class_id))
            ))
          )
        order by created_at desc, id desc
        limit 40
      ) p
      left join app.personas persona on persona.institute_id = p.institute_id and persona.id = p.author_persona_id
      left join app.classes room on room.institute_id = p.institute_id and room.id = p.class_id
    ), '[]'::jsonb),
    'public_posts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'title', p.title,
        'body', left(p.body, 280),
        'scope', p.scope,
        'state', p.moderation_state,
        'hidden', p.hidden_at is not null,
        'persona', persona.display_name,
        'can_takedown', p.moderation_state <> 'taken_down' and (is_admin or app.has_role('teacher')),
        'can_hide', false,
        'can_remove', false
      ) order by p.published_at desc nulls last, p.id)
      from (
        select * from app.posts
        where institute_id = tenant and scope = 'public' and moderation_state = 'published'
          and (
            is_admin
            or (app.has_role('teacher') and (
              class_id is null or app.is_class_teacher(class_id)
            ))
          )
        order by published_at desc nulls last, id desc
        limit 40
      ) p
      left join app.personas persona on persona.institute_id = p.institute_id and persona.id = p.author_persona_id
    ), '[]'::jsonb),
    'taken_down', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'title', p.title,
        'body', left(p.body, 280),
        'scope', p.scope,
        'state', p.moderation_state,
        'reason', p.takedown_reason,
        'persona', persona.display_name,
        'can_restore', is_admin
      ) order by p.taken_down_at desc, p.id)
      from (
        select * from app.posts
        where institute_id = tenant and moderation_state = 'taken_down'
          and (
            is_admin
            or (app.has_role('teacher') and (
              scope = 'madrasa' or scope = 'public'
              or (class_id is not null and app.is_class_teacher(class_id))
            ))
            or (is_editor and author_user_id is not null)
          )
        order by taken_down_at desc nulls last, id desc
        limit 40
      ) p
      left join app.personas persona on persona.institute_id = p.institute_id and persona.id = p.author_persona_id
    ), '[]'::jsonb),
    'wideners', case when is_admin then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', u.id, 'name', u.full_name, 'can_widen', r.can_widen_scope
      ) order by u.full_name, u.id)
      from app.user_roles r
      join app.users u on u.institute_id = r.institute_id and u.id = r.user_id
      where r.institute_id = tenant and r.role = 'teacher' and u.status = 'active'
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end
$function$;
--> statement-breakpoint
create function identity.moderate_post(
  p_session_id uuid, p_post_id uuid, p_action text, p_reason text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  post app.posts%rowtype;
  reason text := nullif(btrim(p_reason), '');
  is_admin boolean := app.has_role('admin');
  may_touch boolean;
begin
  if not identity.staff_session_ok(p_session_id) then return 'denied'; end if;
  if p_post_id is null or p_action not in ('hide', 'unhide', 'remove', 'takedown', 'restore')
    or (reason is not null and (length(reason) > 500 or reason ~ '[[:cntrl:]]'))
    or (p_action in ('hide', 'remove', 'takedown') and reason is null)
  then
    return 'invalid';
  end if;
  select * into post from app.posts
  where institute_id = tenant and id = p_post_id
  for update;
  if not found then return 'not_found'; end if;
  may_touch := is_admin or (
    app.has_role('teacher') and post.scope <> 'community'
    and (post.class_id is null or post.scope = 'madrasa' or app.is_class_teacher(post.class_id))
  );
  if p_action = 'takedown' and post.scope = 'public' and not may_touch and not is_admin then
    return 'denied';
  end if;
  if not may_touch and not (p_action = 'restore' and is_admin) then
    return 'denied';
  end if;
  begin
    if p_action = 'hide' then
      if post.moderation_state = 'taken_down' or post.hidden_at is not null then return 'blocked'; end if;
      update app.posts set hidden_at = clock_timestamp(), hidden_reason = reason
      where institute_id = tenant and id = post.id;
    elsif p_action = 'unhide' then
      if post.hidden_at is null or post.moderation_state = 'taken_down' then return 'blocked'; end if;
      update app.posts set hidden_at = null
      where institute_id = tenant and id = post.id;
    elsif p_action in ('remove', 'takedown') then
      if post.moderation_state = 'taken_down' then return 'blocked'; end if;
      if p_action = 'remove' and post.scope not in ('class', 'madrasa') then return 'invalid'; end if;
      update app.posts set moderation_state = 'taken_down', takedown_reason = reason
      where institute_id = tenant and id = post.id;
    else
      if post.moderation_state <> 'taken_down' then return 'not_waiting'; end if;
      if post.scope = 'public' then
        update app.posts set moderation_state = 'submitted', hidden_at = null
        where institute_id = tenant and id = post.id;
      else
        update app.posts set moderation_state = 'published', hidden_at = null
        where institute_id = tenant and id = post.id;
      end if;
    end if;
  exception
    when insufficient_privilege then return 'denied';
    when object_not_in_prerequisite_state then return 'blocked';
    when check_violation then return 'invalid';
  end;
  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, reason, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'posts.' || p_action, 'posts', post.id::text, reason,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return p_action;
end
$function$;
--> statement-breakpoint
create function identity.set_scope_widener(p_session_id uuid, p_teacher_id uuid, p_enabled boolean)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
begin
  if not identity.staff_session_ok(p_session_id) or not app.has_role('admin') then
    return 'denied';
  end if;
  if p_teacher_id is null or p_enabled is null or p_teacher_id = actor then
    return 'invalid';
  end if;
  update app.user_roles set can_widen_scope = p_enabled
  where institute_id = tenant and user_id = p_teacher_id and role = 'teacher';
  if not found then return 'not_teacher'; end if;
  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, reason, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'roles.scope_widener', 'user_roles', p_teacher_id::text,
    case when p_enabled then 'on' else 'off' end,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return 'saved';
end
$function$;
--> statement-breakpoint
revoke all on function identity.moderation_board(uuid),
  identity.moderate_post(uuid, uuid, text, text),
  identity.set_scope_widener(uuid, uuid, boolean) from public;
--> statement-breakpoint
grant execute on function identity.moderation_board(uuid),
  identity.moderate_post(uuid, uuid, text, text),
  identity.set_scope_widener(uuid, uuid, boolean) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
