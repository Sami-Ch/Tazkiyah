SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."allocations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"donation_id" uuid NOT NULL,
	"cause_id" uuid NOT NULL,
	"kind" text DEFAULT 'to_cause' NOT NULL,
	"donation_type" text NOT NULL,
	"amount_paisa" bigint NOT NULL,
	"created_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "allocations_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "allocations_manual_kind_check" CHECK (kind = 'to_cause'),
	CONSTRAINT "allocations_type_check" CHECK (donation_type in ('zakat', 'sadaqah', 'general')),
	CONSTRAINT "allocations_amount_check" CHECK (amount_paisa > 0)
);
--> statement-breakpoint
ALTER TABLE "app"."allocations" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."donations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"operation_id" uuid NOT NULL,
	"bank_account_id" uuid NOT NULL,
	"bank_reference" text NOT NULL,
	"credited_on" date NOT NULL,
	"amount_paisa" bigint NOT NULL,
	"currency" text DEFAULT 'PKR' NOT NULL,
	"method" text DEFAULT 'bank_transfer' NOT NULL,
	"frequency" text DEFAULT 'one_off' NOT NULL,
	"donation_type" text NOT NULL,
	"donor_id" uuid,
	"cause_id" uuid,
	"receipt_number" text NOT NULL,
	"receipt_locale" text NOT NULL,
	"is_anonymous" boolean DEFAULT true NOT NULL,
	"status" text DEFAULT 'recorded' NOT NULL,
	"recorded_by" uuid NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "donations_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "donations_institute_id_operation_id_unique" UNIQUE("institute_id","operation_id"),
	CONSTRAINT "donations_institute_id_receipt_number_unique" UNIQUE("institute_id","receipt_number"),
	CONSTRAINT "donations_amount_check" CHECK (amount_paisa between 100 and 99999999999900 and amount_paisa % 100 = 0),
	CONSTRAINT "donations_bank_reference_check" CHECK (length(bank_reference) between 1 and 120 and bank_reference = btrim(bank_reference) and bank_reference !~ '[[:cntrl:]]'),
	CONSTRAINT "donations_manual_source_check" CHECK (currency = 'PKR' and method = 'bank_transfer' and frequency = 'one_off'),
	CONSTRAINT "donations_type_check" CHECK (donation_type in ('zakat', 'sadaqah', 'general')),
	CONSTRAINT "donations_locale_check" CHECK (receipt_locale in ('en', 'ur')),
	CONSTRAINT "donations_status_check" CHECK (status in ('recorded', 'reversed')),
	CONSTRAINT "donations_anonymity_check" CHECK (is_anonymous)
);
--> statement-breakpoint
ALTER TABLE "app"."donations" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."donors" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"email" text NOT NULL,
	"preferred_language" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "donors_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "donors_institute_id_email_unique" UNIQUE("institute_id","email"),
	CONSTRAINT "donors_email_check" CHECK (length(email) <= 254 and email = lower(btrim(email)) and email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'),
	CONSTRAINT "donors_language_check" CHECK (preferred_language in ('en', 'ur'))
);
--> statement-breakpoint
ALTER TABLE "app"."donors" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."receipt_counters" (
	"institute_id" uuid NOT NULL,
	"year" smallint NOT NULL,
	"last_number" bigint NOT NULL,
	CONSTRAINT "receipt_counters_institute_id_year_pk" PRIMARY KEY("institute_id","year"),
	CONSTRAINT "receipt_counters_range_check" CHECK (year between 1 and 9999 and last_number > 0)
);
--> statement-breakpoint
ALTER TABLE "app"."receipt_counters" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."trail_events" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."trail_events_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"institute_id" uuid NOT NULL,
	"donation_id" uuid NOT NULL,
	"event_type" text NOT NULL,
	"credited_on" date NOT NULL,
	"amount_paisa" bigint NOT NULL,
	"cause_id" uuid,
	"allocation_id" uuid,
	"recorded_by" uuid NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "trail_events_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "trail_events_institute_id_allocation_id_unique" UNIQUE("institute_id","allocation_id"),
	CONSTRAINT "trail_events_amount_check" CHECK (amount_paisa > 0),
	CONSTRAINT "trail_events_manual_shape_check" CHECK ((event_type = 'received' and cause_id is null and allocation_id is null) or (event_type = 'allocated' and cause_id is not null and allocation_id is not null))
);
--> statement-breakpoint
ALTER TABLE "app"."trail_events" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."institute_bank_accounts" ADD COLUMN "show_on_donate" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_institute_id_donation_id_donations_institute_id_id_fk" FOREIGN KEY ("institute_id","donation_id") REFERENCES "app"."donations"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_institute_id_cause_id_causes_institute_id_id_fk" FOREIGN KEY ("institute_id","cause_id") REFERENCES "app"."causes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_institute_id_created_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","created_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_bank_account_id_institute_bank_accounts_institute_id_id_fk" FOREIGN KEY ("institute_id","bank_account_id") REFERENCES "app"."institute_bank_accounts"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_cause_id_causes_institute_id_id_fk" FOREIGN KEY ("institute_id","cause_id") REFERENCES "app"."causes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_donor_id_donors_institute_id_id_fk" FOREIGN KEY ("institute_id","donor_id") REFERENCES "app"."donors"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_recorded_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","recorded_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."donors" ADD CONSTRAINT "donors_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."receipt_counters" ADD CONSTRAINT "receipt_counters_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_donation_id_donations_institute_id_id_fk" FOREIGN KEY ("institute_id","donation_id") REFERENCES "app"."donations"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_cause_id_causes_institute_id_id_fk" FOREIGN KEY ("institute_id","cause_id") REFERENCES "app"."causes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_allocation_id_allocations_institute_id_id_fk" FOREIGN KEY ("institute_id","allocation_id") REFERENCES "app"."allocations"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_recorded_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","recorded_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "donations_recorded_bank_reference" ON "app"."donations" USING btree ("institute_id","bank_account_id","bank_reference") WHERE status = 'recorded';--> statement-breakpoint
CREATE INDEX "donations_institute_id_bank_account_id_credited_on_amount_paisa_index" ON "app"."donations" USING btree ("institute_id","bank_account_id","credited_on","amount_paisa");--> statement-breakpoint
CREATE INDEX "donations_institute_id_recorded_at_id_index" ON "app"."donations" USING btree ("institute_id","recorded_at","id");--> statement-breakpoint
CREATE UNIQUE INDEX "trail_events_one_received" ON "app"."trail_events" USING btree ("institute_id","donation_id") WHERE event_type = 'received';--> statement-breakpoint
CREATE POLICY "iso" ON "app"."allocations" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."donations" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."donors" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."receipt_counters" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."trail_events" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));
--> statement-breakpoint
create function identity.is_finance_session(session_id uuid) returns boolean
language sql stable
set search_path = pg_catalog, pg_temp
return (app.has_role('admin') or app.has_role('finance_officer')) and exists (
  select 1 from identity.sessions s
  join app.users u on (u.institute_id, u.id) = (s.institute_id, s.user_id)
  join identity.two_factor f on (f.institute_id, f.user_id) = (s.institute_id, s.user_id)
  where s.id = session_id and s.institute_id = app.current_institute_id()
    and s.user_id = app.current_user_id() and s.expires_at > now()
    and s.updated_at > now() - interval '30 minutes' and s.two_factor_verified_at is not null
    and u.status = 'active' and u.two_factor_enabled and not u.must_change_password and f.verified
);
--> statement-breakpoint
create function identity.read_manual_donation_options(session_id uuid)
returns table (allowed boolean, bank_accounts jsonb, causes jsonb)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select access.allowed,
    case when access.allowed then coalesce((
      select jsonb_agg(jsonb_build_object('id', b.id, 'label', b.label,
        'bank_name', b.bank_name, 'for_donation_types', b.for_donation_types)
        order by b.display_order, b.id)
      from app.institute_bank_accounts b
      where b.institute_id = app.current_institute_id() and b.is_active
    ), '[]') else '[]' end,
    case when access.allowed then coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'slug', c.slug,
        'cause_type', c.cause_type, 'status', c.status, 'starts_on', c.starts_on,
        'ends_on', c.ends_on, 'accepts_zakat', c.accepts_zakat)
        order by c.display_order, c.slug)
      from app.causes c
      where c.institute_id = app.current_institute_id() and c.status = 'active'
    ), '[]') else '[]' end
  from (select identity.is_finance_session(session_id) as allowed) access
