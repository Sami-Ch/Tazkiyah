SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."poll_options" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"post_id" uuid NOT NULL,
	"label" text NOT NULL,
	"position" smallint NOT NULL,
	CONSTRAINT "poll_options_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "poll_options_post_option" UNIQUE("institute_id","post_id","id"),
	CONSTRAINT "poll_options_position" UNIQUE("institute_id","post_id","position"),
	CONSTRAINT "poll_options_label_check" CHECK (length(label) between 1 and 80 and label = btrim(label) and label ~ '[^[:space:]]'),
	CONSTRAINT "poll_options_position_check" CHECK (position between 1 and 6)
);
--> statement-breakpoint
ALTER TABLE "app"."poll_options" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."poll_votes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"post_id" uuid NOT NULL,
	"option_id" uuid NOT NULL,
	"voter_user_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "poll_votes_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "poll_votes_one_per_option" UNIQUE("institute_id","option_id","voter_user_id")
);
--> statement-breakpoint
ALTER TABLE "app"."poll_votes" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."posts" DROP CONSTRAINT "posts_poll_check";--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "poll_max_choices" smallint;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "poll_results" text;--> statement-breakpoint
ALTER TABLE "app"."poll_options" ADD CONSTRAINT "poll_options_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."poll_options" ADD CONSTRAINT "poll_options_institute_id_post_id_posts_institute_id_id_fk" FOREIGN KEY ("institute_id","post_id") REFERENCES "app"."posts"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."poll_votes" ADD CONSTRAINT "poll_votes_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."poll_votes" ADD CONSTRAINT "poll_votes_institute_id_post_id_option_id_poll_options_institute_id_post_id_id_fk" FOREIGN KEY ("institute_id","post_id","option_id") REFERENCES "app"."poll_options"("institute_id","post_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."poll_votes" ADD CONSTRAINT "poll_votes_institute_id_voter_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","voter_user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "poll_votes_post_option" ON "app"."poll_votes" USING btree ("institute_id","post_id","option_id");--> statement-breakpoint
CREATE INDEX "poll_votes_voter" ON "app"."poll_votes" USING btree ("institute_id","voter_user_id","post_id");--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_poll_check" CHECK (case when post_type = 'poll' then poll_closes_at is not null
            and poll_results is not null and poll_results in ('after_voting', 'after_closing')
            and case when poll_multiple then coalesce(poll_max_choices between 2 and 6, false)
              else poll_max_choices is null end
          else poll_closes_at is null and not poll_multiple and poll_max_choices is null and poll_results is null end);--> statement-breakpoint
CREATE POLICY "iso" ON "app"."poll_options" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "poll_options_read" ON "app"."poll_options" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (exists (select from app.posts p where p.id = post_id));--> statement-breakpoint
CREATE POLICY "poll_options_add" ON "app"."poll_options" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (exists (select from app.posts p where p.id = post_id and p.post_type = 'poll'
          and (p.author_persona_id = (select app.current_persona_id())
            or p.author_user_id = (select app.current_user_id()))));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."poll_votes" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "poll_votes_read" ON "app"."poll_votes" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (voter_user_id = (select app.current_user_id())
          or (select app.has_role('admin')) or app.is_teacher_of(voter_user_id));--> statement-breakpoint
CREATE POLICY "poll_votes_cast" ON "app"."poll_votes" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (voter_user_id = (select app.current_user_id())
          and (((select app.has_role('student')) and (select app.module_enabled('student_hub')))
            or (select app.has_role('teacher')) or (select app.has_role('admin')))
          and exists (select from app.posts p where p.id = post_id and p.post_type = 'poll'
            and p.moderation_state = 'published' and p.poll_closes_at > now()));--> statement-breakpoint
CREATE POLICY "poll_votes_withdraw" ON "app"."poll_votes" AS PERMISSIVE FOR DELETE TO "tazkiyah_app" USING (voter_user_id = (select app.current_user_id())
          and exists (select from app.posts p where p.id = post_id and p.post_type = 'poll'
            and p.moderation_state = 'published' and p.poll_closes_at > now()));
