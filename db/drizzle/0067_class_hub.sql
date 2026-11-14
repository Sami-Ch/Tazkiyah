SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- A student, teacher or admin session that may open the hub. Students sign in
-- with a username, so email verification is not required. An admin still
-- needs the staff session, including two-factor.
create function identity.is_hub_session(p_session uuid) returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return (app.has_role('student') or app.has_role('teacher') or app.has_role('admin'))
  and exists (
    select from identity.sessions s
    join app.users u on (u.institute_id, u.id) = (s.institute_id, s.user_id)
    where s.id = p_session and s.institute_id = app.current_institute_id()
      and s.user_id = app.current_user_id() and s.expires_at > now()
      and s.updated_at > now() - (identity.session_limits(u.id)).idle
      and not u.must_change_password and u.status in ('active', 'left')
      and (not app.has_role('admin') or identity.staff_session_ok(p_session))
  );
--> statement-breakpoint
create function identity.hub_can_see_class(p_class uuid) returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return app.has_role('admin') or app.is_class_member(p_class) or app.is_class_teacher(p_class);
--> statement-breakpoint
-- Classes, threads or one thread. Students see personas, never a classmate's
-- real name. Hidden and taken-down posts stay visible to the class teacher
-- and admins (REQ-CHS-003) and are marked so the page can say they are hidden.
create function identity.read_hub(
  p_session uuid, p_scope text, p_class uuid, p_thread uuid
) returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  staff boolean;
  thread_row app.threads;
begin
  if not identity.is_hub_session(p_session) then
    return jsonb_build_object('code', 'denied');
  end if;
  if app.has_role('student') and not app.has_role('teacher') and not app.has_role('admin')
    and not app.module_enabled('student_hub')
  then
    return jsonb_build_object('code', 'module_off');
  end if;
  if not app.has_role('student') and not app.module_enabled('student_hub')
    and not app.module_enabled('teacher_hub')
  then
    return jsonb_build_object('code', 'module_off');
  end if;

  staff := app.has_role('admin') or app.has_role('teacher');
  if p_thread is not null then
    select * into thread_row from app.threads t
    where t.institute_id = tenant and t.id = p_thread and t.scope in ('class', 'madrasa')
      and (t.scope = 'madrasa' or identity.hub_can_see_class(t.class_id));
    if thread_row.id is null then
      return jsonb_build_object('code', 'unavailable');
    end if;
    return jsonb_build_object(
      'code', 'ok',
      'thread', jsonb_build_object(
        'id', thread_row.id, 'title', thread_row.title, 'language', thread_row.language,
        'scope', thread_row.scope, 'class_id', thread_row.class_id,
        'locked', thread_row.locked_at is not null
      ),
      'posts', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', p.id, 'post_type', p.post_type, 'language', p.language,
          'title', p.title, 'body', p.body, 'created_at', p.created_at,
          'parent_post_id', p.parent_post_id,
          'author_name', coalesce(persona.display_name, author.full_name),
          'author_kind', case when p.author_persona_id is not null then 'persona' else 'staff' end,
          'hidden', p.hidden_at is not null or p.moderation_state = 'taken_down'
        ) order by p.created_at, p.id)
        from app.posts p
        left join app.personas persona on (persona.institute_id, persona.id) = (p.institute_id, p.author_persona_id)
        left join app.users author on p.author_persona_id is null
          and (author.institute_id, author.id) = (p.institute_id, p.author_user_id)
        where p.institute_id = tenant and p.thread_id = thread_row.id
          and p.scope <> 'community'
          and (
            (p.moderation_state = 'published' and p.hidden_at is null)
            or (staff and (app.has_role('admin') or thread_row.scope = 'madrasa'
              or app.is_class_teacher(thread_row.class_id)))
          )
      ), '[]'::jsonb)
    );
  end if;

  if p_scope = 'madrasa' or p_class is not null then
    if p_scope = 'class' and not identity.hub_can_see_class(p_class) then
      return jsonb_build_object('code', 'unavailable');
    end if;
    if p_scope not in ('class', 'madrasa') then
      return jsonb_build_object('code', 'invalid');
    end if;
    return jsonb_build_object('code', 'ok', 'threads', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'title', t.title, 'language', t.language, 'scope', t.scope,
        'reply_count', t.reply_count, 'last_post_at', t.last_post_at,
        'locked', t.locked_at is not null
      ) order by t.last_post_at desc, t.id)
      from app.threads t
      where t.institute_id = tenant and t.scope = p_scope
        and (p_scope = 'madrasa' or t.class_id = p_class)
    ), '[]'::jsonb));
  end if;

  return jsonb_build_object('code', 'ok', 'classes', coalesce((
    select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name) order by c.name->>'en', c.id)
    from app.classes c
    where c.institute_id = tenant and c.archived_at is null
      and identity.hub_can_see_class(c.id)
  ), '[]'::jsonb));