$function$;
--> statement-breakpoint
create function identity.list_manual_donations(session_id uuid)
returns table (id uuid, receipt_number text, credited_on date, recorded_at timestamptz,
  amount_paisa bigint, donation_type text, cause_id uuid, is_anonymous boolean)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select d.id, d.receipt_number, d.credited_on, d.recorded_at,
    d.amount_paisa, d.donation_type, d.cause_id, d.is_anonymous
  from app.donations d
  where identity.is_finance_session(session_id)
    and d.institute_id = app.current_institute_id() and d.status = 'recorded'
  order by d.recorded_at desc, d.id desc
  limit 50
$function$;
--> statement-breakpoint
create function identity.record_manual_donation(
  p_session_id uuid, p_operation_id uuid, p_bank_account_id uuid, p_bank_reference text,
  p_credited_on date, p_amount_paisa bigint, p_donation_type text, p_cause_id uuid,
  p_donor_email text, p_receipt_locale text, p_anonymous boolean,
  p_confirm_large boolean, p_confirm_similar boolean
) returns table (code text, donation_id uuid, receipt_number text)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  reference text := btrim(p_bank_reference);
  guest_email text := nullif(lower(btrim(p_donor_email)), '');
  receipt_year smallint := extract(year from today);
  receipt_prefix text;
  receipt_sequence bigint;
  receipt text;
  prior app.donations%rowtype;
  guest_id uuid;
  recorded_id uuid;
  allocation_id uuid;
