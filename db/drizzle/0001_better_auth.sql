SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The administrator provisions the runtime login and schema ownership.
RESET ROLE;
--> statement-breakpoint
do $auth_role$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'tazkiyah_auth') then
    create role tazkiyah_auth nologin;
  end if;
  if exists (
    select 1 from pg_catalog.pg_roles r where r.rolname = 'tazkiyah_auth'
      and (r.rolsuper or r.rolbypassrls or r.rolcreaterole or r.rolcreatedb or r.rolreplication
        or exists (select 1 from pg_catalog.pg_auth_members m where m.member = r.oid))
  ) then
    raise exception 'The auth role must have no elevated privileges or memberships';
  end if;
  execute format('grant connect on database %I to tazkiyah_auth', current_database());
end
$auth_role$;
--> statement-breakpoint
CREATE SCHEMA "identity" AUTHORIZATION tazkiyah_schema_owner;
--> statement-breakpoint
SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "identity"."accounts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid DEFAULT app.current_institute_id() NOT NULL,
	"user_id" uuid NOT NULL,
	"provider_id" text NOT NULL,
	"account_id" text NOT NULL,
	"password" text,
	"access_token" text,
	"refresh_token" text,
	"id_token" text,
	"access_token_expires_at" timestamp with time zone,
	"refresh_token_expires_at" timestamp with time zone,
	"scope" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "accounts_institute_id_provider_id_account_id_unique" UNIQUE("institute_id","provider_id","account_id")
);
--> statement-breakpoint
ALTER TABLE "identity"."accounts" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "identity"."rate_limit" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid DEFAULT app.current_institute_id() NOT NULL,
	"key" text NOT NULL,
	"count" integer NOT NULL,
	"last_request" bigint NOT NULL,
	CONSTRAINT "rate_limit_institute_id_key_unique" UNIQUE("institute_id","key")
);
--> statement-breakpoint
ALTER TABLE "identity"."rate_limit" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "identity"."sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid DEFAULT app.current_institute_id() NOT NULL,
	"user_id" uuid NOT NULL,
	"token" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ip_address" text,
	"user_agent" text,
	CONSTRAINT "sessions_institute_id_token_unique" UNIQUE("institute_id","token")
);
--> statement-breakpoint
ALTER TABLE "identity"."sessions" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "identity"."two_factor" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid DEFAULT app.current_institute_id() NOT NULL,
	"user_id" uuid NOT NULL,
	"secret" text NOT NULL,
	"backup_codes" text NOT NULL,
	"verified" boolean DEFAULT true NOT NULL,
	"failed_verification_count" integer DEFAULT 0 NOT NULL,
	"locked_until" timestamp with time zone,
	CONSTRAINT "two_factor_institute_id_user_id_unique" UNIQUE("institute_id","user_id")
);
--> statement-breakpoint
ALTER TABLE "identity"."two_factor" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "identity"."verification" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid DEFAULT app.current_institute_id() NOT NULL,
	"identifier" text NOT NULL,
	"value" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "identity"."verification" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."users" ADD COLUMN "email_verified" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."users" ADD COLUMN "auth_image" text;--> statement-breakpoint
ALTER TABLE "app"."users" ADD COLUMN "two_factor_enabled" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."users" ADD COLUMN "updated_at" timestamp with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "identity"."accounts" ADD CONSTRAINT "accounts_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity"."accounts" ADD CONSTRAINT "accounts_institute_id_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity"."rate_limit" ADD CONSTRAINT "rate_limit_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity"."sessions" ADD CONSTRAINT "sessions_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity"."sessions" ADD CONSTRAINT "sessions_institute_id_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity"."two_factor" ADD CONSTRAINT "two_factor_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity"."two_factor" ADD CONSTRAINT "two_factor_institute_id_user_id_users_institute_id_id_fk" FOREIGN KEY ("institute_id","user_id") REFERENCES "app"."users"("institute_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "identity"."verification" ADD CONSTRAINT "verification_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "accounts_institute_id_user_id_index" ON "identity"."accounts" USING btree ("institute_id","user_id");--> statement-breakpoint
CREATE INDEX "rate_limit_institute_id_last_request_index" ON "identity"."rate_limit" USING btree ("institute_id","last_request");--> statement-breakpoint
CREATE INDEX "sessions_institute_id_user_id_index" ON "identity"."sessions" USING btree ("institute_id","user_id");--> statement-breakpoint
CREATE INDEX "verification_institute_id_identifier_index" ON "identity"."verification" USING btree ("institute_id","identifier");--> statement-breakpoint
CREATE POLICY "auth_iso" ON "app"."users" AS RESTRICTIVE FOR ALL TO "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "auth_user_read" ON "app"."users" AS PERMISSIVE FOR SELECT TO "tazkiyah_auth" USING (status in ('active', 'left'));--> statement-breakpoint
CREATE POLICY "auth_user_update" ON "app"."users" AS PERMISSIVE FOR UPDATE TO "tazkiyah_auth" USING (status in ('active', 'left')) WITH CHECK (status in ('active', 'left'));--> statement-breakpoint
CREATE POLICY "iso" ON "identity"."accounts" AS RESTRICTIVE FOR ALL TO "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "auth_access" ON "identity"."accounts" AS PERMISSIVE FOR ALL TO "tazkiyah_auth" USING (true) WITH CHECK (true);--> statement-breakpoint
CREATE POLICY "iso" ON "identity"."rate_limit" AS RESTRICTIVE FOR ALL TO "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "auth_access" ON "identity"."rate_limit" AS PERMISSIVE FOR ALL TO "tazkiyah_auth" USING (true) WITH CHECK (true);--> statement-breakpoint
CREATE POLICY "iso" ON "identity"."sessions" AS RESTRICTIVE FOR ALL TO "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "auth_access" ON "identity"."sessions" AS PERMISSIVE FOR ALL TO "tazkiyah_auth" USING (true) WITH CHECK (true);--> statement-breakpoint
CREATE POLICY "iso" ON "identity"."two_factor" AS RESTRICTIVE FOR ALL TO "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "auth_access" ON "identity"."two_factor" AS PERMISSIVE FOR ALL TO "tazkiyah_auth" USING (true) WITH CHECK (true);--> statement-breakpoint
CREATE POLICY "iso" ON "identity"."verification" AS RESTRICTIVE FOR ALL TO "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "auth_access" ON "identity"."verification" AS PERMISSIVE FOR ALL TO "tazkiyah_auth" USING (true) WITH CHECK (true);
--> statement-breakpoint
revoke all on schema identity from public;
grant usage on schema app, identity to tazkiyah_auth;
grant execute on function app.resolve_institute(text), app.current_institute_id() to tazkiyah_auth;
grant select on app.users, identity.accounts to tazkiyah_auth;
grant update (two_factor_enabled, updated_at) on app.users to tazkiyah_auth;
grant select, insert, update, delete
  on identity.sessions, identity.verification, identity.two_factor, identity.rate_limit to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
