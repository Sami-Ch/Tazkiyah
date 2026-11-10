SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Personas and the private persona links (04 §7.4, 07 §4, P3-E1-T41).

-- Contact details a child must not share (07 §12.2): a phone number (10 or
-- more digits, Latin, Arabic-Indic or Urdu, with spaces, dashes, dots, brackets
-- or a plus between them), an email address, written as such or spelled out,
-- and links to messaging or social profiles. The full scan of posts, with the
-- flagged street addresses, is P3-E3-T12.
create function app.has_contact_details(value text) returns boolean
language sql immutable parallel safe
set search_path = pg_catalog, pg_temp
return value ~ '([0-9٠-٩۰-۹][ ().+-]*){10,}'
  or value ~ '[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+'
  or value ~* '\mat\M[[:space:]]+[^[:space:]]+[[:space:]]+\mdot\M'
  or value ~ 'ایٹ.{0,30}ڈاٹ'
  or value ~* '(wa\.me|whatsapp\.com|t\.me/|telegram\.(me|org)|facebook\.com|fb\.(com|me)|instagram\.com|tiktok\.com|snapchat\.com)';
--> statement-breakpoint
-- A display name: 3 to 24 Urdu or Latin letters, digits, spaces and hyphens,
-- not digits only, and no phone number (04 §7.4, 07 §4.2). The real-name match
-- and the word block list are P3-E1-T03.
create function app.persona_name_ok(value text) returns boolean
language sql immutable parallel safe
set search_path = pg_catalog, pg_temp
return length(value) between 3 and 24 and value = btrim(value)
  and value ~ '^[A-Za-z0-9؀-ۿݐ-ݿ‌ -]+$'
  and value !~ '^[0-9٠-٩۰-۹ -]+$'
  and not app.has_contact_details(value);
--> statement-breakpoint
-- The current student's own persona (04 §6.2).
create function app.current_persona_id() returns uuid
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  return (select l.persona_id from app.persona_links l
    where l.institute_id = app.current_institute_id() and l.user_id = app.current_user_id()
      and app.has_role('student'));
end
$function$;
--> statement-breakpoint
-- Admins, the persona's student and that student's teachers may know whose
-- persona it is (04 §6.2, REQ-SEC-007, REQ-TCH-006).
create function app.can_trace_persona(p_persona_id uuid) returns boolean
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  return app.has_role('admin') or exists (select from app.persona_links l
    where l.institute_id = app.current_institute_id() and l.persona_id = p_persona_id
      and ((l.user_id = app.current_user_id() and app.has_role('student'))
        or app.is_teacher_of(l.user_id)));
end
$function$;
--> statement-breakpoint
revoke all on function app.current_persona_id(), app.can_trace_persona(uuid) from public;
--> statement-breakpoint
grant execute on function app.current_persona_id(), app.can_trace_persona(uuid),
  app.has_contact_details(text), app.persona_name_ok(text) to tazkiyah_app;