--> statement-breakpoint
-- Options are added with their poll and never changed (no update or delete,
-- as for posts, D-133). Votes are cast and taken back while the poll is open;
-- changing a vote is taking one back and casting another.
grant select, insert on app.poll_options to tazkiyah_app;
--> statement-breakpoint
grant select, insert, delete on app.poll_votes to tazkiyah_app;
--> statement-breakpoint
-- A poll closes 1 hour to 30 days after it is posted, 7 days by default
-- (07 §6.4). This runs before posts_rules, which checks the date is ahead.
create function app.posts_poll_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.post_type = 'poll' then
    new.poll_closes_at := coalesce(new.poll_closes_at, now() + interval '7 days');
    if new.poll_closes_at < now() + interval '1 hour' or new.poll_closes_at > now() + interval '30 days' then
      raise exception 'a poll closes between 1 hour and 30 days from now' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger posts_poll_rules before insert on app.posts
for each row execute function app.posts_poll_rules();
--> statement-breakpoint
-- Options belong to an open poll and stop changing at the first vote.
create function app.poll_options_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  poll app.posts;
begin
  if new.institute_id is distinct from app.current_institute_id() and app.current_institute_id() is not null then
    raise exception 'a poll option belongs to the current institute' using errcode = 'insufficient_privilege';
  end if;
  select * into poll from app.posts p
  where p.institute_id = new.institute_id and p.id = new.post_id for share;
  if poll.post_type is distinct from 'poll' then
    raise exception 'options belong to a poll' using errcode = 'check_violation';
  end if;
  if poll.moderation_state = 'taken_down' or poll.poll_closes_at <= now() then
    raise exception 'the poll is closed' using errcode = 'object_not_in_prerequisite_state';
  end if;
  if exists (select from app.poll_votes v where v.institute_id = new.institute_id and v.post_id = new.post_id) then
    raise exception 'options cannot change after the first vote' using errcode = 'object_not_in_prerequisite_state';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger poll_options_rules before insert on app.poll_options
for each row execute function app.poll_options_rules();
--> statement-breakpoint
-- At commit a poll has 2 to 6 options, and a multiple-choice maximum no larger
-- than the number of options (07 §6.4).
create function app.poll_options_count() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  poll_id uuid;
  options int;
  max_choices smallint;
begin
  -- Each branch reads a field only its own table has.
  if tg_table_name = 'posts' then
    poll_id := new.id;
  else
    poll_id := new.post_id;
  end if;
  select p.poll_max_choices into max_choices from app.posts p
  where p.institute_id = new.institute_id and p.id = poll_id and p.post_type = 'poll';
  if not found then
    return null;
  end if;
  select count(*) into options from app.poll_options o
  where o.institute_id = new.institute_id and o.post_id = poll_id;
  if options not between 2 and 6 then
    raise exception 'a poll has 2 to 6 options' using errcode = 'check_violation';
  end if;
  if max_choices > options then
    raise exception 'a poll allows at most as many choices as it has options' using errcode = 'check_violation';
  end if;
  return null;
end
$function$;
--> statement-breakpoint
create constraint trigger poll_options_count after insert on app.poll_options
deferrable initially deferred for each row execute function app.poll_options_count();
--> statement-breakpoint
create constraint trigger poll_options_count after insert on app.posts
deferrable initially deferred for each row when (new.post_type = 'poll')
execute function app.poll_options_count();
--> statement-breakpoint
-- One vote per user on a single-choice poll, up to the maximum on a
-- multiple-choice one, only while the poll is open and live, and never in an
-- archived class (07 §4.5, §6.4, REQ-STU-007).
create function app.poll_votes_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  poll app.posts;
  cast_votes int;
