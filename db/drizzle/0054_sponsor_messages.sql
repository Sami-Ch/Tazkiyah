SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."sponsor_messages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"sponsorship_id" uuid NOT NULL,
	"direction" text NOT NULL,
	"body" text NOT NULL,
	"language" text NOT NULL,
	"sender_donor_id" uuid,
	"sender_user_id" uuid,
	"read_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "sponsor_messages_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "sponsor_messages_direction_check" CHECK ((direction = 'to_madrasa' and sender_donor_id is not null and sender_user_id is null)
          or (direction = 'to_sponsor' and sender_user_id is not null and sender_donor_id is null)),
	CONSTRAINT "sponsor_messages_body_check" CHECK (length(body) between 1 and 2000 and body ~ '[^[:space:]]'),
	CONSTRAINT "sponsor_messages_language_check" CHECK (language ~ '^[a-z]{2,3}$')
);
--> statement-breakpoint
ALTER TABLE "app"."sponsor_messages" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."sponsor_messages" ADD CONSTRAINT "sponsor_messages_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsor_messages" ADD CONSTRAINT "sponsor_messages_institute_id_sponsorship_id_sponsorships_institute_id_id_fk" FOREIGN KEY ("institute_id","sponsorship_id") REFERENCES "app"."sponsorships"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsor_messages" ADD CONSTRAINT "sponsor_messages_institute_id_sender_donor_id_donors_institute_id_id_fk" FOREIGN KEY ("institute_id","sender_donor_id") REFERENCES "app"."donors"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."sponsor_messages" ADD CONSTRAINT "sponsor_messages_institute_id_sender_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","sender_user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "sponsor_messages_sponsorship" ON "app"."sponsor_messages" USING btree ("institute_id","sponsorship_id","created_at");--> statement-breakpoint
CREATE INDEX "sponsor_messages_sender_donor" ON "app"."sponsor_messages" USING btree ("institute_id","sender_donor_id") WHERE sender_donor_id is not null;--> statement-breakpoint
CREATE INDEX "sponsor_messages_sender_user" ON "app"."sponsor_messages" USING btree ("institute_id","sender_user_id") WHERE sender_user_id is not null;--> statement-breakpoint
CREATE POLICY "iso" ON "app"."sponsor_messages" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "sponsor_messages_read" ON "app"."sponsor_messages" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin')) or exists (select from app.sponsorships s
            where s.id = sponsor_messages.sponsorship_id
              and s.sponsor_donor_id = (select app.my_account_donor_id())));--> statement-breakpoint
CREATE POLICY "sponsor_messages_sponsor_write" ON "app"."sponsor_messages" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (direction = 'to_madrasa' and sender_donor_id = (select app.my_account_donor_id()));--> statement-breakpoint
CREATE POLICY "sponsor_messages_admin_write" ON "app"."sponsor_messages" AS PERMISSIVE FOR INSERT TO "tazkiyah_app" WITH CHECK (direction = 'to_sponsor' and sender_user_id = (select app.current_user_id())
          and (select app.has_role('admin')));--> statement-breakpoint
CREATE POLICY "sponsor_messages_mark_read" ON "app"."sponsor_messages" AS PERMISSIVE FOR UPDATE TO "tazkiyah_app" USING ((direction = 'to_madrasa' and (select app.has_role('admin')))
          or (direction = 'to_sponsor' and exists (select from app.sponsorships s
            where s.id = sponsor_messages.sponsorship_id
              and s.sponsor_donor_id = (select app.my_account_donor_id())))) WITH CHECK (true);
--> statement-breakpoint
-- The sponsor and admins read the messages of a sponsorship; the sponsor
-- writes to the madrasa and admins reply; each side marks what it received
-- as read. Nobody deletes a message (04 §10.3, 06 §12.5).
grant select, insert on app.sponsor_messages to tazkiyah_app;
--> statement-breakpoint
grant update (read_at) on app.sponsor_messages to tazkiyah_app;
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.sponsor_messages
for each row execute function app.audit_row_change();
--> statement-breakpoint
-- A message to the madrasa comes from the sponsorship's own sponsor while it
-- is active; a reply comes from an admin while the sponsorship has not ended.
-- Afterwards only the read mark is set, once. It runs for the owner too.
create function app.sponsor_messages_rules() returns trigger
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op in ('DELETE', 'TRUNCATE') then
    raise exception 'sponsor messages are never deleted' using errcode = 'insufficient_privilege';
  end if;
  if tg_op = 'INSERT' then
    if new.direction = 'to_madrasa' and not exists (select from app.sponsorships s
      where s.institute_id = new.institute_id and s.id = new.sponsorship_id and s.status = 'active'
        and s.sponsor_donor_id = new.sender_donor_id)
    then
      raise exception 'only the sponsor of an active sponsorship writes to the madrasa' using errcode = 'check_violation';
    end if;
    if new.direction = 'to_sponsor' and (not exists (select from app.sponsorships s
      where s.institute_id = new.institute_id and s.id = new.sponsorship_id and s.status <> 'ended')
      or not exists (select from app.user_roles r
        where r.institute_id = new.institute_id and r.user_id = new.sender_user_id and r.role = 'admin'))
    then
      raise exception 'an admin replies while the sponsorship has not ended' using errcode = 'check_violation';
    end if;
    new.read_at := null;
    new.created_at := now();
    return new;
  end if;
  if to_jsonb(new) - 'read_at' is distinct from to_jsonb(old) - 'read_at'
    or old.read_at is not null or new.read_at is null
  then
    raise exception 'only the read mark is set on a message, once' using errcode = 'object_not_in_prerequisite_state';
  end if;
  new.read_at := now();
  return new;
end
$function$;
--> statement-breakpoint
create trigger sponsor_messages_rules before insert or update or delete on app.sponsor_messages
for each row execute function app.sponsor_messages_rules();
--> statement-breakpoint
create trigger sponsor_messages_no_truncate before truncate on app.sponsor_messages
for each statement execute function app.sponsor_messages_rules();
--> statement-breakpoint
RESET ROLE;
