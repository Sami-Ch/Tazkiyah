SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The signed-in account's own donor row (06-P16: sponsors are account
-- donors, never a trail link).
create function app.my_account_donor_id() returns uuid
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select d.id from app.donors d
  where d.institute_id = app.current_institute_id() and d.user_id = app.current_user_id() and d.erased_at is null
$function$;
--> statement-breakpoint
-- A teacher of the student behind a persona (D-015, D-028).
create function app.teaches_persona(p_persona_id uuid) returns boolean
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  return app.has_role('teacher') and exists (select from app.persona_links l
    where l.institute_id = app.current_institute_id() and l.persona_id = p_persona_id
      and app.is_teacher_of(l.user_id));
end
$function$;
--> statement-breakpoint
revoke all on function app.my_account_donor_id(), app.teaches_persona(uuid) from public;
--> statement-breakpoint
grant execute on function app.my_account_donor_id(), app.teaches_persona(uuid) to tazkiyah_app;
--> statement-breakpoint
CREATE TABLE "app"."sponsorship_updates" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"child_persona_id" uuid NOT NULL,
	"body" app.localized_text NOT NULL,
	"media_id" uuid,
	"author_user_id" uuid NOT NULL,
	"published_at" timestamp with time zone,
	"hidden_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "sponsorship_updates_institute_id_id_unique" UNIQUE("institute_id","id")
);
--> statement-breakpoint
ALTER TABLE "app"."sponsorship_updates" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."sponsorships" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"sponsor_donor_id" uuid NOT NULL,
	"child_persona_id" uuid NOT NULL,
	"cause_id" uuid NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"started_on" date DEFAULT (now() at time zone 'Asia/Karachi')::date NOT NULL,
	"ended_on" date,
	"matched_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "sponsorships_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "sponsorships_status_check" CHECK (status in ('active', 'paused', 'ended') and (status = 'ended') = (ended_on is not null)
          and (ended_on is null or ended_on >= started_on))
);
--> statement-breakpoint
ALTER TABLE "app"."sponsorships" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "sponsorship_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."sponsorship_updates" ADD CONSTRAINT "sponsorship_updates_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsorship_updates" ADD CONSTRAINT "sponsorship_updates_institute_id_child_persona_id_personas_institute_id_id_fk" FOREIGN KEY ("institute_id","child_persona_id") REFERENCES "app"."personas"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsorship_updates" ADD CONSTRAINT "sponsorship_updates_institute_id_media_id_media_assets_institute_id_id_fk" FOREIGN KEY ("institute_id","media_id") REFERENCES "app"."media_assets"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsorship_updates" ADD CONSTRAINT "sponsorship_updates_institute_id_author_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","author_user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsorships" ADD CONSTRAINT "sponsorships_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsorships" ADD CONSTRAINT "sponsorships_institute_id_sponsor_donor_id_donors_institute_id_id_fk" FOREIGN KEY ("institute_id","sponsor_donor_id") REFERENCES "app"."donors"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsorships" ADD CONSTRAINT "sponsorships_institute_id_child_persona_id_personas_institute_id_id_fk" FOREIGN KEY ("institute_id","child_persona_id") REFERENCES "app"."personas"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsorships" ADD CONSTRAINT "sponsorships_institute_id_cause_id_causes_institute_id_id_fk" FOREIGN KEY ("institute_id","cause_id") REFERENCES "app"."causes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsorships" ADD CONSTRAINT "sponsorships_institute_id_matched_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","matched_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "sponsorship_updates_child" ON "app"."sponsorship_updates" USING btree ("institute_id","child_persona_id","published_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "sponsorship_updates_media" ON "app"."sponsorship_updates" USING btree ("institute_id","media_id") WHERE media_id is not null;--> statement-breakpoint
CREATE INDEX "sponsorship_updates_author" ON "app"."sponsorship_updates" USING btree ("institute_id","author_user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "sponsorships_one_per_child" ON "app"."sponsorships" USING btree ("institute_id","child_persona_id") WHERE status <> 'ended';--> statement-breakpoint
CREATE INDEX "sponsorships_child" ON "app"."sponsorships" USING btree ("institute_id","child_persona_id");--> statement-breakpoint
CREATE INDEX "sponsorships_sponsor" ON "app"."sponsorships" USING btree ("institute_id","sponsor_donor_id");--> statement-breakpoint
CREATE INDEX "sponsorships_cause" ON "app"."sponsorships" USING btree ("institute_id","cause_id");--> statement-breakpoint
CREATE INDEX "sponsorships_matched_by" ON "app"."sponsorships" USING btree ("institute_id","matched_by");--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_sponsorship_id_sponsorships_institute_id_id_fk" FOREIGN KEY ("institute_id","sponsorship_id") REFERENCES "app"."sponsorships"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "donations_sponsorship" ON "app"."donations" USING btree ("institute_id","sponsorship_id") WHERE sponsorship_id is not null;--> statement-breakpoint
CREATE POLICY "iso" ON "app"."sponsorship_updates" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "sponsorship_updates_read" ON "app"."sponsorship_updates" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin')) or app.teaches_persona(child_persona_id)
          or (published_at is not null and hidden_at is null and exists (select from app.sponsorships s
            where s.child_persona_id = sponsorship_updates.child_persona_id and s.status = 'active'
              and s.sponsor_donor_id = (select app.my_account_donor_id()))));--> statement-breakpoint
CREATE POLICY "sponsorship_updates_write" ON "app"."sponsorship_updates" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (author_user_id = (select app.current_user_id())
          and ((select app.has_role('admin')) or app.teaches_persona(child_persona_id)));--> statement-breakpoint
CREATE POLICY "sponsorship_updates_edit" ON "app"."sponsorship_updates" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING ((select app.has_role('admin'))
          or (author_user_id = (select app.current_user_id()) and published_at is null)) WITH CHECK (true);--> statement-breakpoint
CREATE POLICY "iso" ON "app"."sponsorships" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "sponsorships_read" ON "app"."sponsorships" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin')) or sponsor_donor_id = (select app.my_account_donor_id())
          or app.teaches_persona(child_persona_id));--> statement-breakpoint
