SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."consent_records" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"student_user_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"guardian_name" text NOT NULL,
	"guardian_relation" text NOT NULL,
	"method" text NOT NULL,
	"given_on" date NOT NULL,
	"form_media_id" uuid,
	"notes" text,
	"recorded_by" uuid NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL,
	"principal_signed_by" uuid,
	"principal_signed_at" timestamp with time zone,
	"second_signer_assigned" uuid,
	"second_assigned_by" uuid,
	"second_assigned_at" timestamp with time zone,
	"second_signed_by" uuid,
	"second_signed_at" timestamp with time zone,
	"withdrawn_at" timestamp with time zone,
	"withdrawn_by" uuid,
	"withdrawal_reason" text,
	CONSTRAINT "consent_records_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "consent_records_kind_check" CHECK (kind in ('public_work', 'real_name', 'face')),
	CONSTRAINT "consent_records_guardian_check" CHECK (length(guardian_name) between 1 and 120 and guardian_name = btrim(guardian_name)
          and guardian_relation in ('father', 'mother', 'guardian', 'other')),
	CONSTRAINT "consent_records_method_check" CHECK (method in ('paper_form', 'in_person', 'phone', 'other')),
	CONSTRAINT "consent_records_notes_check" CHECK (notes is null or (length(notes) between 1 and 1000 and notes ~ '[^[:space:]]')),
	CONSTRAINT "consent_records_signoff_check" CHECK ((principal_signed_by is null) = (principal_signed_at is null)
          and (second_signer_assigned is null) = (second_assigned_by is null)
          and (second_signer_assigned is null) = (second_assigned_at is null)
          and (second_signed_by is null) = (second_signed_at is null)),
	CONSTRAINT "consent_records_withdrawal_check" CHECK ((withdrawn_at is null) = (withdrawn_by is null) and (withdrawn_at is null) = (withdrawal_reason is null)
          and (withdrawal_reason is null or (length(withdrawal_reason) between 1 and 500 and withdrawal_reason ~ '[^[:space:]]')))
);
--> statement-breakpoint
ALTER TABLE "app"."consent_records" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_student_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","student_user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_form_media_id_media_assets_institute_id_id_fk" FOREIGN KEY ("institute_id","form_media_id") REFERENCES "app"."media_assets"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_recorded_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","recorded_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_principal_signed_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","principal_signed_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_second_signer_assigned_users_institute_id_id_fk" FOREIGN KEY ("institute_id","second_signer_assigned") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_second_assigned_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","second_assigned_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_second_signed_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","second_signed_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_withdrawn_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","withdrawn_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "consent_records_student_kind" ON "app"."consent_records" USING btree ("institute_id","student_user_id","kind");--> statement-breakpoint
CREATE INDEX "consent_records_form_media" ON "app"."consent_records" USING btree ("institute_id","form_media_id");--> statement-breakpoint
CREATE INDEX "consent_records_recorded_by" ON "app"."consent_records" USING btree ("institute_id","recorded_by");--> statement-breakpoint
CREATE INDEX "consent_records_principal_signed_by" ON "app"."consent_records" USING btree ("institute_id","principal_signed_by");--> statement-breakpoint
CREATE INDEX "consent_records_second_signer" ON "app"."consent_records" USING btree ("institute_id","second_signer_assigned");--> statement-breakpoint
CREATE INDEX "consent_records_second_assigned_by" ON "app"."consent_records" USING btree ("institute_id","second_assigned_by");--> statement-breakpoint
CREATE INDEX "consent_records_second_signed_by" ON "app"."consent_records" USING btree ("institute_id","second_signed_by");--> statement-breakpoint
CREATE INDEX "consent_records_withdrawn_by" ON "app"."consent_records" USING btree ("institute_id","withdrawn_by");--> statement-breakpoint
CREATE POLICY "iso" ON "app"."consent_records" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "consent_staff_read" ON "app"."consent_records" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin')) or app.is_teacher_of(student_user_id)
          or second_signer_assigned = (select app.current_user_id()));--> statement-breakpoint
CREATE POLICY "consent_staff_record" ON "app"."consent_records" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (recorded_by = (select app.current_user_id())
          and ((select app.has_role('admin')) or app.is_teacher_of(student_user_id)));
