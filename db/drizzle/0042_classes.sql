SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."class_members" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"class_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"member_role" text NOT NULL,
	"joined_at" date DEFAULT current_date NOT NULL,
	"ended_at" date,
	"added_by" uuid,
	CONSTRAINT "class_members_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "class_members_role_check" CHECK (member_role in ('student', 'teacher')),
	CONSTRAINT "class_members_dates_check" CHECK (ended_at is null or ended_at >= joined_at)
);
--> statement-breakpoint
ALTER TABLE "app"."class_members" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."classes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"name" "app"."localized_text" NOT NULL,
	"year_label" text,
	"created_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"archived_at" timestamp with time zone,
	CONSTRAINT "classes_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "classes_year_label_check" CHECK (year_label is null or (length(year_label) between 1 and 40 and year_label = btrim(year_label)))
);
--> statement-breakpoint
ALTER TABLE "app"."classes" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."class_members" ADD CONSTRAINT "class_members_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."class_members" ADD CONSTRAINT "class_members_institute_id_class_id_classes_institute_id_id_fk" FOREIGN KEY ("institute_id","class_id") REFERENCES "app"."classes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."class_members" ADD CONSTRAINT "class_members_institute_id_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."class_members" ADD CONSTRAINT "class_members_institute_id_added_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","added_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."classes" ADD CONSTRAINT "classes_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."classes" ADD CONSTRAINT "classes_institute_id_created_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","created_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "class_members_one_open" ON "app"."class_members" USING btree ("institute_id","class_id","user_id","member_role") WHERE ended_at is null;--> statement-breakpoint
CREATE INDEX "class_members_user" ON "app"."class_members" USING btree ("institute_id","user_id");--> statement-breakpoint
CREATE INDEX "class_members_class_role" ON "app"."class_members" USING btree ("institute_id","class_id","member_role");--> statement-breakpoint
CREATE INDEX "class_members_added_by" ON "app"."class_members" USING btree ("institute_id","added_by");--> statement-breakpoint
CREATE INDEX "classes_created_by" ON "app"."classes" USING btree ("institute_id","created_by");--> statement-breakpoint
-- Class helpers (04 §6.2), definer and stable, keeping to the session's
-- institute. A teacher counts only while they hold the teacher role.
create function app.is_class_member(p_class_id uuid) returns boolean
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  return exists (select from app.class_members m
    where m.institute_id = app.current_institute_id() and m.class_id = p_class_id
      and m.user_id = app.current_user_id() and m.ended_at is null);
end
$function$;
--> statement-breakpoint
create function app.is_class_teacher(p_class_id uuid) returns boolean
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  return app.has_role('teacher') and exists (select from app.class_members m
    where m.institute_id = app.current_institute_id() and m.class_id = p_class_id
      and m.user_id = app.current_user_id() and m.member_role = 'teacher' and m.ended_at is null);
end
$function$;
--> statement-breakpoint
-- An active teacher of any class the student is or was in. Past student
-- membership counts, so a student who left stays traceable (D-015, D-028).
create function app.is_teacher_of(p_student_user_id uuid) returns boolean
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  return app.has_role('teacher') and exists (
    select from app.class_members t
    join app.class_members s on s.institute_id = t.institute_id and s.class_id = t.class_id
    where t.institute_id = app.current_institute_id() and t.user_id = app.current_user_id()
      and t.member_role = 'teacher' and t.ended_at is null
      and s.user_id = p_student_user_id and s.member_role = 'student');
end
$function$;
--> statement-breakpoint
revoke all on function app.is_class_member(uuid), app.is_class_teacher(uuid), app.is_teacher_of(uuid) from public;
--> statement-breakpoint
grant execute on function app.is_class_member(uuid), app.is_class_teacher(uuid), app.is_teacher_of(uuid)
  to tazkiyah_app;
--> statement-breakpoint
CREATE POLICY "iso" ON "app"."class_members" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "class_members_read" ON "app"."class_members" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (user_id = (select app.current_user_id()) or (select app.has_role('admin')) or app.is_class_teacher(class_id));--> statement-breakpoint
CREATE POLICY "class_members_add" ON "app"."class_members" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (added_by = (select app.current_user_id()) and ((select app.has_role('admin')) or (member_role = 'student' and app.is_class_teacher(class_id))));--> statement-breakpoint
CREATE POLICY "class_members_end" ON "app"."class_members" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING ((select app.has_role('admin')) or (member_role = 'student' and app.is_class_teacher(class_id))) WITH CHECK ((select app.has_role('admin')) or (member_role = 'student' and app.is_class_teacher(class_id)));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."classes" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "classes_member_read" ON "app"."classes" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin')) or created_by = (select app.current_user_id()) or app.is_class_member(id));--> statement-breakpoint
CREATE POLICY "classes_staff_create" ON "app"."classes" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (created_by = (select app.current_user_id()) and ((select app.has_role('teacher')) or (select app.has_role('admin'))));--> statement-breakpoint
CREATE POLICY "classes_teacher_update" ON "app"."classes" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING ((select app.has_role('admin')) or app.is_class_teacher(id)) WITH CHECK ((select app.has_role('admin')) or app.is_class_teacher(id));
--> statement-breakpoint
-- Teachers and admins create classes and change their name, year and archive
-- date; members are added and their membership ended. Nothing is deleted.
grant select, insert on app.classes to tazkiyah_app;
--> statement-breakpoint
grant update (name, year_label, archived_at) on app.classes to tazkiyah_app;
--> statement-breakpoint
grant select, insert on app.class_members to tazkiyah_app;
--> statement-breakpoint
grant update (ended_at) on app.class_members to tazkiyah_app;
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.classes
for each row execute function app.audit_row_change();
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.class_members
for each row execute function app.audit_row_change();
--> statement-breakpoint
-- The creator of a class joins it as its teacher (REQ-TCH-005), so a teacher
-- never needs to add teacher members, which only admins do (D-129).
create function app.classes_add_creator() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if exists (select from app.user_roles r
    where r.institute_id = new.institute_id and r.user_id = new.created_by and r.role = 'teacher')
  then
    insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
    values (new.institute_id, new.id, new.created_by, 'teacher', new.created_by);
  end if;
  return null;
end
$function$;
--> statement-breakpoint
create trigger classes_add_creator after insert on app.classes
for each row execute function app.classes_add_creator();
--> statement-breakpoint
-- A member's role in a class must be a role they hold (04 §7.3). Only the end
-- date of a membership changes, and only once.
create function app.class_members_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op = 'UPDATE' then
    if to_jsonb(new) - 'ended_at' is distinct from to_jsonb(old) - 'ended_at' or old.ended_at is not null then
      raise exception 'only an open membership can be ended' using errcode = 'object_not_in_prerequisite_state';
    end if;
    return new;
  end if;
  if not exists (select from app.user_roles r
    where r.institute_id = new.institute_id and r.user_id = new.user_id and r.role = new.member_role)
  then
    raise exception 'a class % must hold the % role', new.member_role, new.member_role using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger class_members_rules before insert or update on app.class_members
for each row execute function app.class_members_rules();
--> statement-breakpoint
RESET ROLE;
