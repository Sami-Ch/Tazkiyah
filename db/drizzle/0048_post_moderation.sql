SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- A teacher the admin chose to widen post scopes (04 §7.2, REQ-MOD-007).
create function app.can_widen_scope() returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
return app.has_role('teacher') and exists (select from app.user_roles r
  where r.institute_id = app.current_institute_id() and r.user_id = app.current_user_id()
    and r.role = 'teacher' and r.can_widen_scope);
--> statement-breakpoint
revoke all on function app.can_widen_scope() from public;
--> statement-breakpoint
grant execute on function app.can_widen_scope() to tazkiyah_app;
--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "target_scope" text;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "submitted_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "approved_by" uuid;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "approved_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "hidden_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "hidden_by" uuid;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "hidden_reason" text;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "taken_down_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "taken_down_by" uuid;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD COLUMN "takedown_reason" text;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_approved_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","approved_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_hidden_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","hidden_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_institute_id_taken_down_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","taken_down_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "posts_approved_by" ON "app"."posts" USING btree ("institute_id","approved_by") WHERE approved_by is not null;--> statement-breakpoint
CREATE INDEX "posts_hidden_by" ON "app"."posts" USING btree ("institute_id","hidden_by") WHERE hidden_by is not null;--> statement-breakpoint
CREATE INDEX "posts_taken_down_by" ON "app"."posts" USING btree ("institute_id","taken_down_by") WHERE taken_down_by is not null;--> statement-breakpoint
ALTER TABLE "app"."posts" ADD CONSTRAINT "posts_moderation_check" CHECK ((target_scope is null or target_scope in ('madrasa', 'public', 'community'))
          and (target_scope is not null) = (moderation_state in ('submitted', 'approved'))
          and (submitted_at is not null) = (moderation_state in ('submitted', 'approved'))
          and (approved_at is null) = (approved_by is null)
          and (moderation_state <> 'approved' or approved_at is not null)
          and (hidden_at is not null or (hidden_by is null and hidden_reason is null))
          and (hidden_reason is null or hidden_reason ~ '[^[:space:]]')
          and (moderation_state = 'taken_down') = (taken_down_at is not null)
          and (taken_down_at is not null or (taken_down_by is null and takedown_reason is null))
          and (taken_down_at is null or (takedown_reason is not null and takedown_reason ~ '[^[:space:]]')));--> statement-breakpoint
CREATE POLICY "posts_moderate" ON "app"."posts" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING ((select app.has_role('admin'))
          or author_persona_id = (select app.current_persona_id())
          or author_user_id = (select app.current_user_id())
          or (class_id is not null and app.is_class_teacher(class_id))
          or ((class_id is null or scope = 'madrasa') and scope <> 'community' and (select app.has_role('teacher')))
          or (author_user_id is not null and (select app.has_role('editor')))
          or (target_scope = 'madrasa' and (select app.can_widen_scope()))) WITH CHECK (true);--> statement-breakpoint
ALTER POLICY "posts_read" ON "app"."posts" TO tazkiyah_app USING ((select app.has_role('admin'))
          or (moderation_state <> 'taken_down' and (author_persona_id = (select app.current_persona_id())
            or author_user_id = (select app.current_user_id())))
          or (class_id is not null and app.is_class_teacher(class_id))
          or ((class_id is null or scope = 'madrasa') and scope <> 'community' and (select app.has_role('teacher')))
          or (hidden_at is null and moderation_state in ('published', 'submitted', 'approved')
            and ((scope = 'class' and app.is_class_member(class_id))
              or (scope in ('madrasa', 'public') and (select app.is_member()))))
          or (moderation_state in ('submitted', 'approved')
            and ((target_scope = 'public' and author_user_id is not null and (select app.has_role('editor')))
              or (target_scope = 'madrasa' and (select app.can_widen_scope())))));
--> statement-breakpoint
-- The moderation path (04 §11.3). Content edits stay closed until P3-E3-T11.
grant update (moderation_state, target_scope, hidden_at, hidden_reason, takedown_reason) on app.posts
to tazkiyah_app;
--> statement-breakpoint
-- Who may approve a request to widen a post (04 §11.3, 07 §8.2, D-029, D-136):
-- to the madrasa, an admin or a teacher the admin chose (REQ-MOD-007); to the
-- public, for a student's post an admin or a class teacher of the post's
-- class (any class of the student for a post outside a class, REQ-MOD-003),
-- for staff work an editor or admin (REQ-TCH-004). Nobody approves their own.
create function app.may_approve_post(p_post app.posts, p_student uuid) returns boolean
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  actor uuid := app.current_user_id();
begin
  if actor is null or actor = p_post.author_user_id or actor = p_student then
    return false;
  end if;
  if p_post.target_scope = 'madrasa' then
    return app.has_role('admin') or app.can_widen_scope();
  elsif p_post.target_scope = 'public' and p_student is not null then
    return app.has_role('admin') or (app.has_role('teacher') and case when p_post.class_id is not null
      then app.is_class_teacher(p_post.class_id) else app.is_teacher_of(p_student) end);
  elsif p_post.target_scope = 'public' then
    return app.has_role('admin') or app.has_role('editor');
  end if;
  return false;
end
$function$;
--> statement-breakpoint
revoke all on function app.may_approve_post(app.posts, uuid) from public;
--> statement-breakpoint
-- Every change of a post's moderation state, hide or takedown passes here,
-- for the owner too. It fills who and when itself. A step with no user is a
-- system step (report threshold, consent withdrawal) and may only hide or
-- take down.
create function app.posts_moderation() returns trigger
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

  -- Publishing an approved request: the post must be visible and, for a
  -- student's public work, consent still active (REQ-CHS-005). Otherwise it
  -- waits as approved.
  if publish then
    if new.hidden_at is null and not (student is not null and new.target_scope = 'public'
      and not app.consent_active(student, 'public_work'))
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
create trigger posts_moderation before update on app.posts
for each row execute function app.posts_moderation();
--> statement-breakpoint
RESET ROLE;
