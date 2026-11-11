SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "app"."consent_records" DROP CONSTRAINT "consent_records_kind_check";--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD COLUMN "sponsorship_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_institute_id_sponsorship_id_sponsorships_institute_id_id_fk" FOREIGN KEY ("institute_id","sponsorship_id") REFERENCES "app"."sponsorships"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "consent_records_sponsorship" ON "app"."consent_records" USING btree ("institute_id","sponsorship_id");--> statement-breakpoint
ALTER TABLE "app"."consent_records" ADD CONSTRAINT "consent_records_kind_check" CHECK (kind in ('public_work', 'real_name', 'face', 'orphan_full_profile')
          and (kind = 'orphan_full_profile') = (sponsorship_id is not null));
--> statement-breakpoint
-- The shape of a consent record over its life (04 §10.1, 07 §5). A new record
-- is about a student, carries no sign-off or withdrawal, and is dated no later
-- than today. Afterwards only the sign-offs, the second-signer assignment and
-- the withdrawal change, each once, except that the assignment may change
-- until the second sign-off. A withdrawn record never changes again.
-- Full-profile consent (06 §12.4, REQ-ORP-003, REQ-ORP-005) is opened by the
-- principal, the orphans' guardian, for one active sponsorship of that
-- student, and its two sign-offs come in either order.
create or replace function app.consent_records_rules() returns trigger
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
    if new.kind = 'orphan_full_profile' then
      if not exists (select from app.institute_settings s
        where s.institute_id = new.institute_id and s.principal_user_id = new.recorded_by)
      then
        raise exception 'the principal opens full-profile consent' using errcode = 'insufficient_privilege';
      end if;
      if not exists (select from app.sponsorships sp
        join app.persona_links l on l.institute_id = sp.institute_id and l.persona_id = sp.child_persona_id
        join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
        where sp.institute_id = new.institute_id and sp.id = new.sponsorship_id and sp.status = 'active'
          and l.user_id = new.student_user_id and u.is_orphan)
      then
        raise exception 'full-profile consent is for an active sponsorship of that orphan' using errcode = 'check_violation';
      end if;
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
    and (new.second_signed_by is distinct from new.second_signer_assigned
      or (new.principal_signed_by is null and new.kind <> 'orphan_full_profile'))
  then
    raise exception 'the assigned teacher signs after the principal' using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
-- Computed, never stored (04 §10.1): withdrawn once withdrawn; for a student
-- who is an orphan now, pending until both sign-offs are in (00 §8, D-017);
-- otherwise active from recording. Full-profile consent always needs both
-- sign-offs and counts only while its sponsorship is active; withdrawn before
-- both sign-offs it reads as declined, and a paused or ended sponsorship
-- shows as such (06 §12.4).
create or replace function app.consent_status(p_consent_id uuid) returns text
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  c app.consent_records;
  sponsorship_status text;
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
  if c.kind = 'orphan_full_profile' then
    if c.withdrawn_at is not null then
      return case when c.principal_signed_at is not null and c.second_signed_at is not null
        then 'withdrawn' else 'declined' end;
    end if;
    if c.principal_signed_at is null or c.second_signed_at is null then
      return 'pending';
    end if;
    select sp.status into sponsorship_status from app.sponsorships sp
    where sp.institute_id = tenant and sp.id = c.sponsorship_id;
    return case sponsorship_status when 'active' then 'active' when 'paused' then 'paused' else 'ended' end;
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
-- (04 §10.1, REQ-CHS-005, REQ-STU-004). Full-profile consent also needs both
-- sign-offs and an active sponsorship.
create or replace function app.consent_active(p_student_user_id uuid, p_kind text) returns boolean
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
        or (c.kind <> 'orphan_full_profile' and not exists (select from app.users u
          where u.institute_id = tenant and u.id = p_student_user_id and u.is_orphan)))
      and (c.kind <> 'orphan_full_profile' or exists (select from app.sponsorships sp
        where sp.institute_id = tenant and sp.id = c.sponsorship_id and sp.status = 'active')));
end
$function$;
--> statement-breakpoint
-- True while one sponsorship has active full-profile consent (04 §10.2,
-- REQ-ORP-003, REQ-ORP-005, REQ-ORP-006). Read on every request, never cached.
create function app.full_profile_active(p_sponsorship_id uuid) returns boolean
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select exists (
    select from app.consent_records c
    join app.sponsorships sp on sp.institute_id = c.institute_id and sp.id = c.sponsorship_id
    where c.institute_id = app.current_institute_id() and c.sponsorship_id = p_sponsorship_id
      and c.kind = 'orphan_full_profile' and c.withdrawn_at is null
      and c.principal_signed_at is not null and c.second_signed_at is not null and sp.status = 'active')