begin
  if new.institute_id is distinct from app.current_institute_id() and app.current_institute_id() is not null then
    raise exception 'a vote belongs to the current institute' using errcode = 'insufficient_privilege';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('poll_votes:' || new.post_id || ':' || new.voter_user_id, 0));
  select * into poll from app.posts p where p.institute_id = new.institute_id and p.id = new.post_id;
  if poll.post_type is distinct from 'poll' or poll.moderation_state <> 'published'
    or poll.poll_closes_at <= now()
  then
    raise exception 'the poll is not open' using errcode = 'object_not_in_prerequisite_state';
  end if;
  if poll.class_id is not null and exists (select from app.classes c
    where c.institute_id = poll.institute_id and c.id = poll.class_id and c.archived_at is not null)
  then
    raise exception 'an archived class is read-only' using errcode = 'object_not_in_prerequisite_state';
  end if;
  select count(*) into cast_votes from app.poll_votes v
  where v.institute_id = new.institute_id and v.post_id = new.post_id and v.voter_user_id = new.voter_user_id;
  if cast_votes >= coalesce(poll.poll_max_choices, 1) then
    raise exception 'no more choices are allowed in this poll' using errcode = 'unique_violation';
  end if;
  new.created_at := now();
  return new;
end
$function$;
--> statement-breakpoint
create trigger poll_votes_rules before insert on app.poll_votes
for each row execute function app.poll_votes_rules();
--> statement-breakpoint
-- A teacher or admin can close a poll early (07 §6.4): admins any poll,
-- teachers the polls of classes they teach and those outside a class, which
-- every teacher can see (04 §11.4). Returns whether an open poll was closed.
create function app.close_poll(p_post_id uuid) returns boolean
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  update app.posts p set poll_closes_at = now()
  where p.institute_id = app.current_institute_id() and p.id = p_post_id and p.post_type = 'poll'
    and p.poll_closes_at > now()
    and (app.has_role('admin')
      or (app.has_role('teacher') and p.scope <> 'community'
        and (p.class_id is null or app.is_class_teacher(p.class_id))));
  return found;
end
$function$;
--> statement-breakpoint
revoke all on function app.close_poll(uuid) from public;
--> statement-breakpoint
grant execute on function app.close_poll(uuid) to tazkiyah_app;
--> statement-breakpoint
-- Whether the caller may read a post. It runs as the caller, so the posts
-- read policy decides, also when a view owned by the schema owner calls it.
-- Written in PL/pgSQL so it is never inlined into the view.
create function app.can_see_post(p_post_id uuid) returns boolean
language plpgsql stable
set search_path = pg_catalog, pg_temp
as $function$
begin
  return exists (select from app.posts p where p.id = p_post_id);
end
$function$;
--> statement-breakpoint
revoke all on function app.can_see_post(uuid) from public;
--> statement-breakpoint
grant execute on function app.can_see_post(uuid) to tazkiyah_app;
--> statement-breakpoint
-- Votes per option, never voters (04 §6.5). A member who can see a live poll
-- sees counts once it closes, or after voting when the creator chose that.
-- Visitors see final counts of closed public polls only (07 §6.4), and not
-- while the module that holds the post is switched off.
create view public_api.poll_counts with (security_barrier = true) as
select o.post_id, o.id as option_id, o.position, o.label, p.poll_closes_at <= now() as is_closed,
  (select count(*) from app.poll_votes v
    where v.institute_id = o.institute_id and v.post_id = o.post_id and v.option_id = o.id)::int as votes,
  (select count(distinct v.voter_user_id) from app.poll_votes v
    where v.institute_id = o.institute_id and v.post_id = o.post_id)::int as voters
from app.posts p
join app.poll_options o on o.institute_id = p.institute_id and o.post_id = p.id
where p.institute_id = app.current_institute_id() and p.post_type = 'poll' and p.moderation_state = 'published'
  and ((p.scope = 'public' and p.poll_closes_at <= now()
      and app.module_enabled(case when p.author_persona_id is null then 'teacher_hub' else 'student_hub' end))
    or (app.can_see_post(p.id) and (p.poll_closes_at <= now()
      or (p.poll_results = 'after_voting' and exists (select from app.poll_votes mine
        where mine.institute_id = p.institute_id and mine.post_id = p.id
          and mine.voter_user_id = app.current_user_id())))));
--> statement-breakpoint
grant select on public_api.poll_counts to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
