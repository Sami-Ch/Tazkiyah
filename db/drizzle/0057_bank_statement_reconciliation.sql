SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "statement_audit_id" bigint;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD COLUMN "statement_matched" boolean;--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_institute_id_statement_audit_id_audit_log_institute_id_id_fk" FOREIGN KEY ("institute_id","statement_audit_id") REFERENCES "app"."audit_log"("institute_id","id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "donations_statement_audit" ON "app"."donations" USING btree ("institute_id","statement_audit_id");--> statement-breakpoint
ALTER TABLE "app"."donations" ADD CONSTRAINT "donations_statement_check" CHECK ((statement_audit_id is null) = (statement_matched is null) and (statement_audit_id is null or method = 'bank_transfer'));
--> statement-breakpoint
create or replace function app.donations_column_lock() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
begin
  if tg_op <> 'UPDATE' then
    raise exception 'donations cannot be deleted; record a reversal instead'
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if to_jsonb(new) - array['is_anonymous', 'trail_public', 'status', 'statement_audit_id', 'statement_matched']
    is distinct from to_jsonb(old) - array['is_anonymous', 'trail_public', 'status', 'statement_audit_id', 'statement_matched']
  then
    raise exception 'donation % is locked: record a reversal to correct its details', old.id
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if new.status is distinct from old.status
    and not (old.status = 'recorded' and new.status = 'reversed')
  then
    raise exception 'donation % cannot move from % to %', old.id, old.status, new.status
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  return new;
end
$function$;
--> statement-breakpoint
create function identity.read_statement_accounts(p_session uuid)
returns table (id uuid, label jsonb, bank_name text, is_active boolean)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select b.id, b.label::jsonb, b.bank_name, b.is_active
  from app.institute_bank_accounts b
  where b.institute_id = app.current_institute_id() and identity.is_finance_session(p_session)
  order by b.is_active desc, b.display_order, b.id
$function$;
--> statement-breakpoint
create function identity.read_bank_statement(p_session uuid, p_bank uuid, p_from date, p_to date)
returns jsonb
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select jsonb_build_object('review', gifts.review, 'transfers', gifts.transfers, 'otherCredits', credits.items)
  from app.institute_bank_accounts b
  cross join lateral (
    select md5(coalesce(string_agg(d.id::text || ':' || coalesce(d.statement_audit_id::text, ''), ',' order by d.id), '')) as review,
      coalesce(jsonb_agg(jsonb_build_object(
        'id', d.id, 'receipt_number', d.receipt_number, 'credited_on', d.credited_on,
        'amount_paisa', d.amount_paisa::text, 'reference_tail', right(d.bank_reference, 4),
        'matched', d.statement_matched, 'statement_from', a.changes -> 'statement_from',
        'statement_to', a.changes -> 'statement_to'
      ) order by d.credited_on, d.receipt_number), '[]') as transfers
    from app.donations d
    left join app.audit_log a on (a.institute_id, a.id) = (d.institute_id, d.statement_audit_id)
    where (d.institute_id, d.bank_account_id) = (b.institute_id, b.id)
      and d.credited_on between p_from and p_to and d.method = 'bank_transfer' and d.status = 'recorded'
  ) gifts
  cross join lateral (
    select coalesce(jsonb_agg(jsonb_build_object('id', a.id::text,
      'credited_on', a.changes -> 'credited_on', 'amount_paisa', a.changes -> 'amount_paisa')
      order by a.changes ->> 'credited_on', a.id), '[]') as items
    from app.audit_log a
    where a.institute_id = b.institute_id and a.action = 'bank_statement.non_donation'
      and a.changes ->> 'bank_account_id' = b.id::text
      and a.changes ->> 'credited_on' between to_char(p_from, 'YYYY-MM-DD') and to_char(p_to, 'YYYY-MM-DD')
  ) credits
  where b.institute_id = app.current_institute_id() and b.id = p_bank
    and p_from between date '1900-01-01' and p_to and p_to <= (now() at time zone 'Asia/Karachi')::date
    and identity.is_finance_session(p_session)
