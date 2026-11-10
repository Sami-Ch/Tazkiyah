SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."posts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"thread_id" uuid NOT NULL,
	"parent_post_id" uuid,
	"post_type" text NOT NULL,
	"language" text NOT NULL,
	"title" text,
	"body" text,
	"scope" text NOT NULL,
	"class_id" uuid,
	"moderation_state" text DEFAULT 'published' NOT NULL,
	"author_persona_id" uuid,
	"author_user_id" uuid,
	"published_at" timestamp with time zone,
	"poll_closes_at" timestamp with time zone,
	"poll_multiple" boolean DEFAULT false NOT NULL,
	"edited_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "posts_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "posts_type_check" CHECK (post_type in ('message', 'question', 'answer', 'poll', 'article', 'video', 'vlog', 'audio', 'slides')),
	CONSTRAINT "posts_language_check" CHECK (language ~ '^[a-z]{2,3}$'),
	CONSTRAINT "posts_text_check" CHECK ((title is null or (length(title) between 1 and 200 and title ~ '[^[:space:]]'))
          and (body is null or body ~ '[^[:space:]]')
          and (post_type <> 'article' or title is not null)),
	CONSTRAINT "posts_scope_check" CHECK (scope in ('class', 'madrasa', 'public', 'community') and (scope <> 'class' or class_id is not null)),
	CONSTRAINT "posts_state_check" CHECK (moderation_state in ('draft', 'submitted', 'approved', 'published', 'taken_down')),
	CONSTRAINT "posts_author_check" CHECK ((author_persona_id is null) <> (author_user_id is null)),
	CONSTRAINT "posts_poll_check" CHECK (post_type = 'poll' or (poll_closes_at is null and not poll_multiple))
);
--> statement-breakpoint
ALTER TABLE "app"."posts" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."threads" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"class_id" uuid,
	"scope" text NOT NULL,
	"title" text,
	"language" text NOT NULL,
	"author_persona_id" uuid,
	"author_user_id" uuid,
	"first_post_id" uuid,
	"last_post_at" timestamp with time zone DEFAULT now() NOT NULL,
	"reply_count" integer DEFAULT 0 NOT NULL,
	"locked_at" timestamp with time zone,
	"locked_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "threads_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "threads_scope_check" CHECK (scope in ('class', 'madrasa', 'public', 'community') and (scope <> 'class' or class_id is not null)),
	CONSTRAINT "threads_author_check" CHECK ((author_persona_id is null) <> (author_user_id is null)),
	CONSTRAINT "threads_title_check" CHECK (title is null or (length(title) between 1 and 200 and title ~ '[^[:space:]]')),
	CONSTRAINT "threads_language_check" CHECK (language ~ '^[a-z]{2,3}$'),
	CONSTRAINT "threads_lock_check" CHECK ((locked_at is null) = (locked_by is null) and reply_count >= 0)
);
--> statement-breakpoint
ALTER TABLE "app"."threads" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_thread_id_threads_institute_id_id_fk" FOREIGN KEY ("institute_id","thread_id") REFERENCES "app"."threads"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_parent_post_id_posts_institute_id_id_fk" FOREIGN KEY ("institute_id","parent_post_id") REFERENCES "app"."posts"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_class_id_classes_institute_id_id_fk" FOREIGN KEY ("institute_id","class_id") REFERENCES "app"."classes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_author_persona_id_personas_institute_id_id_fk" FOREIGN KEY ("institute_id","author_persona_id") REFERENCES "app"."personas"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_author_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","author_user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."threads" ADD CONSTRAINT "threads_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."threads" ADD CONSTRAINT "threads_institute_id_class_id_classes_institute_id_id_fk" FOREIGN KEY ("institute_id","class_id") REFERENCES "app"."classes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."threads" ADD CONSTRAINT "threads_institute_id_author_persona_id_personas_institute_id_id_fk" FOREIGN KEY ("institute_id","author_persona_id") REFERENCES "app"."personas"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."threads" ADD CONSTRAINT "threads_institute_id_author_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","author_user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."threads" ADD CONSTRAINT "threads_institute_id_first_post_id_posts_institute_id_id_fk" FOREIGN KEY ("institute_id","first_post_id") REFERENCES "app"."posts"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."threads" ADD CONSTRAINT "threads_institute_id_locked_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","locked_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "posts_thread" ON "app"."posts" USING btree ("institute_id","thread_id","created_at");--> statement-breakpoint
CREATE INDEX "posts_public_recent" ON "app"."posts" USING btree ("institute_id","published_at" DESC NULLS LAST) WHERE scope = 'public' and moderation_state = 'published';--> statement-breakpoint
CREATE INDEX "posts_author_persona" ON "app"."posts" USING btree ("institute_id","author_persona_id");--> statement-breakpoint
CREATE INDEX "posts_author_user" ON "app"."posts" USING btree ("institute_id","author_user_id");--> statement-breakpoint
CREATE INDEX "posts_parent" ON "app"."posts" USING btree ("institute_id","parent_post_id");--> statement-breakpoint
CREATE INDEX "posts_class" ON "app"."posts" USING btree ("institute_id","class_id");--> statement-breakpoint
CREATE INDEX "posts_approval_queue" ON "app"."posts" USING btree ("institute_id","moderation_state") WHERE moderation_state in ('submitted', 'approved');--> statement-breakpoint
CREATE INDEX "threads_class_recent" ON "app"."threads" USING btree ("institute_id","class_id","last_post_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "threads_scope_recent" ON "app"."threads" USING btree ("institute_id","scope","last_post_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "threads_author_persona" ON "app"."threads" USING btree ("institute_id","author_persona_id");--> statement-breakpoint
CREATE INDEX "threads_author_user" ON "app"."threads" USING btree ("institute_id","author_user_id");--> statement-breakpoint
CREATE INDEX "threads_first_post" ON "app"."threads" USING btree ("institute_id","first_post_id");--> statement-breakpoint
CREATE INDEX "threads_locked_by" ON "app"."threads" USING btree ("institute_id","locked_by");--> statement-breakpoint
CREATE POLICY "iso" ON "app"."posts" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "posts_read" ON "app"."posts" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin'))
          or (moderation_state <> 'taken_down' and (author_persona_id = (select app.current_persona_id())
            or author_user_id = (select app.current_user_id())))
          or (class_id is not null and app.is_class_teacher(class_id))
          or (class_id is null and scope <> 'community' and (select app.has_role('teacher')))
          or (moderation_state in ('published', 'submitted', 'approved')
            and ((scope = 'class' and app.is_class_member(class_id))
              or (scope in ('madrasa', 'public') and (select app.is_member())))));--> statement-breakpoint
