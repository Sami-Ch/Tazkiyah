SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "is_verified" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "verified_by" uuid;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "verified_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."threads" ADD COLUMN "article_post_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_verified_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","verified_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."threads" ADD CONSTRAINT "threads_institute_id_article_post_id_posts_institute_id_id_fk" FOREIGN KEY ("institute_id","article_post_id") REFERENCES "app"."posts"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "posts_verified_by" ON "app"."posts" USING btree ("institute_id","verified_by") WHERE verified_by is not null;--> statement-breakpoint
CREATE UNIQUE INDEX "threads_article_post" ON "app"."threads" USING btree ("institute_id","article_post_id") WHERE article_post_id is not null;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_verified_check" CHECK ((is_verified = (verified_by is not null)) and (is_verified = (verified_at is not null))
          and (not is_verified or (post_type = 'article' and author_user_id is not null)));
--> statement-breakpoint
-- The verified mark and the thread's article link are set only by
-- app.make_verified_article (07 §9.1). This trigger is not a definer: it sees
-- the runtime role on a direct write, and the owner inside the function.
create function app.verified_article_guard() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  -- Each branch reads a field only its own table has.
  if current_user <> 'tazkiyah_app' then
    return new;
  elsif tg_table_name = 'posts' then
    if new.is_verified or new.verified_by is not null or new.verified_at is not null then
      raise exception 'only a teacher''s verification marks an article' using errcode = 'insufficient_privilege';
    end if;
  elsif new.article_post_id is not null then
    raise exception 'a thread gets its article through verification' using errcode = 'insufficient_privilege';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger posts_verified_guard before insert on app.posts
for each row execute function app.verified_article_guard();
--> statement-breakpoint
create trigger threads_verified_guard before insert on app.threads
for each row execute function app.verified_article_guard();
--> statement-breakpoint
-- A teacher turns a thread into a verified article (REQ-TCH-002, 07 §9.1):
-- any teacher of the thread's class, any teacher for a madrasa thread (with
-- the teacher hub on, as for every staff post outside a class), or an admin.
-- The article is a new `article` post by the teacher in the thread's scope,
-- live at once, with the verified mark (REQ-TCH-003). One article per
-- thread. Returns the article's id, or null when the caller may not make it.
create function app.make_verified_article(p_thread_id uuid, p_title text, p_body text, p_language text)
returns uuid
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  actor uuid := app.current_user_id();
  t app.threads;
  article uuid;
begin
  select * into t from app.threads th
  where th.institute_id = app.current_institute_id() and th.id = p_thread_id for update;
  if actor is null or t.id is null or t.article_post_id is not null or t.scope = 'community' then
    return null;
  end if;
  if not (app.has_role('admin')
    or (app.has_role('teacher') and (t.class_id is null or app.is_class_teacher(t.class_id))))
  then
    return null;
  end if;
  if t.class_id is null and not app.module_enabled('teacher_hub') then
    return null;
  end if;
  insert into app.posts (institute_id, thread_id, post_type, language, title, body, author_user_id,
    is_verified, verified_by, verified_at)
  values (t.institute_id, t.id, 'article', p_language, p_title, p_body, actor, true, actor, now())
  returning id into article;
  update app.threads th set article_post_id = article where th.institute_id = t.institute_id and th.id = t.id;
  return article;
end
$function$;
--> statement-breakpoint
revoke all on function app.make_verified_article(uuid, text, text, text) from public;
--> statement-breakpoint
grant execute on function app.make_verified_article(uuid, text, text, text) to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