CREATE POLICY "sponsorships_admin_insert" ON "app"."sponsorships" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK ((select app.has_role('admin')));--> statement-breakpoint
CREATE POLICY "sponsorships_admin_update" ON "app"."sponsorships" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING ((select app.has_role('admin'))) WITH CHECK ((select app.has_role('admin')));
--> statement-breakpoint
grant select, insert on app.sponsorships, app.sponsorship_updates to tazkiyah_app;
--> statement-breakpoint
grant update (status) on app.sponsorships to tazkiyah_app;
--> statement-breakpoint
grant update (body, media_id, published_at, hidden_at) on app.sponsorship_updates to tazkiyah_app;
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.sponsorships
for each row execute function app.audit_row_change();
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.sponsorship_updates
for each row execute function app.audit_row_change();
--> statement-breakpoint
-- Matching (06 §12.1): the child is a student marked as an orphan, known by
-- persona; the sponsor is an account donor; the admin who matched is
-- recorded. Afterwards only the status changes: active and paused switch,
-- and ended is final, dated today. It runs for the owner too.
create function app.sponsorships_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op = 'INSERT' then
    if not exists (select from app.persona_links l
      join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
      where l.institute_id = new.institute_id and l.persona_id = new.child_persona_id and u.is_orphan)
    then
      raise exception 'only an orphan is sponsored' using errcode = 'check_violation';
    end if;
    if not exists (select from app.donors d where d.institute_id = new.institute_id and d.id = new.sponsor_donor_id
      and d.user_id is not null and d.erased_at is null)
    then
      raise exception 'a sponsor needs a donor account' using errcode = 'check_violation';
    end if;
    new.matched_by := coalesce(app.current_user_id(), new.matched_by);
    new.status := 'active';
    new.ended_on := null;
    new.created_at := now();
    return new;
  end if;
  if to_jsonb(new) - array['status', 'ended_on'] is distinct from to_jsonb(old) - array['status', 'ended_on'] then
    raise exception 'a sponsorship keeps its sponsor, child and cause' using errcode = 'insufficient_privilege';
  end if;
  if old.status = 'ended' then
    raise exception 'an ended sponsorship stays ended' using errcode = 'object_not_in_prerequisite_state';
  end if;
  new.ended_on := case when new.status = 'ended' then (now() at time zone 'Asia/Karachi')::date end;
  return new;