$function$;
--> statement-breakpoint
create function identity.close_bank_statement(
  p_session uuid, p_bank uuid, p_from date, p_to date, p_review text, p_matched uuid[], p_operation uuid
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  audit_id bigint;
  snapshot jsonb;
  fingerprint text;
  previous text;
  matched_count integer;
  missing_count integer;
  matched_total numeric;
begin
  if not identity.is_finance_session(p_session) then return 'denied'; end if;
  if p_operation is null or p_review is null or p_review !~ '^[0-9a-f]{32}$'
    or p_matched is null or exists (select from unnest(p_matched) id group by id having id is null or count(*) > 1)
  then return 'invalid'; end if;
  if current_setting('transaction_isolation') not in ('read committed', 'read uncommitted') then return 'stale'; end if;
  perform pg_advisory_xact_lock(hashtextextended(tenant::text || '/bank-statement/' || p_operation::text, 0));
  fingerprint := md5(jsonb_build_array(p_bank, p_from, p_to, p_review,
    array(select id from unnest(p_matched) id order by id))::text);
  select a.changes ->> 'fingerprint' into previous from app.audit_log a
  where a.institute_id = tenant and a.entity_id = p_operation::text and a.action = 'bank_statement.closed';
  if found then return case when previous = fingerprint then 'closed' else 'invalid' end; end if;

  -- Manual recording takes this bank lock. The row locks serialize with
  -- donation reversals and let the next statement see the final set of gifts.
  perform from app.institute_bank_accounts b where b.institute_id = tenant and b.id = p_bank for update;
  if not found then return 'invalid'; end if;
  perform from app.donations d where d.institute_id = tenant and d.bank_account_id = p_bank
    and d.credited_on between p_from and p_to and d.method = 'bank_transfer' and d.status = 'recorded'
    order by d.id for update;
  snapshot := identity.read_bank_statement(p_session, p_bank, p_from, p_to);
  if snapshot is null then return 'invalid'; end if;
  if snapshot ->> 'review' is distinct from p_review then return 'stale'; end if;

  select count(*) filter (where d.id = any (p_matched)), count(*) filter (where not (d.id = any (p_matched))),
    coalesce(sum(d.amount_paisa) filter (where d.id = any (p_matched)), 0)
  into matched_count, missing_count, matched_total
  from app.donations d where d.institute_id = tenant and d.bank_account_id = p_bank
    and d.credited_on between p_from and p_to and d.method = 'bank_transfer' and d.status = 'recorded';
  if matched_count <> cardinality(p_matched) then return 'invalid'; end if;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, changes, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role), 'bank_statement.closed',
    'institute_bank_accounts', p_operation::text,
    jsonb_build_object('bank_account_id', p_bank, 'statement_from', p_from, 'statement_to', p_to,
      'matched_count', matched_count, 'matched_paisa', matched_total::text, 'missing_count', missing_count,
      'fingerprint', fingerprint), nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor returning id into audit_id;

  update app.donations d set statement_audit_id = audit_id, statement_matched = d.id = any (p_matched)
  where d.institute_id = tenant and d.bank_account_id = p_bank and d.credited_on between p_from and p_to
    and d.method = 'bank_transfer' and d.status = 'recorded';
  return 'closed';
end
$function$;
--> statement-breakpoint
create function identity.note_non_donation_credit(
  p_session uuid, p_bank uuid, p_credited date, p_amount bigint, p_note text, p_operation uuid
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  note text := nullif(btrim(p_note), '');
  detail jsonb;
  previous app.audit_log%rowtype;
begin
  if not identity.is_finance_session(p_session) then return 'denied'; end if;
  if p_operation is null or p_credited is null or p_credited not between date '1900-01-01' and (now() at time zone 'Asia/Karachi')::date
    or p_amount is null or p_amount not between 1 and 99999999999999
    or note is null or length(note) > 500 or note ~ '[[:cntrl:]]'
    or not exists (select from app.institute_bank_accounts b where b.institute_id = tenant and b.id = p_bank)
  then return 'invalid'; end if;
  perform pg_advisory_xact_lock(hashtextextended(tenant::text || '/bank-statement/' || p_operation::text, 0));
  detail := jsonb_build_object('bank_account_id', p_bank, 'credited_on', p_credited, 'amount_paisa', p_amount::text);
  select a.* into previous from app.audit_log a where a.institute_id = tenant
    and a.entity_id = p_operation::text and a.action = 'bank_statement.non_donation';
  if found then return case when previous.changes = detail and previous.reason = note then 'noted' else 'invalid' end; end if;
  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles, action, entity_table, entity_id, changes, reason, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role), 'bank_statement.non_donation',
    'institute_bank_accounts', p_operation::text, detail, note, nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  return 'noted';
end
$function$;
--> statement-breakpoint
revoke all on function identity.read_statement_accounts(uuid), identity.read_bank_statement(uuid, uuid, date, date),
  identity.close_bank_statement(uuid, uuid, date, date, text, uuid[], uuid),
  identity.note_non_donation_credit(uuid, uuid, date, bigint, text, uuid) from public;
grant execute on function identity.read_statement_accounts(uuid), identity.read_bank_statement(uuid, uuid, date, date),
  identity.close_bank_statement(uuid, uuid, date, date, text, uuid[], uuid),
  identity.note_non_donation_credit(uuid, uuid, date, bigint, text, uuid) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
