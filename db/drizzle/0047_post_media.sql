SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."post_media" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"post_id" uuid NOT NULL,
	"media_asset_id" uuid NOT NULL,
	"position" smallint NOT NULL,
	CONSTRAINT "post_media_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "post_media_position" UNIQUE("institute_id","post_id","position"),
	CONSTRAINT "post_media_position_check" CHECK (position between 1 and 20)
);
--> statement-breakpoint
ALTER TABLE "app"."post_media" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."post_media" ADD CONSTRAINT "post_media_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."post_media" ADD CONSTRAINT "post_media_institute_id_post_id_posts_institute_id_id_fk" FOREIGN KEY ("institute_id","post_id") REFERENCES "app"."posts"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."post_media" ADD CONSTRAINT "post_media_institute_id_media_asset_id_media_assets_institute_id_id_fk" FOREIGN KEY ("institute_id","media_asset_id") REFERENCES "app"."media_assets"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "post_media_asset" ON "app"."post_media" USING btree ("institute_id","media_asset_id");--> statement-breakpoint
CREATE POLICY "iso" ON "app"."post_media" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "post_media_read" ON "app"."post_media" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (exists (select from app.posts p where p.id = post_id));--> statement-breakpoint
CREATE POLICY "post_media_attach" ON "app"."post_media" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (exists (select from app.posts p where p.id = post_id
            and (p.author_persona_id = (select app.current_persona_id())
              or p.author_user_id = (select app.current_user_id()))
            and (p.moderation_state = 'draft' or p.created_at = now()))
          and exists (select from app.media_assets m where m.id = media_asset_id
            and m.uploaded_by = (select app.current_user_id())));--> statement-breakpoint
CREATE POLICY "post_media_remove" ON "app"."post_media" AS PERMISSIVE FOR DELETE TO "tazkiyah_app" USING ((select app.has_role('admin')) or exists (select from app.posts p where p.id = post_id
          and ((p.class_id is not null and app.is_class_teacher(p.class_id))
            or (p.class_id is null and p.scope <> 'community' and (select app.has_role('teacher'))))));
--> statement-breakpoint
grant select, insert, delete on app.post_media to tazkiyah_app;
--> statement-breakpoint
-- The students a piece of media is about: its uploader if a student, and the
-- student behind every persona post it is attached to (04 §11.7, 07 §12.1).
create function app.media_students(p_institute_id uuid, p_media_id uuid, p_uploaded_by uuid)
returns setof uuid
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select r.user_id from app.user_roles r
  where r.institute_id = p_institute_id and r.user_id = p_uploaded_by and r.role = 'student'
  union
  select l.user_id from app.post_media pm
  join app.posts p on p.institute_id = pm.institute_id and p.id = pm.post_id
  join app.persona_links l on l.institute_id = p.institute_id and l.persona_id = p.author_persona_id
  where pm.institute_id = p_institute_id and pm.media_asset_id = p_media_id
$function$;
--> statement-breakpoint
revoke all on function app.media_students(uuid, uuid, uuid) from public;
--> statement-breakpoint
-- Media showing a face is public only with `face` consent for every student
-- it is about (REQ-CHS-001). Making such media public is refused; raising the
-- face flag on public media makes it private instead, so the flag can always
-- be raised. It runs for the owner too.
create function app.media_face_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.visibility = 'public' and new.shows_face and exists (
    select from app.media_students(new.institute_id, new.id, new.uploaded_by) s(user_id)
    where not app.consent_active(s.user_id, 'face'))
  then
    if tg_op = 'UPDATE' and old.visibility = 'public' and not old.shows_face then
      new.visibility := 'private';
    else
      raise exception 'media showing a student''s face needs face consent to be public'
        using errcode = 'insufficient_privilege';
    end if;
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger media_face_rules before insert or update of visibility, shows_face, uploaded_by on app.media_assets
for each row execute function app.media_face_rules();
--> statement-breakpoint
-- Attaching media: a post upload that is not rejected or deleted, never to a
-- poll (07 §11.1) or a taken-down post, and public face media only when the
-- post's student has face consent.
create function app.post_media_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  media app.media_assets;
  post app.posts;
  student uuid;
begin
  if new.institute_id is distinct from app.current_institute_id() and app.current_institute_id() is not null then
    raise exception 'post media belongs to the current institute' using errcode = 'insufficient_privilege';
  end if;
  select * into media from app.media_assets m where m.institute_id = new.institute_id and m.id = new.media_asset_id;
  select * into post from app.posts p where p.institute_id = new.institute_id and p.id = new.post_id;
  if media.purpose is distinct from 'post' or media.status not in ('pending', 'ready') then
    raise exception 'only a post upload can be attached' using errcode = 'check_violation';
  end if;
  if post.post_type = 'poll' then
    raise exception 'a poll has no media' using errcode = 'check_violation';
  end if;
  if post.moderation_state = 'taken_down' then
    raise exception 'the post was taken down' using errcode = 'object_not_in_prerequisite_state';
  end if;
  if media.visibility = 'public' and media.shows_face then
    select l.user_id into student from app.persona_links l
    where l.institute_id = post.institute_id and l.persona_id = post.author_persona_id;
    if student is not null and not app.consent_active(student, 'face') then
      raise exception 'media showing a student''s face needs face consent to be public'
        using errcode = 'insufficient_privilege';
    end if;
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger post_media_rules before insert on app.post_media
for each row execute function app.post_media_rules();
--> statement-breakpoint
-- The face flag is set by the uploader or a teacher (04 §11.7). Anyone of
-- them may raise it; only staff clear it: the uploader if staff, the
-- uploader's teachers and admins, so a student cannot undo a teacher's
-- flag (D-135). Returns whether the flag now has the asked value.
create function app.set_media_shows_face(p_media_id uuid, p_shows_face boolean) returns boolean
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  media app.media_assets;
  me uuid := app.current_user_id();
begin
  select * into media from app.media_assets m
  where m.institute_id = app.current_institute_id() and m.id = p_media_id and m.status <> 'deleted' for update;
  if media.id is null or p_shows_face is null then
    return false;
  end if;
  if not (app.has_role('admin')
    or (app.has_role('teacher') and media.uploaded_by is not null and app.is_teacher_of(media.uploaded_by))
    or (media.uploaded_by = me and (p_shows_face or app.is_staff())))
  then
    return false;
  end if;
  update app.media_assets m set shows_face = p_shows_face
  where m.institute_id = media.institute_id and m.id = media.id;
  return true;
end
$function$;
--> statement-breakpoint
revoke all on function app.set_media_shows_face(uuid, boolean) from public;
--> statement-breakpoint
grant execute on function app.set_media_shows_face(uuid, boolean) to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
