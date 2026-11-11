SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Teachers on public pages (04 §6.5, REQ-TCH-001, REQ-PUB-005): the public
-- name, short profile and a public staff photo of active teachers who have a
-- public name, while the teacher hub is on. Never email, username or the
-- real full name.
create view public_api.public_teachers with (security_barrier = true) as
select u.id as teacher_id, u.public_name, u.public_bio,
  m.id as photo_media_id, m.storage_key as photo_storage_key, m.variants as photo_variants, m.alt_text as photo_alt_text
from app.users u
left join app.media_assets m on m.institute_id = u.institute_id and m.id = u.photo_media_id
  and m.purpose = 'staff_photo' and m.kind = 'image' and m.status = 'ready' and m.visibility = 'public'
where u.institute_id = app.current_institute_id() and u.status = 'active' and u.public_name is not null
  and exists (select from app.user_roles r where r.institute_id = u.institute_id and r.user_id = u.id and r.role = 'teacher')
  and app.module_enabled('teacher_hub');
--> statement-breakpoint
grant select on public_api.public_teachers to tazkiyah_app;
--> statement-breakpoint
-- Whether a persona's student has active public_work consent (04 §10.2,
-- REQ-CHS-005), by app.consent_active. It answers only yes or no for a
-- persona, so public views never read persona links (04 §7.5 test 5).
create function app.persona_work_may_show(p_persona_id uuid) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select exists (
    select from app.persona_links l
    where l.institute_id = app.current_institute_id() and l.persona_id = p_persona_id
      and app.consent_active(l.user_id, 'public_work'))
$function$;
--> statement-breakpoint
revoke all on function app.persona_work_may_show(uuid) from public;
--> statement-breakpoint
grant execute on function app.persona_work_may_show(uuid) to tazkiyah_app;
--> statement-breakpoint
-- Published public posts (04 §6.5, §10.2, §11.4, REQ-PUB-004, REQ-PUB-005):
-- live, not hidden, and in public scope. A student's post shows under the
-- persona's display name and illustrated avatar, only while the student hub
-- is on and the student's public_work consent is active (checked at read
-- time, so a withdrawal hides the post at once). Staff work shows under the
-- teacher's public name while the teacher hub is on. Verified articles carry
-- the verifier's public name (REQ-TCH-003). Never persona links, a student's user id, real name or
-- class. Media joins when public copies exist (P3-E4-T04).
create view public_api.public_posts with (security_barrier = true) as
select p.id, p.thread_id, p.parent_post_id, p.post_type, p.language, p.title, p.body, p.published_at,
  p.poll_closes_at, p.poll_multiple, p.poll_max_choices,
  case when p.author_persona_id is not null then 'persona' else 'teacher' end as author_kind,
  pe.display_name as persona_name, av.id as persona_avatar_media_id, av.storage_key as persona_avatar_storage_key,
  av.variants as persona_avatar_variants,
  case when p.author_user_id is not null then p.author_user_id end as teacher_id,
  au.public_name as teacher_name,
  p.is_verified, p.verified_at, vu.public_name as verified_by_name
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
grant select on public_api.public_posts to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
