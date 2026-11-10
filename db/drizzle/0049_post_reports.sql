SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Whether the caller moderates a post: an admin, the class teacher of a
-- class post, or any teacher for a post in madrasa scope or outside a class
-- (04 §11.3, 07 §8.4, D-136).
create function app.moderates_post(p_post_id uuid) returns boolean
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  return app.has_role('admin') or (app.has_role('teacher') and exists (select from app.posts p
    where p.institute_id = app.current_institute_id() and p.id = p_post_id and p.scope <> 'community'
      and (p.class_id is null or p.scope = 'madrasa' or app.is_class_teacher(p.class_id))));
end
$function$;
--> statement-breakpoint
revoke all on function app.moderates_post(uuid) from public;
--> statement-breakpoint
grant execute on function app.moderates_post(uuid) to tazkiyah_app;
--> statement-breakpoint
CREATE TABLE "app"."post_reports" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"post_id" uuid NOT NULL,
	"reporter_user_id" uuid,
	"reason" text NOT NULL,
	"note" text,
	"status" text DEFAULT 'open' NOT NULL,
	"handled_by" uuid,
	"handled_at" timestamp with time zone,
	"outcome_note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "post_reports_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "post_reports_reason_check" CHECK (reason in ('personal_details', 'face_or_name', 'unkind', 'wrong_information', 'other')),
	CONSTRAINT "post_reports_note_check" CHECK ((note is null or (length(note) between 1 and 300 and note ~ '[^[:space:]]'))
          and (reason <> 'other' or note is not null)),
	CONSTRAINT "post_reports_status_check" CHECK (status in ('open', 'actioned', 'dismissed')
          and (status = 'open') = (handled_at is null)
          and (handled_at is not null or (handled_by is null and outcome_note is null))
          and (outcome_note is null or (length(outcome_note) between 1 and 1000 and outcome_note ~ '[^[:space:]]')))
);
--> statement-breakpoint
ALTER TABLE "app"."post_reports" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."post_reports" ADD CONSTRAINT "post_reports_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."post_reports" ADD CONSTRAINT "post_reports_institute_id_post_id_posts_institute_id_id_fk" FOREIGN KEY ("institute_id","post_id") REFERENCES "app"."posts"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."post_reports" ADD CONSTRAINT "post_reports_institute_id_reporter_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","reporter_user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."post_reports" ADD CONSTRAINT "post_reports_institute_id_handled_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","handled_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "post_reports_post" ON "app"."post_reports" USING btree ("institute_id","post_id");--> statement-breakpoint
CREATE UNIQUE INDEX "post_reports_one_open" ON "app"."post_reports" USING btree ("institute_id","post_id","reporter_user_id") WHERE status = 'open';--> statement-breakpoint
CREATE INDEX "post_reports_open_queue" ON "app"."post_reports" USING btree ("institute_id","created_at") WHERE status = 'open';--> statement-breakpoint
CREATE INDEX "post_reports_reporter" ON "app"."post_reports" USING btree ("institute_id","reporter_user_id") WHERE reporter_user_id is not null;--> statement-breakpoint
CREATE INDEX "post_reports_handled_by" ON "app"."post_reports" USING btree ("institute_id","handled_by") WHERE handled_by is not null;--> statement-breakpoint
CREATE POLICY "iso" ON "app"."post_reports" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "post_reports_read" ON "app"."post_reports" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (reporter_user_id = (select app.current_user_id()) or app.moderates_post(post_id));--> statement-breakpoint
CREATE POLICY "post_reports_file" ON "app"."post_reports" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (reporter_user_id = (select app.current_user_id()) and status = 'open'
          and ((select app.has_role('student')) or (select app.has_role('teacher'))
            or (select app.has_role('editor')) or (select app.has_role('admin')))
          and exists (select from app.posts p where p.id = post_id));--> statement-breakpoint