--> statement-breakpoint
-- Teachers of the student and admins record consent and read it; the teacher
-- assigned to sign an orphan's record reads that record too. Nobody updates or
-- deletes a row directly (04 §10.1).
grant select, insert on app.consent_records to tazkiyah_app;
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.consent_records
for each row execute function app.audit_row_change();
--> statement-breakpoint
-- The shape of a consent record over its life (04 §10.1, 07 §5). A new record
-- is about a student, carries no sign-off or withdrawal, and is dated no later
-- than today. Afterwards only the sign-offs, the second-signer assignment and
-- the withdrawal change, each once, except that the assignment may change
-- until the second sign-off. A withdrawn record never changes again.
create function app.consent_records_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  signoffs constant text[] := array['principal_signed_by', 'principal_signed_at', 'second_signer_assigned',
    'second_assigned_by', 'second_assigned_at', 'second_signed_by', 'second_signed_at',
    'withdrawn_at', 'withdrawn_by', 'withdrawal_reason'];
begin
  if tg_op = 'DELETE' then
    raise exception 'consent records are never deleted' using errcode = 'insufficient_privilege';
  end if;
  if new.institute_id is distinct from app.current_institute_id() and app.current_institute_id() is not null then
    raise exception 'a consent record belongs to the current institute' using errcode = 'insufficient_privilege';
  end if;
  if tg_op = 'INSERT' then
    if not exists (select from app.user_roles r
      where r.institute_id = new.institute_id and r.user_id = new.student_user_id and r.role = 'student')
    then
      raise exception 'consent is recorded only for a student' using errcode = 'check_violation';
    end if;
    if new.principal_signed_by is not null or new.second_signer_assigned is not null
      or new.second_signed_by is not null or new.withdrawn_at is not null
    then
      raise exception 'a new consent record has no sign-off or withdrawal' using errcode = 'check_violation';
    end if;
    if new.given_on > (now() at time zone 'Asia/Karachi')::date then
      raise exception 'consent cannot be given in the future' using errcode = 'check_violation';
    end if;
    if new.form_media_id is not null and not exists (select from app.media_assets m
      where m.institute_id = new.institute_id and m.id = new.form_media_id
        and m.purpose = 'consent_form' and m.visibility = 'private')
    then
      raise exception 'a consent form scan must be a private consent form upload' using errcode = 'check_violation';
    end if;
    new.recorded_at := now();
    return new;
  end if;

  if to_jsonb(new) - signoffs is distinct from to_jsonb(old) - signoffs then
    raise exception 'only sign-offs and withdrawal change on a consent record' using errcode = 'object_not_in_prerequisite_state';
  end if;
  if old.withdrawn_at is not null
    or (old.principal_signed_by is not null
      and (new.principal_signed_by, new.principal_signed_at) is distinct from (old.principal_signed_by, old.principal_signed_at))
    or (old.second_signed_by is not null
      and (new.second_signed_by, new.second_signed_at, new.second_signer_assigned)
        is distinct from (old.second_signed_by, old.second_signed_at, old.second_signer_assigned))
    or (old.second_signer_assigned is not null and new.second_signer_assigned is null)
  then
    raise exception 'a sign-off or withdrawal is set once' using errcode = 'object_not_in_prerequisite_state';
  end if;
  if new.second_signed_by is not null
    and (new.second_signed_by is distinct from new.second_signer_assigned or new.principal_signed_by is null)
  then
    raise exception 'the assigned teacher signs after the principal' using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger consent_records_rules before insert or update or delete on app.consent_records
for each row execute function app.consent_records_rules();
--> statement-breakpoint
-- Computed, never stored (04 §10.1): withdrawn once withdrawn; for a student
-- who is an orphan now, pending until both sign-offs are in (00 §8, D-017);
-- otherwise active from recording.
create function app.consent_status(p_consent_id uuid) returns text
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  c app.consent_records;
begin
  select * into c from app.consent_records r where r.institute_id = tenant and r.id = p_consent_id;
  if c.id is null then
    return null;
  end if;
  -- Only someone who may read the record learns its status.
  if not (app.has_role('admin') or app.is_teacher_of(c.student_user_id)
    or c.second_signer_assigned is not distinct from app.current_user_id())
  then
    return null;
  end if;
  if c.withdrawn_at is not null then
    return 'withdrawn';
  end if;
  if (c.principal_signed_at is null or c.second_signed_at is null) and exists (select from app.users u
    where u.institute_id = tenant and u.id = c.student_user_id and u.is_orphan)
  then
    return 'pending';
  end if;
  return 'active';
end
$function$;
--> statement-breakpoint
-- True while the student has an active consent record of that kind. Checked
-- on every read by the views and triggers that need it; nothing caches it
-- (04 §10.1, REQ-CHS-005, REQ-STU-004).
create function app.consent_active(p_student_user_id uuid, p_kind text) returns boolean
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
begin
  return exists (
    select from app.consent_records c
    where c.institute_id = tenant and c.student_user_id = p_student_user_id and c.kind = p_kind
      and c.withdrawn_at is null
      and ((c.principal_signed_at is not null and c.second_signed_at is not null)
        or not exists (select from app.users u
          where u.institute_id = tenant and u.id = p_student_user_id and u.is_orphan)));