--> statement-breakpoint
CREATE TABLE "app"."persona_links" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"persona_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"created_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "persona_links_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "persona_links_persona" UNIQUE("institute_id","persona_id"),
	CONSTRAINT "persona_links_user" UNIQUE("institute_id","user_id")
);
--> statement-breakpoint
ALTER TABLE "app"."persona_links" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."personas" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"display_name" text NOT NULL,
	"avatar_media_id" uuid,
	"bio" text,
	"bio_language" text,
	"show_real_name" boolean DEFAULT false NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "personas_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "personas_display_name_check" CHECK (app.persona_name_ok(display_name)),
	CONSTRAINT "personas_bio_check" CHECK (bio is null or (length(bio) between 1 and 160 and bio ~ '[^[:space:]]' and not app.has_contact_details(bio))),
	CONSTRAINT "personas_bio_language_check" CHECK (bio_language is null or bio_language in ('en', 'ur'))
);
--> statement-breakpoint
ALTER TABLE "app"."personas" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."persona_links" ADD CONSTRAINT "persona_links_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."persona_links" ADD CONSTRAINT "persona_links_institute_id_persona_id_personas_institute_id_id_fk" FOREIGN KEY ("institute_id","persona_id") REFERENCES "app"."personas"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."persona_links" ADD CONSTRAINT "persona_links_institute_id_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."persona_links" ADD CONSTRAINT "persona_links_institute_id_created_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","created_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."personas" ADD CONSTRAINT "personas_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."personas" ADD CONSTRAINT "personas_institute_id_avatar_media_id_media_assets_institute_id_id_fk" FOREIGN KEY ("institute_id","avatar_media_id") REFERENCES "app"."media_assets"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "persona_links_created_by" ON "app"."persona_links" USING btree ("institute_id","created_by");--> statement-breakpoint
CREATE UNIQUE INDEX "personas_display_name" ON "app"."personas" USING btree ("institute_id",lower(display_name));--> statement-breakpoint
CREATE INDEX "personas_avatar_media" ON "app"."personas" USING btree ("institute_id","avatar_media_id");--> statement-breakpoint
CREATE POLICY "users_teacher_read" ON "app"."users" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (app.is_teacher_of(id));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."persona_links" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "read_link" ON "app"."persona_links" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING (user_id = (select app.current_user_id()) or (select app.has_role('admin')) or app.is_teacher_of(user_id));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."personas" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "personas_member_read" ON "app"."personas" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.is_member()));--> statement-breakpoint
CREATE POLICY "personas_edit" ON "app"."personas" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING (app.can_trace_persona(id)) WITH CHECK (app.can_trace_persona(id));
--> statement-breakpoint
-- Everyone in the madrasa reads personas. The student, the student's teachers
-- and admins change the name, avatar and bio; only an admin switches a persona
-- off. Showing the real name waits for consent (P3-E1-T13), so nobody sets it
-- yet. Rows are never inserted or deleted directly.
grant select on app.personas, app.persona_links to tazkiyah_app;
--> statement-breakpoint
grant update (display_name, avatar_media_id, bio, bio_language, is_active, updated_at)
  on app.personas to tazkiyah_app;
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.personas
for each row execute function app.audit_row_change();
--> statement-breakpoint
create trigger audit_row_change after insert on app.persona_links
for each row execute function app.audit_row_change();
--> statement-breakpoint
-- An avatar is an illustration uploaded for that purpose, never a face
-- (04 §7.4, REQ-CHS-001). Only admins switch a persona off or on.
create function app.personas_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.avatar_media_id is not null and new.avatar_media_id is distinct from old.avatar_media_id
    and not exists (select from app.media_assets m
      where m.institute_id = new.institute_id and m.id = new.avatar_media_id
        and m.purpose = 'avatar' and m.kind = 'image' and not m.shows_face and m.status <> 'deleted')
  then
    raise exception 'a persona avatar must be an avatar illustration' using errcode = 'check_violation';
  end if;
  if new.is_active is distinct from old.is_active and not app.has_role('admin') then
    raise exception 'only an admin can switch a persona off' using errcode = 'insufficient_privilege';
  end if;
  new.updated_at := now();
  return new;
end
$function$;
--> statement-breakpoint
create trigger personas_rules before update on app.personas
for each row execute function app.personas_rules();
--> statement-breakpoint
-- A link always belongs to a student (04 §7.4).
create function app.persona_links_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if not exists (select from app.user_roles r
    where r.institute_id = new.institute_id and r.user_id = new.user_id and r.role = 'student')
  then
    raise exception 'a persona belongs only to a student' using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger persona_links_rules before insert on app.persona_links
for each row execute function app.persona_links_rules();
--> statement-breakpoint
-- A generated display name such as "Sitara 114" (07 §4.1): a word for a thing
-- in nature or the classroom and a number. A word that is part of any real
-- name in the institute is never used (07 §4.2).
create function app.generate_persona_name(p_institute_id uuid) returns text
language plpgsql volatile security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  words constant text[] := array['Sitara', 'Qalam', 'Chinar', 'Jugnu', 'Darya', 'Badal', 'Kitab',
    'Hilal', 'Zaitoon', 'Anaar', 'Sanober', 'Shahtoot', 'Pahar', 'Barish', 'Kehkashan', 'Titli',
    'Bulbul', 'Diya', 'Sahil', 'Shabnam'];
  usable text[];
  candidate text;
