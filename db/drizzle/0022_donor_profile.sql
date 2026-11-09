SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Donor profile fields, privacy flags and erasure (04 §8.2, P1-E3-T40).
-- Up to five {"label","url"} links, https only (REQ-DPR-005).
create function app.valid_profile_links(links jsonb) returns boolean
language sql immutable
set search_path = pg_catalog, pg_temp
return jsonb_typeof(links) = 'array' and jsonb_array_length(links) <= 5
  and not exists (
    select 1 from jsonb_array_elements(links) as item(link)
    where jsonb_typeof(link) <> 'object'
      or (select count(*) from jsonb_object_keys(link)) <> 2
      or jsonb_typeof(link -> 'label') is distinct from 'string'
      or jsonb_typeof(link -> 'url') is distinct from 'string'
      or length(link ->> 'label') not between 1 and 40
      or link ->> 'label' ~ '[[:cntrl:]]'
      or length(link ->> 'url') > 300
      or link ->> 'url' !~ '^https://[^[:space:]/@]+[.][^[:space:]/@]+(/[^[:space:]]*)?$'
  );
--> statement-breakpoint
grant execute on function app.valid_profile_links(jsonb) to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
ALTER TABLE "app"."donors" ALTER COLUMN "email" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donors" ALTER COLUMN "preferred_language" SET DEFAULT 'en';--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "kind" text DEFAULT 'person' NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "user_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "email_verified_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "legal_name" text;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "phone" text;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "display_name" text;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "photo_media_id" uuid;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "profile_links" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "profile_public" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "reminder_opt_in" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "reminder_opt_in_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "claimed_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD COLUMN "erased_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_institute_id_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_institute_id_photo_media_id_media_assets_institute_id_id_fk" FOREIGN KEY ("institute_id","photo_media_id") REFERENCES "app"."media_assets"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "donors_photo_media" ON "app"."donors" USING btree ("institute_id","photo_media_id");--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_institute_id_user_id_unique" UNIQUE("institute_id","user_id");--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_kind_check" CHECK (kind in ('person', 'organisation', 'institute'));--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_text_check" CHECK (
        (legal_name is null or (length(legal_name) between 1 and 200 and legal_name = btrim(legal_name) and legal_name !~ '[[:cntrl:]]'))
        and (display_name is null or (length(display_name) between 1 and 80 and display_name = btrim(display_name) and display_name !~ '[[:cntrl:]]'))
        and (phone is null or phone ~ '^[+0-9][0-9 ()-]{4,31}$')
      );--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_profile_links_check" CHECK (app.valid_profile_links(profile_links));--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_reminder_check" CHECK (not reminder_opt_in or reminder_opt_in_at is not null);--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_claim_check" CHECK (claimed_at is null or user_id is not null);--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_erasure_check" CHECK (
        erased_at is null or (email is null and legal_name is null and phone is null
          and display_name is null and photo_media_id is null and profile_links = '[]'::jsonb
          and not profile_public and not reminder_opt_in)
      );
--> statement-breakpoint
-- Staff changes to donors are audited; every personal field is redacted by
-- app.audit_row_change (§12, REQ-DPR-009).
create trigger audit_row_change after insert or update on app.donors
for each row execute function app.audit_row_change();
--> statement-breakpoint
RESET ROLE;
