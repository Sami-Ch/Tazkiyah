SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
CREATE TABLE "app"."spending_entries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"cause_id" uuid NOT NULL,
	"amount_paisa" bigint NOT NULL,
	"spent_on" date NOT NULL,
	"description" "app"."localized_text" NOT NULL,
	"receipt_media_id" uuid,
	"receipt_public" boolean DEFAULT true NOT NULL,
	"report_id" uuid,
	"status" text DEFAULT 'draft' NOT NULL,
	"recorded_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "spending_entries_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "spending_entries_amount_check" CHECK (amount_paisa between 100 and 99999999999900 and amount_paisa % 100 = 0),
	CONSTRAINT "spending_entries_status_check" CHECK (status in ('draft', 'recorded', 'reversed') and (status <> 'draft' or report_id is null))
);
--> statement-breakpoint
ALTER TABLE "app"."spending_entries" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app"."spending_reports" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"institute_id" uuid NOT NULL,
	"period_kind" text NOT NULL,
	"period_start" date NOT NULL,
	"period_end" date NOT NULL,
	"title" "app"."localized_text" NOT NULL,
	"notes" "app"."localized_text",
	"status" text DEFAULT 'draft' NOT NULL,
	"published_at" timestamp with time zone,
	"published_by" uuid,
	"created_by" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "spending_reports_institute_id_id_unique" UNIQUE("institute_id","id"),
	CONSTRAINT "spending_reports_period_check" CHECK (period_kind in ('daily', 'weekly', 'custom') and period_end >= period_start and (period_kind <> 'daily' or period_end = period_start)),
	CONSTRAINT "spending_reports_status_check" CHECK (status in ('draft', 'published') and (status = 'published') = (published_at is not null) and (published_at is null) = (published_by is null))
);
--> statement-breakpoint
ALTER TABLE "app"."spending_reports" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "app"."spending_entries" ADD CONSTRAINT "spending_entries_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."spending_entries" ADD CONSTRAINT "spending_entries_institute_id_cause_id_causes_institute_id_id_fk" FOREIGN KEY ("institute_id","cause_id") REFERENCES "app"."causes"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."spending_entries" ADD CONSTRAINT "spending_entries_institute_id_receipt_media_id_media_assets_institute_id_id_fk" FOREIGN KEY ("institute_id","receipt_media_id") REFERENCES "app"."media_assets"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."spending_entries" ADD CONSTRAINT "spending_entries_institute_id_report_id_spending_reports_institute_id_id_fk" FOREIGN KEY ("institute_id","report_id") REFERENCES "app"."spending_reports"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."spending_entries" ADD CONSTRAINT "spending_entries_institute_id_recorded_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","recorded_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."spending_reports" ADD CONSTRAINT "spending_reports_institute_id_institutes_id_fk" FOREIGN KEY ("institute_id") REFERENCES "app"."institutes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."spending_reports" ADD CONSTRAINT "spending_reports_institute_id_published_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","published_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."spending_reports" ADD CONSTRAINT "spending_reports_institute_id_created_by_users_institute_id_id_fk" FOREIGN KEY ("institute_id","created_by") REFERENCES "app"."users"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "spending_entries_cause" ON "app"."spending_entries" USING btree ("institute_id","cause_id","spent_on");--> statement-breakpoint
CREATE INDEX "spending_entries_report" ON "app"."spending_entries" USING btree ("institute_id","report_id") WHERE report_id is not null;--> statement-breakpoint
CREATE INDEX "spending_entries_receipt" ON "app"."spending_entries" USING btree ("institute_id","receipt_media_id") WHERE receipt_media_id is not null;--> statement-breakpoint
CREATE INDEX "spending_entries_recorded_by" ON "app"."spending_entries" USING btree ("institute_id","recorded_by");--> statement-breakpoint
CREATE INDEX "spending_reports_period" ON "app"."spending_reports" USING btree ("institute_id","period_start" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "spending_reports_published_by" ON "app"."spending_reports" USING btree ("institute_id","published_by") WHERE published_by is not null;--> statement-breakpoint
CREATE INDEX "spending_reports_created_by" ON "app"."spending_reports" USING btree ("institute_id","created_by");--> statement-breakpoint
ALTER TABLE "app"."allocations" ADD CONSTRAINT "allocations_institute_id_spending_entry_id_spending_entries_institute_id_id_fk" FOREIGN KEY ("institute_id","spending_entry_id") REFERENCES "app"."spending_entries"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_spending_entry_id_spending_entries_institute_id_id_fk" FOREIGN KEY ("institute_id","spending_entry_id") REFERENCES "app"."spending_entries"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."trail_events" ADD CONSTRAINT "trail_events_institute_id_spending_report_id_spending_reports_institute_id_id_fk" FOREIGN KEY ("institute_id","spending_report_id") REFERENCES "app"."spending_reports"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "trail_events_spending_entry" ON "app"."trail_events" USING btree ("institute_id","spending_entry_id") WHERE spending_entry_id is not null;--> statement-breakpoint
CREATE INDEX "trail_events_spending_report" ON "app"."trail_events" USING btree ("institute_id","spending_report_id") WHERE spending_report_id is not null;--> statement-breakpoint
CREATE POLICY "iso" ON "app"."spending_entries" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "spending_entries_staff_read" ON "app"."spending_entries" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin')) or (select app.has_role('finance_officer')));--> statement-breakpoint
CREATE POLICY "iso" ON "app"."spending_reports" AS RESTRICTIVE FOR ALL TO "tazkiyah_app", "tazkiyah_auth" USING (institute_id = (select app.current_institute_id())) WITH CHECK (institute_id = (select app.current_institute_id()));--> statement-breakpoint
CREATE POLICY "spending_reports_staff_read" ON "app"."spending_reports" AS PERMISSIVE FOR SELECT TO "tazkiyah_app" USING ((select app.has_role('admin')) or (select app.has_role('finance_officer')));
--> statement-breakpoint
-- Admins and finance officers read entries and reports (04 §6.4). Writes go
-- through definer functions (P2-E1-T01, T02), as for donations.
revoke all on app.spending_entries, app.spending_reports from public, tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
grant select on app.spending_entries, app.spending_reports to tazkiyah_app;
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.spending_entries
for each row execute function app.audit_row_change();
--> statement-breakpoint
create trigger audit_row_change after insert or update on app.spending_reports
for each row execute function app.audit_row_change();
--> statement-breakpoint
-- An entry spends from an active or closed cause (06 §5.3), and its photo is
-- a receipt upload (REQ-ROL-007). A draft is free to change or delete (06
-- §9.2). From "Record batch" on, only the description, receipt and report may
-- change, and status only from recorded to reversed; a wrong amount, cause or
-- date is a reversal (§9.7, D-124). A published report gains or loses no
-- entries.
create function app.spending_entries_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op = 'DELETE' then
    if old.status <> 'draft' then
      raise exception 'spending entry % is recorded; reverse it instead', old.id
        using errcode = 'object_not_in_prerequisite_state';
    end if;
    return old;
  end if;
  if new.receipt_media_id is distinct from (case when tg_op = 'UPDATE' then old.receipt_media_id end)
    and new.receipt_media_id is not null and not exists (
      select from app.media_assets m
      where m.institute_id = new.institute_id and m.id = new.receipt_media_id and m.purpose = 'receipt'
    )
  then
    raise exception 'a spending entry photo must be a receipt upload' using errcode = 'check_violation';
  end if;
  if new.cause_id is distinct from (case when tg_op = 'UPDATE' then old.cause_id end)
    and not exists (select from app.causes c
      where c.institute_id = new.institute_id and c.id = new.cause_id and c.status in ('active', 'closed'))
  then
    raise exception 'spending needs an active or closed cause' using errcode = 'check_violation';
  end if;
  if new.report_id is distinct from (case when tg_op = 'UPDATE' then old.report_id end)
    and exists (select from app.spending_reports r
      where r.institute_id = new.institute_id and r.status = 'published'
        and r.id in (new.report_id, case when tg_op = 'UPDATE' then old.report_id end))
  then
    raise exception 'a published spending report cannot gain or lose entries'
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if tg_op = 'INSERT' then
    if new.status = 'reversed' then
      raise exception 'a spending entry cannot start as reversed' using errcode = 'check_violation';
    end if;
    return new;
  end if;
  if new.status is distinct from old.status
    and not (old.status = 'draft' and new.status = 'recorded')
    and not (old.status = 'recorded' and new.status = 'reversed')
  then
    raise exception 'spending entry % cannot move from % to %', old.id, old.status, new.status
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if old.status <> 'draft'
    and to_jsonb(new) - array['description', 'receipt_media_id', 'receipt_public', 'report_id', 'status']
      is distinct from to_jsonb(old) - array['description', 'receipt_media_id', 'receipt_public', 'report_id', 'status']
  then
    raise exception 'spending entry % is recorded: only its text, receipt and report may change', old.id
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create trigger spending_entries_rules before insert or update or delete on app.spending_entries
for each row execute function app.spending_entries_rules();
--> statement-breakpoint
-- A published report has written reported events (P2-E2-T41), so it stays as
-- published.
create function app.spending_reports_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if old.status = 'published' then
    raise exception 'spending report % is published and cannot change', old.id
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end
$function$;
--> statement-breakpoint
create trigger spending_reports_rules before update or delete on app.spending_reports
for each row execute function app.spending_reports_rules();
--> statement-breakpoint
-- A spend must match a recorded entry of its own cause, and the entry's
-- effective matches stay within its amount (§9.2).
create or replace function app.allocations_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
declare
  gift app.donations%rowtype;
  source app.allocations%rowtype;
  original app.allocations%rowtype;
begin
  select d.* into gift from app.donations d
  where d.institute_id = new.institute_id and d.id = new.donation_id
  for no key update;
  if not found then
    raise exception 'allocation needs a donation of its institute' using errcode = 'foreign_key_violation';
  end if;
  if new.donation_type <> gift.donation_type then
    raise exception 'allocation type % must equal the donation type %', new.donation_type, gift.donation_type
      using errcode = 'check_violation';
  end if;

  if new.is_reversal then
    select a.* into original from app.allocations a
    where a.institute_id = new.institute_id and a.id = new.reverses_allocation_id;
    if original.is_reversal or original.donation_id <> new.donation_id or original.kind <> new.kind
      or original.amount_paisa <> new.amount_paisa or original.donation_type <> new.donation_type
      or original.cause_id is distinct from new.cause_id
      or original.from_allocation_id is distinct from new.from_allocation_id
      or original.spending_entry_id is distinct from new.spending_entry_id
      or original.target_institute_id is distinct from new.target_institute_id
    then
      raise exception 'a reversal must mirror the allocation it reverses, which must not be a reversal'
        using errcode = 'check_violation';
    end if;
  elsif new.kind = 'to_spending' then
    select a.* into source from app.allocations a
    where a.institute_id = new.institute_id and a.id = new.from_allocation_id
    for no key update;
    if source.kind <> 'to_cause' or source.is_reversal or source.donation_id <> new.donation_id
      or source.cause_id <> new.cause_id
    then
      raise exception 'spending must draw on a cause allocation of the same donation and cause'
        using errcode = 'check_violation';
    end if;
    -- The entry is locked too, so its per-entry cap is checked on a stable ledger.
    if not exists (
      select from app.spending_entries e
      where e.institute_id = new.institute_id and e.id = new.spending_entry_id
        and e.cause_id = new.cause_id and e.status = 'recorded'
      for no key update
    ) then
      raise exception 'spending must match a recorded spending entry of the same cause'
        using errcode = 'check_violation';
    end if;
  elsif new.kind = 'to_institute' then
    -- REQ-TRL-014: the shape exists, but only a platform fund may use it (§9.5).
    if not exists (select from app.institutes i where i.id = new.institute_id and i.kind = 'platform_fund') then
      raise exception 'transfers to an institute are only possible from a platform fund'
        using errcode = 'check_violation';
    end if;
    if new.target_institute_id = new.institute_id or not exists (
      select from app.institutes i where i.id = new.target_institute_id and i.kind = 'institute'
    ) then
      raise exception 'a transfer must go to another institute' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create or replace function app.allocations_sum_check() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
declare
  placed bigint;
  cap bigint;
  source_id uuid;
begin
  select coalesce(sum(a.amount_paisa), 0) into placed from app.allocations a
  where a.institute_id = new.institute_id and a.donation_id = new.donation_id
    and a.kind in ('to_cause', 'to_institute') and not a.is_reversal
    and not exists (select from app.allocations r
      where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id);
  select d.amount_paisa into cap from app.donations d
  where d.institute_id = new.institute_id and d.id = new.donation_id;
  if placed > cap then
    raise exception 'donation % would have % paisa allocated but holds only %', new.donation_id, placed, cap
      using errcode = 'check_violation';
  end if;

  source_id := case
    when new.kind = 'to_spending' then new.from_allocation_id
    when new.kind = 'to_cause' and new.is_reversal then new.reverses_allocation_id
  end;
  if source_id is not null then
    select coalesce(sum(a.amount_paisa), 0) into placed from app.allocations a
    where a.institute_id = new.institute_id and a.from_allocation_id = source_id and not a.is_reversal
      and not exists (select from app.allocations r
        where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id);
    select case when exists (select from app.allocations r
        where r.institute_id = s.institute_id and r.reverses_allocation_id = s.id)
      then 0 else s.amount_paisa end into cap
    from app.allocations s where s.institute_id = new.institute_id and s.id = source_id;
    if placed > cap then
      raise exception 'allocation % would have % paisa spent from it but holds only %', source_id, placed, cap
        using errcode = 'check_violation';
    end if;
  end if;
  if new.spending_entry_id is not null then
    select coalesce(sum(case when a.is_reversal then -a.amount_paisa else a.amount_paisa end), 0) into placed
    from app.allocations a
    where a.institute_id = new.institute_id and a.spending_entry_id = new.spending_entry_id
      and a.kind = 'to_spending';
    select e.amount_paisa into cap from app.spending_entries e
    where e.institute_id = new.institute_id and e.id = new.spending_entry_id;
    if placed > cap then
      raise exception 'spending entry % would be matched for % paisa but costs only %',
        new.spending_entry_id, placed, cap using errcode = 'check_violation';
    end if;
  end if;
  return null;
end
$function$;
--> statement-breakpoint
RESET ROLE;
