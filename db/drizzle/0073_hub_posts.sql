SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Remaining hub post types, polls, verified articles and teacher review
-- (REQ-STU-005, REQ-STU-007, REQ-TCH-001 to REQ-TCH-004, D-162, D-163).
-- Audio files and slide files need object storage, so those posts keep their
-- text and leave the file slot empty.

alter table app.posts add column summary text;
--> statement-breakpoint
alter table app.posts add column youtube_id text;
--> statement-breakpoint
alter table app.posts add column hub_label text;
--> statement-breakpoint
alter table app.posts add constraint posts_summary_check check (
  summary is null or (length(summary) between 1 and 300 and summary = btrim(summary) and summary ~ '[^[:space:]]'));
--> statement-breakpoint
alter table app.posts add constraint posts_youtube_check check (
  youtube_id is null or (post_type in ('video', 'vlog') and youtube_id ~ '^[A-Za-z0-9_-]{11}$'));
--> statement-breakpoint
alter table app.posts add constraint posts_hub_label_check check (
  hub_label is null or (author_user_id is not null and (
    (hub_label = 'lesson' and post_type in ('article', 'video', 'audio', 'slides'))
    or (hub_label = 'resource' and post_type in ('article', 'slides')))));
--> statement-breakpoint
-- Classes, threads or one thread, plus the signed-in person's walkthrough
-- and persona. Students still see pen names only. No key in this payload is
-- named with a user id (donor_community.sql).
create or replace function identity.read_hub(
  p_session uuid, p_scope text, p_class uuid, p_thread uuid
) returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  staff boolean;
  student boolean;
  viewer jsonb;
  thread_row app.threads;