begin
  if not identity.is_finance_session(p_session_id) then
    return query select 'denied'::text, null::uuid, null::text;
    return;
  end if;
  if p_operation_id is null or p_bank_account_id is null or reference is null
    or length(reference) not between 1 and 120 or reference ~ '[[:cntrl:]]'
    or p_credited_on is null or p_credited_on not between date '1900-01-01' and today
    or p_amount_paisa is null or p_amount_paisa not between 100 and 99999999999900
    or p_amount_paisa % 100 <> 0
    or p_donation_type is null or p_donation_type not in ('zakat', 'sadaqah', 'general')
    or p_receipt_locale is null or p_receipt_locale not in ('en', 'ur')
    or p_anonymous is distinct from true
    or (guest_email is not null and (length(guest_email) > 254
      or guest_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'))
  then
    return query select 'invalid'::text, null::uuid, null::text;
    return;
  end if;

  -- Serialize retries even when a reused operation changes the bank account.
  perform pg_advisory_xact_lock(hashtextextended(tenant::text || '/' || p_operation_id::text, 294751));
  select d.* into prior from app.donations d
  where d.institute_id = tenant and d.operation_id = p_operation_id;
  if found then
    if prior.bank_account_id = p_bank_account_id and prior.bank_reference = reference
      and prior.credited_on = p_credited_on and prior.amount_paisa = p_amount_paisa
      and prior.donation_type = p_donation_type and prior.cause_id is not distinct from p_cause_id
      and prior.receipt_locale = p_receipt_locale
      and guest_email is not distinct from (
        select guest.email from app.donors guest where guest.institute_id = tenant and guest.id = prior.donor_id
      )
    then return query select 'existing'::text, prior.id, prior.receipt_number;
    else return query select 'operation_conflict'::text, null::uuid, null::text;
    end if;
    return;
  end if;

  -- Serialize reference and similar-credit checks for this account.
  perform from app.institute_bank_accounts b
  where b.institute_id = tenant and b.id = p_bank_account_id and b.is_active
    and p_donation_type = any (b.for_donation_types)
  for update;
  if not found then
    return query select 'bank_unavailable'::text, null::uuid, null::text;
    return;
  end if;
  if exists (
    select from app.donations d where d.institute_id = tenant and d.bank_account_id = p_bank_account_id
      and d.bank_reference = reference and d.status = 'recorded'
  ) then
    return query select 'bank_reference_conflict'::text, null::uuid, null::text;
    return;
  end if;
  if p_amount_paisa > 100000000 and p_confirm_large is distinct from true then
    return query select 'large_confirmation_required'::text, null::uuid, null::text;
    return;
  end if;
  if p_confirm_similar is distinct from true and exists (
    select from app.donations d where d.institute_id = tenant and d.bank_account_id = p_bank_account_id
      and d.credited_on = p_credited_on and d.amount_paisa = p_amount_paisa and d.status = 'recorded'
  ) then
    return query select 'similar_confirmation_required'::text, null::uuid, null::text;
    return;
  end if;

  if p_cause_id is not null then
    -- The public view closes ended campaigns by date. Historic in-window credits remain eligible.
    perform from app.causes c
    where c.institute_id = tenant and c.id = p_cause_id and c.status = 'active'
      and (c.starts_on is null or p_credited_on >= c.starts_on)
      and (c.ends_on is null or p_credited_on <= c.ends_on)
      and (p_donation_type <> 'zakat' or c.accepts_zakat)
    for update;
    if not found then
      return query select 'cause_unavailable'::text, null::uuid, null::text;
      return;
    end if;
  end if;

  select settings.receipt_prefix into receipt_prefix
  from app.institute_settings settings where settings.institute_id = tenant;
  if not found then
    return query select 'invalid'::text, null::uuid, null::text;
    return;
  end if;

  if guest_email is not null then
    insert into app.donors as guest (institute_id, email, preferred_language)
    values (tenant, guest_email, p_receipt_locale)
    on conflict (institute_id, email) do nothing
    returning guest.id into guest_id;
    if guest_id is null then
      select guest.id into strict guest_id from app.donors guest
      where guest.institute_id = tenant and guest.email = guest_email;
    end if;
  end if;

  insert into app.receipt_counters as counters (institute_id, year, last_number)
  values (tenant, receipt_year, 1)
  on conflict (institute_id, year) do update set last_number = counters.last_number + 1
  returning counters.last_number into receipt_sequence;
  receipt := receipt_prefix || '-' || receipt_year || '-' ||
    lpad(receipt_sequence::text, greatest(5, length(receipt_sequence::text)), '0');

  insert into app.donations as d (institute_id, operation_id, bank_account_id, bank_reference,
    credited_on, amount_paisa, donation_type, donor_id, cause_id, receipt_number, receipt_locale, recorded_by)
  values (tenant, p_operation_id, p_bank_account_id, reference, p_credited_on,
    p_amount_paisa, p_donation_type, guest_id, p_cause_id, receipt, p_receipt_locale, actor)
  returning d.id into recorded_id;

  insert into app.trail_events (institute_id, donation_id, event_type, credited_on, amount_paisa, recorded_by)
  values (tenant, recorded_id, 'received', p_credited_on, p_amount_paisa, actor);
  if p_cause_id is not null then
    insert into app.allocations as a (institute_id, donation_id, cause_id, donation_type, amount_paisa, created_by)
    values (tenant, recorded_id, p_cause_id, p_donation_type, p_amount_paisa, actor)
    returning a.id into allocation_id;
    insert into app.trail_events (institute_id, donation_id, event_type, credited_on,
      amount_paisa, cause_id, allocation_id, recorded_by)
    values (tenant, recorded_id, 'allocated', p_credited_on, p_amount_paisa, p_cause_id, allocation_id, actor);
  end if;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'donations.recorded', 'donations', recorded_id::text,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;

  return query select 'recorded'::text, recorded_id, receipt;
end
$function$;
--> statement-breakpoint
create trigger append_only_rows before update or delete on app.allocations
for each row execute function app.forbid_change();
--> statement-breakpoint
create trigger append_only_truncate before truncate on app.allocations
for each statement execute function app.forbid_change();
--> statement-breakpoint
create trigger append_only_rows before update or delete on app.trail_events
for each row execute function app.forbid_change();
--> statement-breakpoint
create trigger append_only_truncate before truncate on app.trail_events
for each statement execute function app.forbid_change();
--> statement-breakpoint
revoke all on function identity.is_finance_session(uuid), identity.read_manual_donation_options(uuid),
  identity.list_manual_donations(uuid), identity.record_manual_donation(uuid, uuid, uuid, text, date, bigint,
    text, uuid, text, text, boolean, boolean, boolean) from public;
--> statement-breakpoint
grant execute on function identity.read_manual_donation_options(uuid), identity.list_manual_donations(uuid),
  identity.record_manual_donation(uuid, uuid, uuid, text, date, bigint, text, uuid, text, text,
    boolean, boolean, boolean) to tazkiyah_auth;
--> statement-breakpoint
create or replace view public_api.institute_public with (security_barrier = true) as
select s.institute_id, s.name, s.short_name, s.parent_body, s.theme, s.address,
  jsonb_strip_nulls(jsonb_build_object(
    'phone', s.contact -> 'phone',
    'whatsapp', s.contact -> 'whatsapp',
    'email', s.contact -> 'email',
    'map_url', s.contact -> 'map_url'
  )) as contact,
  s.languages, s.default_language, s.timezone, s.base_currency, s.founded_year, s.enabled_modules,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id,
      'label', a.label,
      'bank_name', a.bank_name,
      'account_title', a.account_title,
      'account_number', a.account_number,
      'iban', a.iban,
      'branch', a.branch,
      'for_donation_types', a.for_donation_types
    ) order by a.display_order, a.id)
    from app.institute_bank_accounts a
    where a.institute_id = s.institute_id and a.is_active and a.show_on_donate
  ), '[]'::jsonb) as bank_accounts
from app.institute_settings s
join app.institutes i on i.id = s.institute_id
where s.institute_id = app.current_institute_id()
  and i.status = 'active' and i.kind = 'institute';
--> statement-breakpoint
grant select (address, contact, bank_accounts) on public_api.institute_public to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