CREATE POLICY "post_reports_handle" ON "app"."post_reports" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING (app.moderates_post(post_id)) WITH CHECK (app.moderates_post(post_id));
--> statement-breakpoint
grant select, insert on app.post_reports to tazkiyah_app;
--> statement-breakpoint
grant update (status, outcome_note) on app.post_reports to tazkiyah_app;
--> statement-breakpoint
-- A report is filed open and closed once, by someone who moderates the post;
-- what was reported never changes. It runs for the owner too.
create function app.post_reports_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.institute_id is distinct from app.current_institute_id() and app.current_institute_id() is not null then
    raise exception 'a report belongs to the current institute' using errcode = 'insufficient_privilege';
  end if;
  if tg_op = 'INSERT' then
    new.status := 'open';
    new.handled_by := null;
    new.handled_at := null;
    new.outcome_note := null;
    new.created_at := now();
    return new;
  end if;
  if (new.post_id, new.reporter_user_id, new.reason, new.note, new.created_at)
    is distinct from (old.post_id, old.reporter_user_id, old.reason, old.note, old.created_at)
  then
    raise exception 'a report keeps what was reported' using errcode = 'insufficient_privilege';
  end if;
  if old.status <> 'open' then
    raise exception 'the report is already closed' using errcode = 'object_not_in_prerequisite_state';
  end if;
  if new.status = 'open' then
    raise exception 'a report is closed as actioned or dismissed' using errcode = 'check_violation';
  end if;
  if app.current_user_id() is not null and not app.moderates_post(old.post_id) then
    raise exception 'only a moderator of the post closes a report' using errcode = 'insufficient_privilege';
  end if;
  new.handled_by := app.current_user_id();
  new.handled_at := now();
  return new;
end
$function$;
--> statement-breakpoint
create trigger post_reports_rules before insert or update on app.post_reports
for each row execute function app.post_reports_rules();
--> statement-breakpoint
-- An approved request waits while the post has an open report.
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
-- The moderation queue (07 §8.5, 05 §8.11, REQ-MOD-005): open reports per
-- post, public requests, requests to widen to the madrasa, approved posts
-- still waiting, and taken-down posts. It reads as the caller, so each person
-- sees only what the post and report policies let them moderate, and report
-- items only on posts they moderate; students see nothing. Reporters are never listed, only counts and reasons. Priority
-- follows 07 §8.5; address flags (P3-E3-T12) and media checks (P3-E4-T72)
-- join when built. Only teachers, editors (teacher work) and admins get rows.
create view app.moderation_queue with (security_invoker = true) as
select q.* from (
select p.institute_id, p.id as post_id, p.thread_id, p.class_id, p.scope, p.moderation_state, 'report' as item,
  case when bool_or(r.reason in ('personal_details', 'face_or_name')) then 1 else 3 end as priority,
  count(*)::int as report_count, array_agg(distinct r.reason order by r.reason) as reasons,
  min(r.created_at) as since
from app.post_reports r
join app.posts p on p.institute_id = r.institute_id and p.id = r.post_id
where r.status = 'open' and app.moderates_post(p.id)
group by p.institute_id, p.id
union all
select p.institute_id, p.id, p.thread_id, p.class_id, p.scope, p.moderation_state,
  case when p.moderation_state = 'approved' then 'approved_waiting'
    when p.target_scope = 'madrasa' then 'widen_request' else 'public_request' end,
  case when p.target_scope = 'madrasa' then 6 else 5 end, 0, '{}', p.submitted_at
from app.posts p
where p.moderation_state in ('submitted', 'approved')
union all
select p.institute_id, p.id, p.thread_id, p.class_id, p.scope, p.moderation_state, 'taken_down', 8, 0, '{}',
  p.taken_down_at
from app.posts p
where p.moderation_state = 'taken_down'
) q
where app.has_role('admin') or app.has_role('teacher') or app.has_role('editor');
--> statement-breakpoint
grant select on app.moderation_queue to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