begin
  if not identity.is_hub_session(p_session) then
    return jsonb_build_object('code', 'denied');
  end if;
  student := app.has_role('student') and not app.has_role('teacher') and not app.has_role('admin');
  if student and not app.module_enabled('student_hub') then
    return jsonb_build_object('code', 'module_off');
  end if;
  if not student and not app.module_enabled('student_hub') and not app.module_enabled('teacher_hub') then
    return jsonb_build_object('code', 'module_off');
  end if;
  staff := app.has_role('admin') or app.has_role('teacher');
  select jsonb_build_object(
    'role', case when student then 'student' when app.has_role('teacher') then 'teacher' else 'admin' end,
    'status', u.status,
    'walkthrough', (student or app.has_role('teacher')) and u.onboarded_at is null,
    'onboarded', u.onboarded_at is not null,
    'step', u.onboarding_step,
    'steps', case when student then 8 else 4 end,
    'skipped', to_jsonb(u.onboarding_skipped),
    'language', u.preferred_language,
    'public_name', case when staff then u.public_name end,
    'public_role', case when staff then u.public_role end,
    'public_bio', case when staff then u.public_bio end,
    'persona', case when persona.id is not null then jsonb_build_object(
      'display_name', persona.display_name,
      'avatar', persona.avatar_preset,
      'bio', persona.bio,
      'bio_language', persona.bio_language,
      'can_rename', persona.display_name_changed_at is null
        or persona.display_name_changed_at <= now() - interval '30 days',
      'reset', persona.reset_note is not null
    ) end,
    'institute_name', settings.name
  ) into viewer
  from app.users u
  left join app.persona_links link on link.institute_id = u.institute_id and link.user_id = u.id
  left join app.personas persona on persona.institute_id = link.institute_id and persona.id = link.persona_id
  join app.institute_settings settings on settings.institute_id = u.institute_id
  where u.institute_id = tenant and u.id = actor;

  if p_thread is not null then
    select * into thread_row from app.threads t
    where t.institute_id = tenant and t.id = p_thread and t.scope in ('class', 'madrasa')
      and (t.scope = 'madrasa' or identity.hub_can_see_class(t.class_id));
    if thread_row.id is null then
      return jsonb_build_object('code', 'unavailable');
    end if;
    return jsonb_build_object(
      'code', 'ok',
      'viewer', viewer,
      'thread', jsonb_build_object(
        'id', thread_row.id, 'title', thread_row.title, 'language', thread_row.language,
        'scope', thread_row.scope, 'class_id', thread_row.class_id,
        'locked', thread_row.locked_at is not null,
        'article_post_id', thread_row.article_post_id,
        'can_verify', thread_row.article_post_id is null and (
          app.has_role('admin') or (app.has_role('teacher')
            and (thread_row.class_id is null or app.is_class_teacher(thread_row.class_id))))
      ),
      'posts', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', p.id, 'post_type', p.post_type, 'language', p.language,
          'title', p.title, 'body', p.body, 'summary', p.summary,
          'youtube_id', p.youtube_id, 'hub_label', p.hub_label,
          'created_at', p.created_at, 'parent_post_id', p.parent_post_id,
          'author_name', coalesce(persona.display_name, author.full_name),
          'author_kind', case when p.author_persona_id is not null then 'persona' else 'staff' end,
          'avatar', persona.avatar_preset,
          'hidden', p.hidden_at is not null or p.moderation_state = 'taken_down',
          'moderation_state', p.moderation_state,
          'is_verified', p.is_verified,
          'verified_name', case when p.is_verified then coalesce(verifier.public_name, verifier.full_name) end,
          'can_submit', p.author_user_id = actor and p.moderation_state = 'published'
            and p.scope in ('class', 'madrasa') and p.hidden_at is null,
          'media_gap', p.post_type in ('audio', 'slides'),
          'poll', case when p.post_type <> 'poll' then null else jsonb_build_object(
            'closes_at', p.poll_closes_at,
            'closed', p.poll_closes_at <= now(),
            'multiple', p.poll_multiple,
            'max_choices', p.poll_max_choices,
            'results', p.poll_results,
            'can_close', p.poll_closes_at > now() and staff,
            'mine', coalesce((
              select jsonb_agg(v.option_id) from app.poll_votes v
              where v.institute_id = p.institute_id and v.post_id = p.id and v.voter_user_id = actor
            ), '[]'::jsonb),
            'options', coalesce((
              select jsonb_agg(jsonb_build_object(
                'id', o.id, 'label', o.label, 'position', o.position,
                'votes', case when p.poll_closes_at <= now()
                  or staff
                  or (p.poll_results = 'after_voting' and exists (
                    select from app.poll_votes mine
                    where mine.institute_id = p.institute_id and mine.post_id = p.id and mine.voter_user_id = actor))
                  then (select count(*)::int from app.poll_votes cv
                    where cv.institute_id = o.institute_id and cv.post_id = o.post_id and cv.option_id = o.id)
                  end
              ) order by o.position)
              from app.poll_options o
              where o.institute_id = p.institute_id and o.post_id = p.id
            ), '[]'::jsonb),
            'voters', case when not staff then null else coalesce((
              select jsonb_agg(jsonb_build_object(
                'option', opt.label,
                'name', case
                  when exists (
                    select from app.user_roles sr
                    where sr.institute_id = v.institute_id and sr.user_id = v.voter_user_id and sr.role = 'student')
                  then case when app.has_role('admin') or app.is_teacher_of(v.voter_user_id)
                    then voter.full_name else pen.display_name end
                  else voter.full_name end
              ) order by opt.position, v.created_at)
              from app.poll_votes v
              join app.poll_options opt on opt.institute_id = v.institute_id and opt.id = v.option_id
              join app.users voter on voter.institute_id = v.institute_id and voter.id = v.voter_user_id
              left join app.persona_links pl on pl.institute_id = v.institute_id and pl.user_id = v.voter_user_id
              left join app.personas pen on pen.institute_id = pl.institute_id and pen.id = pl.persona_id
              where v.institute_id = p.institute_id and v.post_id = p.id
            ), '[]'::jsonb) end
          ) end
        ) order by p.created_at, p.id)
        from app.posts p
        left join app.personas persona on (persona.institute_id, persona.id) = (p.institute_id, p.author_persona_id)
        left join app.users author on p.author_persona_id is null
          and (author.institute_id, author.id) = (p.institute_id, p.author_user_id)
        left join app.users verifier on p.is_verified
          and (verifier.institute_id, verifier.id) = (p.institute_id, p.verified_by)
        where p.institute_id = tenant and p.thread_id = thread_row.id and p.scope <> 'community'
          and (
            (p.moderation_state = 'published' and p.hidden_at is null)
            or (p.hidden_at is null and p.moderation_state in ('submitted', 'approved')
              and (p.author_persona_id = app.current_persona_id() or p.author_user_id = actor))
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
    return jsonb_build_object('code', 'ok', 'viewer', viewer, 'threads', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'title', t.title, 'language', t.language, 'scope', t.scope,
        'reply_count', t.reply_count, 'last_post_at', t.last_post_at,
        'locked', t.locked_at is not null,
        'article_post_id', t.article_post_id
      ) order by t.last_post_at desc, t.id)
      from app.threads t
      where t.institute_id = tenant and t.scope = p_scope
        and (p_scope = 'madrasa' or t.class_id = p_class)
    ), '[]'::jsonb));
  end if;

  return jsonb_build_object('code', 'ok', 'viewer', viewer, 'classes', coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'kind', c.kind
    ) order by c.kind, c.name->>'en', c.id)
    from app.classes c
    where c.institute_id = tenant and c.archived_at is null
      and identity.hub_can_see_class(c.id)
  ), '[]'::jsonb));