end
$function$;
--> statement-breakpoint
create function identity.start_hub_thread(
  p_session uuid, p_scope text, p_class uuid, p_post_type text,
  p_language text, p_title text, p_body text
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  persona uuid := app.current_persona_id();
  student boolean := app.has_role('student') and persona is not null
    and not app.has_role('teacher') and not app.has_role('admin');
  title text := nullif(btrim(p_title), '');
  body text := btrim(p_body);
  thread_id uuid;
begin
  if not identity.is_hub_session(p_session) then
    return jsonb_build_object('code', 'denied');
  end if;
  if p_scope not in ('class', 'madrasa') or p_post_type not in ('message', 'question')
    or p_language not in ('ur', 'en')
    or body is null or length(body) not between 1 and 4000
    or (title is not null and length(title) > 200)
    or (p_post_type = 'question' and title is null)
    or (p_scope = 'class' and p_class is null)
    or (p_scope = 'madrasa' and p_class is not null)
  then
    return jsonb_build_object('code', 'invalid');
  end if;
  if app.has_contact_details(coalesce(title, '') || ' ' || body) then
    return jsonb_build_object('code', 'contact_details');
  end if;
  if student and not app.module_enabled('student_hub') then
    return jsonb_build_object('code', 'module_off');
  end if;
  if not student and p_scope = 'madrasa' and not app.module_enabled('teacher_hub')
    and not app.has_role('admin')
  then
    return jsonb_build_object('code', 'module_off');
  end if;
  if p_scope = 'class' and not identity.hub_can_see_class(p_class) then
    return jsonb_build_object('code', 'unavailable');
  end if;
  if student and p_scope = 'class' and not app.is_class_member(p_class) then
    return jsonb_build_object('code', 'unavailable');
  end if;
  if not student and persona is null and not (app.has_role('teacher') or app.has_role('admin')) then
    return jsonb_build_object('code', 'denied');
  end if;

  insert into app.threads (
    institute_id, class_id, scope, title, language, author_persona_id, author_user_id
  ) values (
    tenant, case when p_scope = 'class' then p_class end, p_scope, title, p_language,
    case when student then persona end, case when student then null else actor end
  ) returning id into thread_id;
  insert into app.posts (
    institute_id, thread_id, post_type, language, title, body, scope,
    moderation_state, author_persona_id, author_user_id
  ) values (
    tenant, thread_id, p_post_type, p_language, title, body, p_scope, 'published',
    case when student then persona end, case when student then null else actor end
  );
  return jsonb_build_object('code', 'posted', 'thread_id', thread_id);
exception
  when check_violation or insufficient_privilege then
    return jsonb_build_object('code', 'unavailable');
end
$function$;
--> statement-breakpoint
create function identity.reply_hub_thread(
  p_session uuid, p_thread uuid, p_parent uuid, p_post_type text,
  p_language text, p_body text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  persona uuid := app.current_persona_id();
  student boolean := app.has_role('student') and persona is not null
    and not app.has_role('teacher') and not app.has_role('admin');
  body text := btrim(p_body);
  thread_row app.threads;
begin
  if not identity.is_hub_session(p_session) then return 'denied'; end if;
  if p_thread is null or p_post_type not in ('message', 'answer')
    or p_language not in ('ur', 'en')
    or body is null or length(body) not between 1 and 4000
  then
    return 'invalid';
  end if;
  if app.has_contact_details(body) then return 'contact_details'; end if;
  select * into thread_row from app.threads t
  where t.institute_id = tenant and t.id = p_thread and t.scope in ('class', 'madrasa')
    and (t.scope = 'madrasa' or identity.hub_can_see_class(t.class_id));
  if thread_row.id is null then return 'unavailable'; end if;
  if student and not app.module_enabled('student_hub') then return 'module_off'; end if;
  if student and thread_row.scope = 'class' and not app.is_class_member(thread_row.class_id) then
    return 'unavailable';
  end if;
  insert into app.posts (
    institute_id, thread_id, parent_post_id, post_type, language, body, scope,
    moderation_state, author_persona_id, author_user_id
  ) values (
    tenant, thread_row.id, p_parent, p_post_type, p_language, body, thread_row.scope,
    'published', case when student then persona end, case when student then null else actor end
  );
  return 'posted';
exception
  when check_violation or insufficient_privilege then
    return 'unavailable';
end
$function$;
--> statement-breakpoint
-- A logged-in member reports a post they can see (REQ-STU-011). The reporter
-- is stored for staff; the author of the post is not told who reported it.
create function identity.report_hub_post(
  p_session uuid, p_post uuid, p_reason text, p_note text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  note text := nullif(btrim(p_note), '');
begin
  if not identity.is_hub_session(p_session) then return 'denied'; end if;
  if p_reason not in ('personal_details', 'face_or_name', 'unkind', 'wrong_information', 'other')
    or (p_reason = 'other' and note is null) or (note is not null and length(note) > 300)
  then
    return 'invalid';
  end if;
  if note is not null and app.has_contact_details(note) then return 'contact_details'; end if;
  if not exists (
    select from app.posts p
    join app.threads t on (t.institute_id, t.id) = (p.institute_id, p.thread_id)
    where p.institute_id = tenant and p.id = p_post and p.scope in ('class', 'madrasa', 'public')
      and (t.scope = 'madrasa' or identity.hub_can_see_class(t.class_id))
  ) then
    return 'unavailable';
  end if;
  insert into app.post_reports (institute_id, post_id, reporter_user_id, reason, note)
  values (tenant, p_post, app.current_user_id(), p_reason, note);
  return 'reported';
exception when unique_violation then
  return 'already';
end
$function$;
--> statement-breakpoint
revoke all on function identity.is_hub_session(uuid), identity.hub_can_see_class(uuid),
  identity.read_hub(uuid, text, uuid, uuid),
  identity.start_hub_thread(uuid, text, uuid, text, text, text, text),
  identity.reply_hub_thread(uuid, uuid, uuid, text, text, text),
  identity.report_hub_post(uuid, uuid, text, text) from public;
--> statement-breakpoint
grant execute on function identity.read_hub(uuid, text, uuid, uuid),
  identity.start_hub_thread(uuid, text, uuid, text, text, text, text),
  identity.reply_hub_thread(uuid, uuid, uuid, text, text, text),
  identity.report_hub_post(uuid, uuid, text, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
