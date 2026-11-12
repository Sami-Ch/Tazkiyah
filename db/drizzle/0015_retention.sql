SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Retention rules from 04 §13.4, one row per table. The periods there are
-- proposed (REQ-SEC-011, Q-08), so the list stays empty until they are approved
-- and each table exists. A rule deletes the institute's rows matching its condition.
create function app.retention_rules()
returns table (table_name text, condition text)
language sql immutable
set search_path = pg_catalog, pg_temp
as $function$
  select r.table_name, r.condition
  from (values (null::text, null::text)) as r (table_name, condition)
  where false
$function$;
--> statement-breakpoint
-- Nightly per-institute run by the jobs Worker (03 §9). Writes one audit row with counts.
create function app.run_retention() returns jsonb
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  rule record;
  removed bigint;
  counts jsonb := '{}';
begin
  if tenant is null or current_setting('app.actor_kind', true) is distinct from 'job' then
    raise exception 'Retention runs only as a job inside an institute' using errcode = '42501';
  end if;

  for rule in select * from app.retention_rules() order by table_name loop
    -- Financial records and the audit log are never deleted by retention (REQ-TRL-002).
    if rule.table_name in ('donations', 'allocations', 'trail_events', 'spending_entries',
      'spending_reports', 'receipt_counters', 'audit_log')
      or to_regclass(format('app.%I', rule.table_name)) is null
    then
      raise exception 'Retention rule for % is not allowed', rule.table_name;
    end if;
    execute format('with gone as (delete from app.%I where institute_id = $1 and (%s) returning 1)
      select count(*) from gone', rule.table_name, rule.condition)
      into removed using tenant;
    counts := counts || jsonb_build_object(rule.table_name, removed);
  end loop;

  insert into app.audit_log (institute_id, actor_kind, action, entity_table, entity_id, changes, request_id)
  values (tenant, 'job', 'retention.run', 'institutes', tenant::text,
    jsonb_build_object('deleted_rows', jsonb_build_object('new', counts)),
    nullif(current_setting('app.request_id', true), ''));
  return counts;
end
$function$;
--> statement-breakpoint
revoke all on function app.retention_rules(), app.run_retention() from public;
--> statement-breakpoint
grant execute on function app.run_retention() to tazkiyah_app;
--> statement-breakpoint
RESET ROLE;