begin
  select array_agg(w) into usable from unnest(words) as w
  where not exists (select from app.users u
    where u.institute_id = p_institute_id and lower(u.full_name) ~ ('\m' || lower(w) || '\M'));
  if usable is null then
    usable := array['Talib'];
  end if;
  for attempt in 1..200 loop
    candidate := usable[1 + floor(random() * cardinality(usable))::int] || ' '
      || (100 + floor(random() * (case when attempt <= 100 then 900 else 9900 end)))::int;
    if not exists (select from app.personas p
      where p.institute_id = p_institute_id and lower(p.display_name) = lower(candidate))
    then
      return candidate;
    end if;
  end loop;
  raise exception 'no free persona name' using errcode = '55000';
end
$function$;
--> statement-breakpoint
-- Creates a student in one step (04 §7.4, REQ-STU-001): the user, the student
-- role, the class membership, a persona with a generated name and the private
-- link. The caller is an admin or a teacher of that open class; anyone else
-- gets null. Only identity.create_student_account(), which also stores the
-- starting password, calls it.
create function app.create_student_account(
  p_full_name text, p_username text, p_class_id uuid, p_is_orphan boolean
) returns uuid
language plpgsql volatile security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  student_id uuid;
  new_persona uuid;
begin
  if tenant is null or actor is null or p_class_id is null
    or not exists (select from app.classes c
      where c.institute_id = tenant and c.id = p_class_id and c.archived_at is null)
    or not (app.has_role('admin') or app.is_class_teacher(p_class_id))
  then
    return null;
  end if;
  if p_full_name is null or length(btrim(p_full_name)) not between 1 and 120
    or p_username is null or p_username !~ '^[a-z0-9][a-z0-9.-]{2,39}$'
  then
    raise exception 'Invalid student account' using errcode = '22023';
  end if;

  insert into app.users (institute_id, full_name, username, status, must_change_password, is_orphan)
  values (tenant, btrim(p_full_name), p_username, 'active', true, coalesce(p_is_orphan, false))
  returning id into student_id;
  insert into app.user_roles (institute_id, user_id, role, granted_by)
  values (tenant, student_id, 'student', actor);
  insert into app.class_members (institute_id, class_id, user_id, member_role, added_by)
  values (tenant, p_class_id, student_id, 'student', actor);
  insert into app.personas (institute_id, display_name)
  values (tenant, app.generate_persona_name(tenant))
  returning id into new_persona;
  insert into app.persona_links (institute_id, persona_id, user_id, created_by)
  values (tenant, new_persona, student_id, actor);
  return student_id;
end
$function$;
--> statement-breakpoint
revoke all on function app.generate_persona_name(uuid),
  app.create_student_account(text, text, uuid, boolean) from public;
--> statement-breakpoint
-- The staff-facing entry point now places the student in a class and gives
-- them a persona; the class is required (07 §4.1). It returns null when the
-- session or the caller's rights do not allow it.
drop function identity.create_student_account(uuid, text, text);
--> statement-breakpoint
create function identity.create_student_account(
  session_id uuid, student_name text, password_hash text, class_id uuid, is_orphan boolean
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  prefix text;
  stem text;
  next_number integer;
  student_id uuid;
  student_username text;
begin
  if not identity.staff_session_ok(session_id)
    or not (app.has_role('admin') or app.has_role('teacher')) then
    return null;
  end if;
  if password_hash is null or length(password_hash) not between 64 and 255 then
    raise exception 'Invalid student account' using errcode = '22023';
  end if;

  -- Lock the settings row so two staff members never get the same number.
  select lower(s.receipt_prefix) into prefix from app.institute_settings s
  where s.institute_id = tenant for update;
  if prefix is null then
    raise exception 'Institute settings are missing' using errcode = '55000';
  end if;
  stem := prefix || '-' || extract(year from now())::text || '-';
  select coalesce(max(substr(u.username, length(stem) + 1)::integer), 0) + 1 into next_number
  from app.users u
  where u.institute_id = tenant and u.username like stem || '%'
    and substr(u.username, length(stem) + 1) ~ '^[0-9]+$';
  student_username := stem || lpad(next_number::text, 4, '0');

  student_id := app.create_student_account(student_name, student_username, class_id, is_orphan);
  if student_id is null then
    return null;
  end if;
  insert into identity.accounts (institute_id, user_id, provider_id, account_id, password)
  values (tenant, student_id, 'credential', student_id::text, password_hash);
  return student_username;
end
$function$;
--> statement-breakpoint
revoke all on function identity.create_student_account(uuid, text, text, uuid, boolean) from public;
--> statement-breakpoint
grant execute on function identity.create_student_account(uuid, text, text, uuid, boolean) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