end
$function$;
--> statement-breakpoint
-- A sign-off on an orphan's consent record (07 §5.4): the principal first,
-- then the teacher the principal assigned. Returns what happened.
create function app.sign_consent(p_consent_id uuid) returns text
language plpgsql volatile security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  c app.consent_records;
begin
  select * into c from app.consent_records r
  where r.institute_id = tenant and r.id = p_consent_id for update;
  if c.id is null or actor is null then
    return 'denied';
  end if;
  if c.withdrawn_at is not null then
    return 'withdrawn';
  end if;
  if not exists (select from app.users u
    where u.institute_id = tenant and u.id = c.student_user_id and u.is_orphan)
  then
    return 'not_needed';
  end if;
  if c.principal_signed_by is null then
    if not app.has_role('admin') or not exists (select from app.institute_settings s
      where s.institute_id = tenant and s.principal_user_id = actor)
    then
      return 'denied';
    end if;
    update app.consent_records set principal_signed_by = actor, principal_signed_at = now()
    where institute_id = tenant and id = c.id;
    return 'principal_signed';
  end if;
  if c.second_signed_by is null then
    if c.second_signer_assigned is distinct from actor or not app.has_role('teacher') then
      return 'denied';
    end if;
    update app.consent_records set second_signed_by = actor, second_signed_at = now()
    where institute_id = tenant and id = c.id;
    return 'second_signed';
  end if;
  return 'already_signed';
end
$function$;
--> statement-breakpoint
-- The principal assigns the second sign-off of an orphan's record to any
-- teacher other than themself, and may change it until that teacher signs
-- (04 §10.1, REQ-ORP-004).
create function app.assign_second_signer(p_consent_id uuid, p_teacher_user_id uuid) returns text
language plpgsql volatile security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  c app.consent_records;
begin
  select * into c from app.consent_records r
  where r.institute_id = tenant and r.id = p_consent_id for update;
  if c.id is null or actor is null or not app.has_role('admin') or not exists (
    select from app.institute_settings s where s.institute_id = tenant and s.principal_user_id = actor)
  then
    return 'denied';
  end if;
  if c.withdrawn_at is not null then
    return 'withdrawn';
  end if;
  if not exists (select from app.users u
    where u.institute_id = tenant and u.id = c.student_user_id and u.is_orphan)
  then
    return 'not_needed';
  end if;
  if c.second_signed_by is not null then
    return 'already_signed';
  end if;
  if p_teacher_user_id is null or p_teacher_user_id = actor or not exists (
    select from app.users u join app.user_roles r on (r.institute_id, r.user_id) = (u.institute_id, u.id)
    where u.institute_id = tenant and u.id = p_teacher_user_id and u.status = 'active' and r.role = 'teacher')
  then
    return 'invalid';
  end if;
  update app.consent_records
  set second_signer_assigned = p_teacher_user_id, second_assigned_by = actor, second_assigned_at = now()
  where institute_id = tenant and id = c.id;
  return 'assigned';
end
$function$;
--> statement-breakpoint
-- Staff record a guardian's withdrawal with its reason (07 §5.5). Any admin,
-- either signer or a teacher of the student may record it. The take-down of
-- public work that relied on it is P3-E2-T04.
create function app.withdraw_consent(p_consent_id uuid, p_reason text) returns text
language plpgsql volatile security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  c app.consent_records;
begin
  select * into c from app.consent_records r
  where r.institute_id = tenant and r.id = p_consent_id for update;
  if c.id is null or actor is null or not (app.has_role('admin') or app.is_teacher_of(c.student_user_id)
    or (app.is_staff() and (actor is not distinct from c.principal_signed_by
      or actor is not distinct from c.second_signer_assigned)))
  then
    return 'denied';
  end if;
  if c.withdrawn_at is not null then
    return 'withdrawn';
  end if;
  if p_reason is null or length(btrim(p_reason)) not between 1 and 500 then
    return 'invalid';
  end if;
  update app.consent_records set withdrawn_at = now(), withdrawn_by = actor, withdrawal_reason = btrim(p_reason)
  where institute_id = tenant and id = c.id;
  return 'withdrawn_now';
end
$function$;
--> statement-breakpoint
revoke all on function app.consent_status(uuid), app.consent_active(uuid, text), app.sign_consent(uuid),
  app.assign_second_signer(uuid, uuid), app.withdraw_consent(uuid, text) from public;
--> statement-breakpoint
grant execute on function app.consent_status(uuid), app.sign_consent(uuid),
  app.assign_second_signer(uuid, uuid), app.withdraw_consent(uuid, text) to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