$function$;
--> statement-breakpoint
revoke all on function app.full_profile_active(uuid) from public;
--> statement-breakpoint
-- A sign-off on an orphan's consent record (07 §5.4): the principal first,
-- then the teacher the principal assigned. Full-profile consent takes the two
-- sign-offs in either order (06 §12.4). Returns what happened.
create or replace function app.sign_consent(p_consent_id uuid) returns text
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
  if c.kind <> 'orphan_full_profile' and not exists (select from app.users u
    where u.institute_id = tenant and u.id = c.student_user_id and u.is_orphan)
  then
    return 'not_needed';
  end if;
  if c.principal_signed_by is null and app.has_role('admin') and exists (select from app.institute_settings s
    where s.institute_id = tenant and s.principal_user_id = actor)
  then
    update app.consent_records set principal_signed_by = actor, principal_signed_at = now()
    where institute_id = tenant and id = c.id;
    return 'principal_signed';
  end if;
  if c.second_signed_by is null and c.second_signer_assigned is not distinct from actor and app.has_role('teacher')
    and (c.principal_signed_by is not null or c.kind = 'orphan_full_profile')
  then
    update app.consent_records set second_signed_by = actor, second_signed_at = now()
    where institute_id = tenant and id = c.id;
    return 'second_signed';
  end if;
  if c.principal_signed_by is not null and c.second_signed_by is not null then
    return 'already_signed';
  end if;
  return 'denied';
end
$function$;
--> statement-breakpoint
-- The principal assigns the second sign-off of an orphan's record to any
-- teacher other than themself, and may change it until that teacher signs
-- (04 §10.1, REQ-ORP-004). Full-profile consent always needs it.
create or replace function app.assign_second_signer(p_consent_id uuid, p_teacher_user_id uuid) returns text
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
  if c.kind <> 'orphan_full_profile' and not exists (select from app.users u
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
-- The sponsor's view of each active sponsorship (04 §10.3, 06 §12.2,
-- REQ-ORP-002): persona name, illustrated avatar, age in whole years and the
-- published updates, newest first. Only for a signed-in account donor. While
-- full-profile consent for that sponsorship is active, also the real name,
-- the student's photo and the current class names (REQ-ORP-003, REQ-ORP-005);
-- the check runs on every call, so a withdrawal hides them at once
-- (REQ-ORP-006).
drop function app.sponsor_child_view();
--> statement-breakpoint
create function app.sponsor_child_view()
returns table (sponsorship_id uuid, persona_name text, avatar_media_id uuid, age_years int, updates jsonb,
  full_profile boolean, full_name text, photo_media_id uuid, class_names jsonb)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select s.id, p.display_name, p.avatar_media_id,
    extract(year from age((now() at time zone 'Asia/Karachi')::date, u.date_of_birth))::int,
    coalesce((select jsonb_agg(jsonb_build_object('id', su.id, 'body', su.body, 'media_id', su.media_id,
        'published_at', su.published_at) order by su.published_at desc, su.id)
      from app.sponsorship_updates su
      where su.institute_id = s.institute_id and su.child_persona_id = s.child_persona_id
        and su.published_at is not null and su.hidden_at is null), '[]'::jsonb),
    f.shown,
    case when f.shown then u.full_name end,
    case when f.shown then u.photo_media_id end,
    case when f.shown then coalesce((select jsonb_agg(c.name order by c.id)
      from app.class_members m join app.classes c on c.institute_id = m.institute_id and c.id = m.class_id
      where m.institute_id = u.institute_id and m.user_id = u.id and m.member_role = 'student'
        and m.ended_at is null and c.archived_at is null), '[]'::jsonb) end
  from app.sponsorships s
  join app.personas p on p.institute_id = s.institute_id and p.id = s.child_persona_id
  left join app.persona_links l on l.institute_id = p.institute_id and l.persona_id = p.id
  left join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
  cross join lateral (select app.full_profile_active(s.id) as shown) f
  where s.institute_id = app.current_institute_id() and s.status = 'active'
    and s.sponsor_donor_id = app.my_account_donor_id()
  order by s.started_on, s.id
$function$;
--> statement-breakpoint
revoke all on function app.sponsor_child_view() from public;
--> statement-breakpoint
grant execute on function app.sponsor_child_view() to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