end
$function$;
--> statement-breakpoint
create function identity.publish_hub_post(
  p_session uuid, p_scope text, p_class uuid, p_thread uuid, p_parent uuid,
  p_post_type text, p_language text, p_title text, p_summary text, p_body text,
  p_youtube text, p_hub_label text, p_poll_multiple boolean, p_poll_max smallint,
  p_poll_results text, p_poll_hours int, p_options text[]
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
  summary text := nullif(btrim(p_summary), '');
  body text := nullif(btrim(p_body), '');
  youtube text := nullif(btrim(p_youtube), '');
  label text := nullif(btrim(p_hub_label), '');
  thread_row app.threads;
  thread_id uuid;
  post_id uuid;
  option text;
  position smallint := 0;
  limit_body int;
  scanned text;
begin
  if not identity.is_hub_session(p_session) then
    return jsonb_build_object('code', 'denied');
  end if;
  if p_post_type not in ('message', 'question', 'answer', 'poll', 'article', 'video', 'vlog', 'audio', 'slides')
    or p_language not in ('ur', 'en')
  then
    return jsonb_build_object('code', 'invalid');
  end if;
  if p_thread is null and p_post_type = 'answer' then
    return jsonb_build_object('code', 'invalid');
  end if;
  if p_thread is not null and p_post_type in ('question', 'article', 'vlog', 'slides') then
    return jsonb_build_object('code', 'invalid');
  end if;
  limit_body := case p_post_type
    when 'message' then 1000 when 'question' then 2000 when 'answer' then 3000
    when 'poll' then 200 when 'article' then 20000 else 1000 end;
  if p_post_type = 'poll' then
    body := coalesce(body, title);
    title := null;
  end if;
  if body is null or length(body) > limit_body
    or (title is not null and length(title) > case when p_post_type = 'message' then 80 else 150 end)
    or (summary is not null and length(summary) > 300)
    or (p_post_type in ('question', 'article', 'video', 'vlog', 'audio', 'slides') and title is null)
  then
    return jsonb_build_object('code', 'invalid');
  end if;
  if youtube is not null then
    if youtube ~ 'https?://|www\.' then
      youtube := substring(youtube from '(?:youtu\.be/|v=|embed/)([A-Za-z0-9_-]{11})');
    end if;
    if youtube is null or youtube !~ '^[A-Za-z0-9_-]{11}$' or p_post_type not in ('video', 'vlog') then
      return jsonb_build_object('code', 'invalid');
    end if;
  elsif p_post_type in ('video', 'vlog') then
    return jsonb_build_object('code', 'invalid');
  end if;
  if label is not null and (
    student or label not in ('lesson', 'resource')
    or (label = 'lesson' and p_post_type not in ('article', 'video', 'audio', 'slides'))
    or (label = 'resource' and p_post_type not in ('article', 'slides'))
  ) then
    return jsonb_build_object('code', 'invalid');
  end if;
  if p_post_type = 'poll' and (
    p_options is null or cardinality(p_options) not between 2 and 6
    or (p_poll_multiple and (p_poll_max is null or p_poll_max not between 2 and cardinality(p_options)))
    or (not p_poll_multiple and p_poll_max is not null)
    or (p_poll_results is not null and p_poll_results not in ('after_voting', 'after_closing'))
    or (p_poll_hours is not null and p_poll_hours not between 1 and 720)
  ) then
    return jsonb_build_object('code', 'invalid');
  end if;
  if p_post_type = 'poll' then
    foreach option in array p_options loop
      if btrim(option) is null or length(btrim(option)) not between 1 and 80 then
        return jsonb_build_object('code', 'invalid');
      end if;
    end loop;
  end if;
  scanned := concat_ws(' ', title, summary, body, youtube, array_to_string(p_options, ' '));
  if app.has_contact_details(scanned)
    or (student and scanned ~* 'https?://|(^|[^[:alnum:]_])www\.')
    or app.persona_text_blocked(scanned)
  then
    return jsonb_build_object('code', 'contact_details');
  end if;
  if student and not app.module_enabled('student_hub') then
    return jsonb_build_object('code', 'module_off');
  end if;
  if p_thread is null then
    if p_scope not in ('class', 'madrasa')
      or (p_scope = 'class' and p_class is null)
      or (p_scope = 'madrasa' and p_class is not null)
    then
      return jsonb_build_object('code', 'invalid');
    end if;
    if not student and p_scope = 'madrasa' and not app.module_enabled('teacher_hub') and not app.has_role('admin') then
      return jsonb_build_object('code', 'module_off');
    end if;
    if p_scope = 'class' and not identity.hub_can_see_class(p_class) then
      return jsonb_build_object('code', 'unavailable');
    end if;
    if student and p_scope = 'class' and not app.is_class_member(p_class) then
      return jsonb_build_object('code', 'unavailable');
    end if;
    if not student and not (app.has_role('teacher') or app.has_role('admin')) then
      return jsonb_build_object('code', 'denied');
    end if;
    insert into app.threads (
      institute_id, class_id, scope, title, language, author_persona_id, author_user_id
    ) values (
      tenant, case when p_scope = 'class' then p_class end, p_scope, coalesce(title, left(body, 80)), p_language,
      case when student then persona end, case when student then null else actor end
    ) returning id into thread_id;
  else
    select * into thread_row from app.threads t
    where t.institute_id = tenant and t.id = p_thread and t.scope in ('class', 'madrasa')
      and (t.scope = 'madrasa' or identity.hub_can_see_class(t.class_id));
    if thread_row.id is null then return jsonb_build_object('code', 'unavailable'); end if;
    if student and thread_row.scope = 'class' and not app.is_class_member(thread_row.class_id) then
      return jsonb_build_object('code', 'unavailable');
    end if;
    thread_id := thread_row.id;
    p_scope := thread_row.scope;
    if p_post_type = 'answer' and p_parent is null then
      select q.id into p_parent from app.posts q
      where q.institute_id = tenant and q.thread_id = thread_id and q.post_type = 'question'
      order by q.created_at limit 1;
      if p_parent is null then return jsonb_build_object('code', 'invalid'); end if;
    end if;
  end if;

  insert into app.posts (
    institute_id, thread_id, parent_post_id, post_type, language, title, summary, body,
    youtube_id, hub_label, moderation_state, author_persona_id, author_user_id,
    poll_closes_at, poll_multiple, poll_max_choices, poll_results
  ) values (
    tenant, thread_id, case when p_thread is null then null else p_parent end,
    p_post_type, p_language, title, summary, body, youtube, label, 'published',
    case when student then persona end, case when student then null else actor end,
    case when p_post_type = 'poll' and p_poll_hours is not null then now() + make_interval(hours => p_poll_hours) end,
    coalesce(p_post_type = 'poll' and p_poll_multiple, false),
    case when p_post_type = 'poll' and p_poll_multiple then p_poll_max end,
    case when p_post_type = 'poll' then coalesce(p_poll_results, 'after_closing') end
  ) returning id into post_id;

  if p_post_type = 'poll' then
    foreach option in array p_options loop
      position := position + 1;
      insert into app.poll_options (institute_id, post_id, label, position)
      values (tenant, post_id, btrim(option), position);
    end loop;
  end if;
  return jsonb_build_object('code', 'posted', 'thread_id', thread_id, 'post_id', post_id,
    'media_gap', p_post_type in ('audio', 'slides'));
exception
  when check_violation or insufficient_privilege or object_not_in_prerequisite_state then
    return jsonb_build_object('code', 'unavailable');
end
$function$;
--> statement-breakpoint
create function identity.vote_hub_poll(p_session uuid, p_post uuid, p_options uuid[])
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  poll app.posts;
  chosen int;
  option uuid;
begin
  if not identity.is_hub_session(p_session) then return 'denied'; end if;
  if app.has_role('editor') and not app.has_role('student') and not app.has_role('teacher')
    and not app.has_role('admin') then
    return 'denied';
  end if;
  select * into poll from app.posts p
  join app.threads t on t.institute_id = p.institute_id and t.id = p.thread_id
  where p.institute_id = tenant and p.id = p_post and p.post_type = 'poll'
    and p.moderation_state = 'published' and p.hidden_at is null
    and (t.scope = 'madrasa' or identity.hub_can_see_class(t.class_id));
  if poll.id is null or poll.poll_closes_at <= now() then return 'closed'; end if;
  if p_options is null then p_options := '{}'; end if;
  select count(distinct item) into chosen from unnest(p_options) item;
  if chosen <> cardinality(p_options) then return 'invalid'; end if;
  if poll.poll_multiple then
    if chosen > poll.poll_max_choices then return 'invalid'; end if;
  elsif chosen > 1 then
    return 'invalid';
  end if;
  if exists (
    select from unnest(p_options) item
    where not exists (
      select from app.poll_options o
      where o.institute_id = tenant and o.post_id = poll.id and o.id = item)
  ) then
    return 'invalid';
  end if;
  delete from app.poll_votes v
  where v.institute_id = tenant and v.post_id = poll.id and v.voter_user_id = actor;
  foreach option in array p_options loop
    insert into app.poll_votes (institute_id, post_id, option_id, voter_user_id)
    values (tenant, poll.id, option, actor);
  end loop;
  return 'voted';
exception
  when unique_violation or object_not_in_prerequisite_state or insufficient_privilege then
    return 'closed';
end
$function$;
--> statement-breakpoint
create function identity.close_hub_poll(p_session uuid, p_post uuid) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if not identity.is_hub_session(p_session) then return 'denied'; end if;
  if not (app.has_role('teacher') or app.has_role('admin')) then return 'denied'; end if;
  if app.close_poll(p_post) then return 'closed'; end if;
  return 'unavailable';
end
$function$;
--> statement-breakpoint
create function identity.make_hub_article(
  p_session uuid, p_thread uuid, p_title text, p_summary text, p_body text,
  p_language text, p_quotes uuid[]
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  title text := nullif(btrim(p_title), '');
  summary text := nullif(btrim(p_summary), '');
  body text := nullif(btrim(p_body), '');
  quote_id uuid;
  quote_body text;
  quote_name text;
  article uuid;
begin
  if not identity.is_hub_session(p_session) then
    return jsonb_build_object('code', 'denied');
  end if;
  if title is null or body is null or p_language not in ('ur', 'en')
    or length(title) > 150 or length(body) > 20000
    or (summary is not null and length(summary) > 300)
  then
    return jsonb_build_object('code', 'invalid');
  end if;
  if app.has_contact_details(concat_ws(' ', title, summary, body)) then
    return jsonb_build_object('code', 'contact_details');
  end if;
  if p_quotes is not null then
    foreach quote_id in array p_quotes loop
      select left(p.body, 400), coalesce(persona.display_name, author.public_name, author.full_name)
        into quote_body, quote_name
      from app.posts p
      join app.threads t on t.institute_id = p.institute_id and t.id = p.thread_id
      left join app.personas persona on persona.institute_id = p.institute_id and persona.id = p.author_persona_id
      left join app.users author on author.institute_id = p.institute_id and author.id = p.author_user_id
      where p.institute_id = tenant and p.id = quote_id and p.thread_id = p_thread
        and p.moderation_state = 'published' and p.hidden_at is null
        and (t.scope = 'madrasa' or identity.hub_can_see_class(t.class_id));
      if quote_body is null then return jsonb_build_object('code', 'invalid'); end if;
      if app.has_contact_details(quote_body) then
        return jsonb_build_object('code', 'contact_details');
      end if;
      body := body || E'\n\n> ' || coalesce(quote_name, '') || ': ' || quote_body;
    end loop;
  end if;
  article := app.make_verified_article(p_thread, title, body, p_language);
  if article is null then return jsonb_build_object('code', 'denied'); end if;
  if summary is not null then
    update app.posts set summary = nullif(btrim(p_summary), '')
    where institute_id = tenant and id = article;
  end if;
  return jsonb_build_object('code', 'posted', 'post_id', article);
exception when check_violation or insufficient_privilege then
  return jsonb_build_object('code', 'unavailable');
end
$function$;
--> statement-breakpoint
create function identity.submit_hub_post(p_session uuid, p_post uuid) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  post app.posts;
begin
  if not identity.is_hub_session(p_session) then return 'denied'; end if;
  select * into post from app.posts p
  where p.institute_id = tenant and p.id = p_post and p.author_user_id = actor
    and p.moderation_state = 'published' and p.scope in ('class', 'madrasa') and p.hidden_at is null
  for update;
  if post.id is null then return 'denied'; end if;
  begin
    if app.has_role('admin') and post.author_user_id = actor then
      update app.posts set target_scope = 'public'
      where institute_id = tenant and id = post.id;
      insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
        action, entity_table, entity_id, reason)
      select tenant, actor, 'user', array_agg(r.role order by r.role),
        'posts.published_public', 'posts', post.id::text, 'admin'
      from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
      return 'published';
    end if;
    update app.posts set moderation_state = 'submitted', target_scope = 'public'
    where institute_id = tenant and id = post.id;
  exception
    when insufficient_privilege then return 'denied';
    when object_not_in_prerequisite_state then return 'needs_consent';
    when check_violation then return 'invalid';
  end;
  return 'submitted';
end
$function$;
--> statement-breakpoint
create function identity.save_teacher_profile(
  p_session uuid, p_name text, p_role text, p_bio_ur text, p_bio_en text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  public_name text := nullif(btrim(p_name), '');
  public_role text := nullif(btrim(p_role), '');
  bio_ur text := nullif(btrim(p_bio_ur), '');
  bio_en text := nullif(btrim(p_bio_en), '');
  bio jsonb := '{}'::jsonb;
begin
  if not identity.is_hub_session(p_session) then return 'denied'; end if;
  if not (app.has_role('teacher') or app.has_role('admin')) then return 'denied'; end if;
  if public_name is null or length(public_name) > 80
    or (public_role is not null and length(public_role) > 80)
    or (bio_ur is not null and length(bio_ur) > 300)
    or (bio_en is not null and length(bio_en) > 300)
  then
    return 'invalid';
  end if;
  if app.has_contact_details(concat_ws(' ', public_name, public_role, bio_ur, bio_en)) then
    return 'contact_details';
  end if;
  if bio_ur is not null then bio := bio || jsonb_build_object('ur', bio_ur); end if;
  if bio_en is not null then bio := bio || jsonb_build_object('en', bio_en); end if;
  update app.users set public_name = public_name, public_role = public_role,
    public_bio = case when bio = '{}'::jsonb then null else bio end
  where institute_id = tenant and id = actor;
  return 'saved';
end
$function$;
--> statement-breakpoint
create or replace view public_api.public_posts with (security_barrier = true) as
select p.id, p.thread_id, p.parent_post_id, p.post_type, p.language, p.title, p.body, p.published_at,
  p.poll_closes_at, p.poll_multiple, p.poll_max_choices,
  case when p.author_persona_id is not null then 'persona' else 'teacher' end as author_kind,
  pe.display_name as persona_name, av.id as persona_avatar_media_id, av.storage_key as persona_avatar_storage_key,
  av.variants as persona_avatar_variants,
  case when p.author_user_id is not null then p.author_user_id end as teacher_id,
  au.public_name as teacher_name,
  p.is_verified, p.verified_at, vu.public_name as verified_by_name,
  p.summary, p.youtube_id, p.hub_label, pe.avatar_preset as persona_avatar_preset
from app.posts p
left join app.personas pe on pe.institute_id = p.institute_id and pe.id = p.author_persona_id
left join app.media_assets av on av.institute_id = pe.institute_id and av.id = pe.avatar_media_id
  and av.purpose = 'avatar' and av.kind = 'image' and av.status = 'ready' and av.visibility = 'public'
  and not av.shows_face
left join app.users au on au.institute_id = p.institute_id and au.id = p.author_user_id
left join app.users vu on vu.institute_id = p.institute_id and vu.id = p.verified_by
where p.institute_id = app.current_institute_id() and p.scope = 'public' and p.moderation_state = 'published'
  and p.hidden_at is null
  and case when p.author_persona_id is not null then
    app.module_enabled('student_hub') and pe.is_active and app.persona_work_may_show(p.author_persona_id)
  else app.module_enabled('teacher_hub') end;
--> statement-breakpoint
revoke all on function identity.publish_hub_post(uuid, text, uuid, uuid, uuid, text, text, text, text, text, text, text, boolean, smallint, text, int, text[]),
  identity.vote_hub_poll(uuid, uuid, uuid[]), identity.close_hub_poll(uuid, uuid),
  identity.make_hub_article(uuid, uuid, text, text, text, text, uuid[]),
  identity.submit_hub_post(uuid, uuid), identity.save_teacher_profile(uuid, text, text, text, text)
  from public;
--> statement-breakpoint
grant execute on function identity.publish_hub_post(uuid, text, uuid, uuid, uuid, text, text, text, text, text, text, text, boolean, smallint, text, int, text[]),
  identity.vote_hub_poll(uuid, uuid, uuid[]), identity.close_hub_poll(uuid, uuid),
  identity.make_hub_article(uuid, uuid, text, text, text, text, uuid[]),
  identity.submit_hub_post(uuid, uuid), identity.save_teacher_profile(uuid, text, text, text, text)
  to tazkiyah_auth;
--> statement-breakpoint
create or replace function app.posts_moderation() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  actor uuid := app.current_user_id();
  student uuid;
  is_admin boolean := app.has_role('admin');
  is_author boolean;
  is_post_teacher boolean;
  publish boolean := false;
begin
  if (new.institute_id, new.thread_id, new.parent_post_id, new.post_type, new.class_id, new.author_persona_id,
      new.author_user_id, new.created_at)
    is distinct from (old.institute_id, old.thread_id, old.parent_post_id, old.post_type, old.class_id,
      old.author_persona_id, old.author_user_id, old.created_at)
  then
    raise exception 'a post keeps its thread, type, class and author' using errcode = 'insufficient_privilege';
  end if;
  select l.user_id into student from app.persona_links l
  where l.institute_id = old.institute_id and l.persona_id = old.author_persona_id;
  is_author := coalesce(actor = old.author_user_id, false)
    or (coalesce(actor = student, false) and app.has_role('student'));
  -- Teachers moderate their classes and everything in madrasa scope (04 §11.3, 07 §8.4).
  is_post_teacher := actor is not null and app.has_role('teacher') and old.scope <> 'community'
    and (old.class_id is null or old.scope = 'madrasa' or app.is_class_teacher(old.class_id));

  -- The wider scope is asked for only by a request, and taken only on publishing.
  if new.scope is distinct from old.scope then
    raise exception 'a post widens only through approval' using errcode = 'insufficient_privilege';
  end if;
  -- An admin publishes their own hub item directly (07 §10.2, D-163).
  if is_admin and actor = old.author_user_id and old.author_persona_id is null
    and old.moderation_state = 'published' and new.moderation_state = 'published'
    and old.scope in ('class', 'madrasa') and old.hidden_at is null
    and new.target_scope = 'public' and new.scope = old.scope
  then
    new.scope := 'public';
    new.target_scope := null;
    new.published_at := now();
    return new;
  end if;
  if new.target_scope is distinct from old.target_scope and new.moderation_state = old.moderation_state then
    raise exception 'the requested scope changes only with a request' using errcode = 'insufficient_privilege';
  end if;
  new.submitted_at := old.submitted_at;
  new.approved_by := old.approved_by;
  new.approved_at := old.approved_at;
  new.taken_down_at := old.taken_down_at;
  new.taken_down_by := old.taken_down_by;
  new.published_at := old.published_at;

  if new.moderation_state is distinct from old.moderation_state then
    if new.moderation_state = 'taken_down' then
      -- Any post can be taken down, with a reason (REQ-CHS-004, 07 §8.4).
      if not (actor is null or is_admin or is_post_teacher) then
        raise exception 'only a teacher or admin takes down a post' using errcode = 'insufficient_privilege';
      end if;
      if new.takedown_reason is null or new.takedown_reason !~ '[^[:space:]]' then
        raise exception 'a takedown needs a reason' using errcode = 'check_violation';
      end if;
      new.taken_down_at := now();
      new.taken_down_by := actor;
      new.target_scope := null;
      new.submitted_at := null;
      if old.hidden_at is null then
        new.hidden_at := now();
        new.hidden_by := actor;
      end if;
    elsif actor is null then
      raise exception 'a system step only hides or takes down' using errcode = 'insufficient_privilege';
    elsif old.moderation_state = 'taken_down' then
      -- An admin restores: a public post needs fresh approval (07 §8.2).
      if not is_admin then
        raise exception 'only an admin restores a post' using errcode = 'insufficient_privilege';
      end if;
      if old.scope = 'public' then
        if new.moderation_state <> 'submitted' then
          raise exception 'a restored public post needs fresh approval' using errcode = 'check_violation';
        end if;
        new.scope := case when old.class_id is not null then 'class' else 'madrasa' end;
        new.target_scope := 'public';
        new.submitted_at := now();
      elsif new.moderation_state <> 'published' then
        raise exception 'a restored post returns to its scope' using errcode = 'check_violation';
      end if;
      new.taken_down_at := null;
      new.taken_down_by := null;
      new.takedown_reason := null;
      new.approved_by := null;
      new.approved_at := null;
    elsif old.moderation_state = 'draft' and new.moderation_state = 'published' then
      if not is_author or new.target_scope is not null then
        raise exception 'only the author posts a draft' using errcode = 'insufficient_privilege';
      end if;
      new.published_at := now();
    elsif old.moderation_state in ('draft', 'published') and new.moderation_state = 'submitted' then
      if not is_author then
        raise exception 'only the author asks to widen a post' using errcode = 'insufficient_privilege';
      end if;
      if old.hidden_at is not null then
        raise exception 'a hidden post cannot be put forward' using errcode = 'object_not_in_prerequisite_state';
      end if;
      if new.target_scope is null or not (
        (old.scope = 'class' and new.target_scope in ('madrasa', 'public'))
        or (old.scope = 'madrasa' and new.target_scope = 'public')
        or (new.target_scope = 'community' and old.scope <> 'community'))
      then
        raise exception 'a request asks for a wider scope' using errcode = 'check_violation';
      end if;
      perform app.hub_author_rules(old.institute_id, new.target_scope, old.class_id, old.author_persona_id,
        old.author_user_id);
      if student is not null and not app.module_enabled('student_hub') then
        raise exception 'the student hub is switched off' using errcode = 'insufficient_privilege';
      end if;
      -- 07 §8.2 checks consent when the student sends the request.
      if student is not null and new.target_scope = 'public' and not app.consent_active(student, 'public_work') then
        raise exception 'this student''s work has no public consent' using errcode = 'object_not_in_prerequisite_state';
      end if;
      new.submitted_at := now();
    elsif old.moderation_state = 'submitted' and new.moderation_state = 'approved' then
      if not app.may_approve_post(old, student) then
        raise exception 'only an approver approves this post' using errcode = 'insufficient_privilege';
      end if;
      new.approved_by := actor;
      new.approved_at := now();
      publish := true;
    elsif old.moderation_state = 'approved' and new.moderation_state = 'published' then
      if not (is_admin or app.may_approve_post(old, student)) then
        raise exception 'only an approver publishes this post' using errcode = 'insufficient_privilege';
      end if;
      publish := true;
    elsif old.moderation_state = 'submitted' and new.moderation_state in ('draft', 'published') then
      -- Rejected by an approver or withdrawn by the author: back where it was.
      if not (is_author or app.may_approve_post(old, student)) then
        raise exception 'only the author or an approver ends a request' using errcode = 'insufficient_privilege';
      end if;
      if new.moderation_state <> (case when old.published_at is null then 'draft' else 'published' end) then
        raise exception 'an ended request returns the post where it was' using errcode = 'check_violation';
      end if;
      new.target_scope := null;
      new.submitted_at := null;
      new.approved_by := null;
      new.approved_at := null;
    else
      raise exception 'this moderation step is not allowed' using errcode = 'check_violation';
    end if;
  end if;

  -- Publishing an approved request: the post must be visible, have no open
  -- report (07 §8.2) and, for a student's public work, consent still active
  -- (REQ-CHS-005). Otherwise it waits as approved.
  if publish then
    if new.hidden_at is null and not (student is not null and new.target_scope = 'public'
      and not app.consent_active(student, 'public_work'))
      and not exists (select from app.post_reports r
        where r.institute_id = new.institute_id and r.post_id = new.id and r.status = 'open')
    then
      new.moderation_state := 'published';
      new.scope := new.target_scope;
      new.target_scope := null;
      new.submitted_at := null;
      new.published_at := now();
      perform app.hub_author_rules(new.institute_id, new.scope, new.class_id, new.author_persona_id,
        new.author_user_id);
    elsif new.moderation_state = 'published' then
      raise exception 'the post cannot be published yet' using errcode = 'object_not_in_prerequisite_state';
    end if;
  end if;

  -- Hide and unhide inside the madrasa (REQ-MOD-002, 07 §8.1).
  if new.hidden_at is distinct from old.hidden_at then
    if old.hidden_at is null then
      if not (actor is null or is_admin or is_post_teacher) then
        raise exception 'only a teacher or admin hides a post' using errcode = 'insufficient_privilege';
      end if;
      new.hidden_at := now();
      new.hidden_by := actor;
    elsif new.hidden_at is null then
      if not (is_admin or (old.class_id is not null and app.has_role('teacher') and app.is_class_teacher(old.class_id))) then
        raise exception 'only the class teacher or an admin shows a hidden post' using errcode = 'insufficient_privilege';
      end if;
      if new.moderation_state = 'taken_down' then
        raise exception 'a taken-down post stays hidden' using errcode = 'object_not_in_prerequisite_state';
      end if;
      new.hidden_by := null;
      new.hidden_reason := null;
    else
      new.hidden_at := old.hidden_at;
    end if;
  else
    new.hidden_by := old.hidden_by;
    if new.hidden_reason is distinct from old.hidden_reason and not (is_admin or is_post_teacher) then
      raise exception 'only a teacher or admin gives a hiding reason' using errcode = 'insufficient_privilege';
    end if;
  end if;
  if new.takedown_reason is distinct from old.takedown_reason and new.moderation_state = old.moderation_state then
    raise exception 'a takedown reason is given with the takedown' using errcode = 'insufficient_privilege';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
RESET ROLE;