end
$function$;
--> statement-breakpoint
create trigger sponsorships_rules before insert or update on app.sponsorships
for each row execute function app.sponsorships_rules();
--> statement-breakpoint
-- Updates (06 §12.3): about a sponsored-orphan persona; an admin's update is
-- published at once, a teacher's waits for an admin (06-P18). Only an admin
-- publishes or hides. The author edits only before publishing. A photo is a
-- `sponsorship_update` upload with no face, since full-profile consent
-- (P4-E2-T40) does not exist yet. It runs for the owner too.
create function app.sponsorship_updates_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  actor uuid := app.current_user_id();
  is_admin boolean := app.has_role('admin');
begin
  if new.media_id is not null and not exists (select from app.media_assets m
    where m.institute_id = new.institute_id and m.id = new.media_id and m.purpose = 'sponsorship_update'
      and m.kind = 'image' and not m.shows_face and m.status in ('pending', 'ready'))
  then
    raise exception 'an update photo is a sponsorship upload with no face' using errcode = 'check_violation';
  end if;
  if tg_op = 'INSERT' then
    if not exists (select from app.persona_links l
      join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
      where l.institute_id = new.institute_id and l.persona_id = new.child_persona_id and u.is_orphan)
    then
      raise exception 'updates are about a sponsored orphan' using errcode = 'check_violation';
    end if;
    new.author_user_id := coalesce(actor, new.author_user_id);
    new.published_at := case when actor is null or is_admin then coalesce(new.published_at, now()) end;
    new.hidden_at := null;
    new.created_at := now();
    return new;
  end if;
  if (new.child_persona_id, new.author_user_id, new.created_at)
    is distinct from (old.child_persona_id, old.author_user_id, old.created_at)
  then
    raise exception 'an update keeps its child and author' using errcode = 'insufficient_privilege';
  end if;
  if actor is not null and not is_admin then
    if new.published_at is distinct from old.published_at or new.hidden_at is distinct from old.hidden_at then
      raise exception 'only an admin publishes or hides an update' using errcode = 'insufficient_privilege';
    end if;
    if old.published_at is not null then
      raise exception 'a published update is not edited' using errcode = 'insufficient_privilege';
    end if;
  end if;
  if new.published_at is distinct from old.published_at then
    if old.published_at is not null then
      raise exception 'a published update is hidden, not unpublished' using errcode = 'object_not_in_prerequisite_state';
    end if;
    new.published_at := now();
  end if;
  if new.hidden_at is not null and old.hidden_at is null then
    new.hidden_at := now();
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger sponsorship_updates_rules before insert or update on app.sponsorship_updates
for each row execute function app.sponsorship_updates_rules();
--> statement-breakpoint
-- A sponsorship gift comes from the sponsor to the sponsorship's cause
-- (06 §12.1, REQ-ORP-009). The donation lock keeps the link fixed afterwards.
create function app.donations_sponsorship_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if new.sponsorship_id is not null and not exists (select from app.sponsorships s
    where s.institute_id = new.institute_id and s.id = new.sponsorship_id
      and s.sponsor_donor_id = new.donor_id and s.cause_id = new.cause_id)
  then
    raise exception 'a sponsorship gift comes from the sponsor to the sponsorship cause' using errcode = 'check_violation';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger donations_sponsorship_rules before insert on app.donations
for each row execute function app.donations_sponsorship_rules();
--> statement-breakpoint
-- What a sponsor sees by default (REQ-ORP-002, 06 §12.2): for each of their
-- active sponsorships, the persona name, its illustrated avatar, the age in
-- whole years (never the date of birth) and the published updates, newest
-- first. Only for a signed-in account donor. The full-profile fields come
-- with orphan_full_profile consent (P4-E2-T40).
create function app.sponsor_child_view()
returns table (sponsorship_id uuid, persona_name text, avatar_media_id uuid, age_years int, updates jsonb)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select s.id, p.display_name, p.avatar_media_id,
    extract(year from age((now() at time zone 'Asia/Karachi')::date, u.date_of_birth))::int,
    coalesce((select jsonb_agg(jsonb_build_object('id', su.id, 'body', su.body, 'media_id', su.media_id,
        'published_at', su.published_at) order by su.published_at desc, su.id)
      from app.sponsorship_updates su
      where su.institute_id = s.institute_id and su.child_persona_id = s.child_persona_id
        and su.published_at is not null and su.hidden_at is null), '[]'::jsonb)
  from app.sponsorships s
  join app.personas p on p.institute_id = s.institute_id and p.id = s.child_persona_id
  left join app.persona_links l on l.institute_id = p.institute_id and l.persona_id = p.id
  left join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
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
