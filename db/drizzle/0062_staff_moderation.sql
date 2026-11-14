SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The public-request queue (07 §8, P3-E5-T05, P3-E5-T08). A post is listed
-- only when this person may approve it. Approving a student's public work
-- needs public-work consent, and a face in the post needs face consent.
create function identity.moderation_queue(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  is_admin boolean := app.has_role('admin');
begin
  if not identity.staff_session_ok(p_session_id)
    or not (is_admin or app.has_role('teacher') or app.has_role('editor'))
  then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'title', p.title,
        'body', left(p.body, 280),
        'language', p.language,
        'scope', p.scope,
        'target_scope', p.target_scope,
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
        'face_consent', student.user_id is not null and app.consent_active(student.user_id, 'face')
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
    ), '[]'::jsonb)
  );
end
$function$;
--> statement-breakpoint
create function identity.decide_post(
  p_session_id uuid, p_post_id uuid, p_action text, p_note text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  post app.posts%rowtype;
  student uuid;
  note text := nullif(btrim(p_note), '');
  shows_face boolean;
begin
  if not identity.staff_session_ok(p_session_id) then
    return 'denied';
  end if;
  if p_post_id is null or p_action not in ('approve', 'reject')
    or (note is not null and (length(note) > 500 or note ~ '[[:cntrl:]]'))
    or (p_action = 'reject' and note is null)
  then
    return 'invalid';
  end if;
  select * into post from app.posts
  where institute_id = tenant and id = p_post_id
  for update;
  if not found or post.moderation_state <> 'submitted' then
    return 'not_waiting';
  end if;
  select l.user_id into student from app.persona_links l
  where l.institute_id = tenant and l.persona_id = post.author_persona_id;
  if not app.may_approve_post(post, student) then
    return 'denied';
  end if;
  select exists (
    select from app.post_media pm
    join app.media_assets m on m.institute_id = pm.institute_id and m.id = pm.media_asset_id
    where pm.institute_id = tenant and pm.post_id = post.id and m.shows_face and m.status <> 'deleted'
  ) into shows_face;
  if p_action = 'approve' and student is not null and post.target_scope = 'public' then
    if not app.consent_active(student, 'public_work') then
      return 'needs_consent';
    end if;
    if shows_face and not app.consent_active(student, 'face') then
      return 'face_blocked';
    end if;
  end if;
  begin
    if p_action = 'approve' then
      update app.posts set moderation_state = 'approved'
      where institute_id = tenant and id = post.id;
    else
      update app.posts set moderation_state = case when published_at is null then 'draft' else 'published' end
      where institute_id = tenant and id = post.id;
    end if;
  exception
    when insufficient_privilege then return 'denied';
    when object_not_in_prerequisite_state then return 'blocked';
    when check_violation then return 'invalid';
  end;
  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, reason, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    case when p_action = 'approve' then 'posts.approved' else 'posts.rejected' end,
    'posts', post.id::text, note, nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return case when p_action = 'approve' then 'approved' else 'rejected' end;
end
$function$;
--> statement-breakpoint
revoke all on function identity.moderation_queue(uuid),
  identity.decide_post(uuid, uuid, text, text) from public;
--> statement-breakpoint
grant execute on function identity.moderation_queue(uuid),
  identity.decide_post(uuid, uuid, text, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
