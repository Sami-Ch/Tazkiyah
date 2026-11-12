SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."causes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"slug" text NOT NULL,
	"cause_type" text NOT NULL,
	"title" "app"."localized_text" NOT NULL,
	"summary" "app"."localized_text" NOT NULL,
	"body" "app"."localized_text",
	"cover_media_id" uuid,
	"target_paisa" bigint,
	"target_period" text,
	"stock_year_start_month" smallint,
	"starts_on" date,
	"ends_on" date,
	"accepts_zakat" boolean DEFAULT false NOT NULL,
	"zakat_approved_by" "app"."localized_text",
	"status" text DEFAULT 'draft' NOT NULL,
	"listed_as_project" boolean DEFAULT false NOT NULL,
	"category" text,
	"display_order" smallint DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "causes_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "causes_institute_id_slug_unique" UNIQUE("institute_id","slug"),
	CONSTRAINT "causes_slug_check" CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) <= 80),
	CONSTRAINT "causes_status_check" CHECK (status in ('draft', 'active', 'closed', 'archived')),
	CONSTRAINT "causes_target_check" CHECK (target_paisa is null or target_paisa > 0),
	CONSTRAINT "causes_dates_check" CHECK (starts_on is null or ends_on is null or ends_on >= starts_on),
	CONSTRAINT "causes_zakat_approval_check" CHECK (accepts_zakat or zakat_approved_by is null),
	CONSTRAINT "causes_type_rules_check" CHECK (
        coalesce(
          (cause_type = 'campaign' and target_paisa is not null and ends_on is not null
            and target_period is null and stock_year_start_month is null)
          or (cause_type = 'ongoing' and ends_on is null
            and target_period in ('monthly', 'yearly') and stock_year_start_month is null)
          or (cause_type = 'yearly_stock' and ends_on is null
            and target_period is null and stock_year_start_month between 1 and 12),
          false
        )
      )
);
--> statement-breakpoint
ALTER TABLE "app"."causes" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."causes" ADD CONSTRAINT "causes_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."causes" ADD CONSTRAINT "causes_institute_id_cover_media_id_media_assets_institute_id_id_fk" FOREIGN KEY ("institute_id","cover_media_id") REFERENCES "app"."media_assets"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "causes_institute_id_status_display_order_index" ON "app"."causes" USING btree ("institute_id","status","display_order");--> statement-breakpoint
CREATE POLICY "iso" ON "app"."causes" AS RESTRICTIVE FOR ALL TO "tazkiyah_app" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));
--> statement-breakpoint
create view public_api.causes with (security_barrier = true) as
select c.id, c.slug, c.cause_type, c.title, c.summary, c.body, c.target_paisa,
  c.target_period, c.stock_year_start_month, c.starts_on, c.ends_on,
  c.accepts_zakat, c.zakat_approved_by,
  case when c.ends_on < clock.today then 'closed' else c.status end as status,
  c.display_order, c.created_at
from app.causes c
join public_api.institute_public i on i.institute_id = c.institute_id
cross join lateral (select (now() at time zone 'Asia/Karachi')::date as today) clock
where c.status in ('active', 'closed') and (c.starts_on is null or c.starts_on <= clock.today);
--> statement-breakpoint
grant select on public_api.causes to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.causes
for each row execute function app.audit_row_change();
--> statement-breakpoint
create function identity.read_causes(session_id uuid)
returns table (id uuid, slug text, cause_type text, title jsonb, status text, starts_on date, ends_on date)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select c.id, c.slug, c.cause_type, c.title::jsonb, c.status, c.starts_on, c.ends_on
  from app.causes c
  where c.institute_id = app.current_institute_id() and identity.is_staff_admin_session(session_id)
  order by c.created_at desc, c.id
$function$;
--> statement-breakpoint
create function identity.create_cause(
  session_id uuid, cause_slug text, kind text, cause_title jsonb, cause_summary jsonb,
  cause_body jsonb, target bigint, period text, stock_month smallint,
  first_day date, last_day date, zakat boolean
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  if cause_slug is null or length(cause_slug) > 80 or cause_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    or not coalesce(app.valid_localized_text(cause_title) and cause_title ?& array['en', 'ur']
      and (cause_title - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_title ->> 'en'), length(cause_title ->> 'ur')) <= 120, false)
    or not coalesce(app.valid_localized_text(cause_summary) and cause_summary ?& array['en', 'ur']
      and (cause_summary - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_summary ->> 'en'), length(cause_summary ->> 'ur')) <= 360, false)
    or (cause_body is not null and not coalesce(app.valid_localized_text(cause_body)
      and cause_body ?& array['en', 'ur'] and (cause_body - array['en', 'ur']) = '{}'::jsonb
      and greatest(length(cause_body ->> 'en'), length(cause_body ->> 'ur')) <= 12000, false))
  then return 'invalid'; end if;

  insert into app.causes (
    institute_id, slug, cause_type, title, summary, body, target_paisa, target_period,
    stock_year_start_month, starts_on, ends_on, accepts_zakat
  ) values (
    app.current_institute_id(), cause_slug, kind, cause_title, cause_summary, cause_body, target, period,
    stock_month, first_day, last_day, coalesce(zakat, false)
  ) on conflict (institute_id, slug) do nothing;
  if found then return 'created'; end if;
  return 'duplicate';
exception when check_violation or not_null_violation then
  return 'invalid';
end
$function$;
--> statement-breakpoint
create function identity.transition_cause(session_id uuid, cause_id uuid, next_status text)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  today date := (now() at time zone 'Asia/Karachi')::date;
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  if next_status is null or next_status not in ('active', 'closed') then return 'invalid'; end if;

  update app.causes
  set status = next_status
  where institute_id = app.current_institute_id() and id = cause_id
    and (next_status = 'active' and status = 'draft' and (ends_on is null or ends_on >= today)
      or next_status = 'closed' and status = 'active');
  if found then return 'updated'; end if;
  return 'stale';
end
$function$;
--> statement-breakpoint
revoke all on function identity.read_causes(uuid),
  identity.create_cause(uuid, text, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean),
  identity.transition_cause(uuid, uuid, text) from public;
grant execute on function identity.read_causes(uuid),
  identity.create_cause(uuid, text, text, jsonb, jsonb, jsonb, bigint, text, smallint, date, date, boolean),
  identity.transition_cause(uuid, uuid, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