CREATE POLICY "posts_write" ON "app"."posts" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (moderation_state in ('draft', 'published') and scope in ('class', 'madrasa') and (
  author_persona_id = (select app.current_persona_id()) and author_user_id is null
  and (select app.module_enabled('student_hub'))
  and ((scope = 'class' and app.is_class_member(class_id)) or scope = 'madrasa')
) or (
  author_user_id = (select app.current_user_id()) and author_persona_id is null
  and ((scope = 'class' and (app.is_class_teacher(class_id) or (select app.has_role('admin'))))
    or (scope = 'madrasa' and ((select app.has_role('teacher')) or (select app.has_role('admin')))
      and (select app.module_enabled('teacher_hub'))))
));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."threads" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "threads_read" ON "app"."threads" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin'))
          or author_persona_id = (select app.current_persona_id())
          or author_user_id = (select app.current_user_id())
          or (scope = 'class' and app.is_class_member(class_id))
          or (scope in ('madrasa', 'public') and (select app.is_member())));--> statement-breakpoint
CREATE POLICY "threads_start" ON "app"."threads" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (scope in ('class', 'madrasa') and (
  author_persona_id = (select app.current_persona_id()) and author_user_id is null
  and (select app.module_enabled('student_hub'))
  and ((scope = 'class' and app.is_class_member(class_id)) or scope = 'madrasa')
) or (
  author_user_id = (select app.current_user_id()) and author_persona_id is null
  and ((scope = 'class' and (app.is_class_teacher(class_id) or (select app.has_role('admin'))))
    or (scope = 'madrasa' and ((select app.has_role('teacher')) or (select app.has_role('admin')))
      and (select app.module_enabled('teacher_hub'))))
));
--> statement-breakpoint
-- Threads and posts are read and written under the scope rules above. Nobody
-- edits or deletes them yet: editing with kept versions is P3-E3-T11, and
-- moderation changes are P3-E5-T40, so no change can skip their checks.
grant select, insert on app.threads, app.posts to tazkiyah_app;
--> statement-breakpoint
-- Rules every hub author follows (04 §7.4, §11.2): a student holds no user
-- authorship and writes only as an active persona; class threads stay closed
-- once the class is archived (07 §4.5); `community` is reserved while the
-- institute has not switched it on (REQ-MIR-004).
create function app.hub_author_rules(p_institute_id uuid, p_scope text, p_class_id uuid,
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
end
$function$;
--> statement-breakpoint
revoke all on function app.hub_author_rules(uuid, text, uuid, uuid, uuid) from public;
--> statement-breakpoint
create function app.threads_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  perform app.hub_author_rules(new.institute_id, new.scope, new.class_id, new.author_persona_id, new.author_user_id);
  if tg_op = 'INSERT' then
    new.first_post_id := null;
    new.reply_count := 0;
    new.last_post_at := now();
    new.locked_at := null;
    new.locked_by := null;
    new.created_at := now();
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger threads_rules before insert or update of scope, class_id on app.threads
for each row execute function app.threads_rules();
--> statement-breakpoint
-- A post takes its thread's scope and class (04 §11.2). A reply's parent is in
-- the same thread, and an answer replies to a question (REQ-STU-006). A locked
-- thread takes posts only from staff.
create function app.posts_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  t app.threads;
  parent_type text;
begin
  if tg_op = 'INSERT' then
    select * into t from app.threads th
    where th.institute_id = new.institute_id and th.id = new.thread_id for update;
    if t.id is null then
      raise exception 'the thread does not exist' using errcode = 'foreign_key_violation';
    end if;
    new.scope := t.scope;
    new.class_id := t.class_id;
    if t.locked_at is not null and new.author_user_id is null then
      raise exception 'the thread is locked' using errcode = 'object_not_in_prerequisite_state';
    end if;
    if new.parent_post_id is not null then
      select p.post_type into parent_type from app.posts p
      where p.institute_id = new.institute_id and p.id = new.parent_post_id and p.thread_id = new.thread_id;
      if parent_type is null then
        raise exception 'a reply stays in its thread' using errcode = 'check_violation';
      end if;
    end if;
    if new.post_type = 'answer' and parent_type is distinct from 'question' then
      raise exception 'an answer replies to a question' using errcode = 'check_violation';
    end if;
    if new.poll_closes_at is not null and new.poll_closes_at <= now() then
      raise exception 'a poll closes in the future' using errcode = 'check_violation';
    end if;
    new.published_at := case when new.moderation_state = 'published' then now() end;
    new.edited_at := null;
    new.created_at := now();
  end if;
  perform app.hub_author_rules(new.institute_id, new.scope, new.class_id, new.author_persona_id, new.author_user_id);
  return new;
end
$function$;
--> statement-breakpoint
create trigger posts_rules before insert or update of scope on app.posts
for each row execute function app.posts_rules();
--> statement-breakpoint
-- The thread keeps its first post, last activity and reply count for lists.
create function app.posts_touch_thread() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  update app.threads th set
    first_post_id = coalesce(th.first_post_id, new.id),
    reply_count = th.reply_count
      + case when th.first_post_id is not null and new.moderation_state = 'published' then 1 else 0 end,
    last_post_at = case when new.moderation_state = 'published' then greatest(th.last_post_at, new.created_at)
      else th.last_post_at end
  where th.institute_id = new.institute_id and th.id = new.thread_id;
  return null;
end
$function$;
--> statement-breakpoint
create trigger posts_touch_thread after insert on app.posts
for each row execute function app.posts_touch_thread();
--> statement-breakpoint
RESET ROLE;
