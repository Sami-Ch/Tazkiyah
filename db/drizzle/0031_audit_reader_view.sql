SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
DROP INDEX "app"."audit_log_actor";--> statement-breakpoint
CREATE INDEX "audit_log_entity" ON "app"."audit_log" USING btree ("institute_id","entity_table","entity_id");--> statement-breakpoint
CREATE INDEX "audit_log_actor" ON "app"."audit_log" USING btree ("institute_id","actor_user_id","occurred_at" DESC NULLS LAST);
--> statement-breakpoint
-- Reversal categories (06 §15.2) are safe values the admin may read, stored in
-- the usual {"old","new"} shape.
create or replace function identity.audit_value(field text, value jsonb) returns jsonb
language sql immutable
set search_path = pg_catalog, pg_temp
return case
  when value is null or value = 'null'::jsonb then 'null'::jsonb
  when field = 'status' and value #>> '{}' in
    ('active', 'invited', 'left', 'suspended', 'draft', 'published', 'archived', 'pending', 'ready', 'rejected', 'deleted', 'closed')
    then value
  when field = 'role' and value #>> '{}' in
    ('admin', 'teacher', 'editor', 'finance_officer', 'student', 'donor') then value
  when field = 'preferred_language' and value #>> '{}' in ('en', 'ur') then value
  when field = 'visibility' and value #>> '{}' in ('public', 'private') then value
  when field in ('can_widen_scope', 'is_active', 'community_enabled', 'must_change_password')
    and jsonb_typeof(value) = 'boolean' then value
  when field = 'category' and value #>> '{}' in ('recorded_twice', 'wrong_details', 'wrong_type',
    'wrong_donor', 'transfer_returned', 'refund_to_donor', 'moved_to_another_cause', 'other') then value
  else null
end;
--> statement-breakpoint
create or replace function app.reverse_donation(p_donation_id uuid, p_category text, p_note text default null)
returns void
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  today date := (now() at time zone 'Asia/Karachi')::date;
  note text := nullif(btrim(p_note), '');
  gift app.donations%rowtype;
  placed record;
  reversal_id uuid;
begin
  if tenant is null or actor is null
    or not (app.has_role('admin') or app.has_role('finance_officer'))
  then
    raise exception 'reversing a donation needs an admin or finance officer'
      using errcode = 'insufficient_privilege';
  end if;
  if p_category is null or p_category not in ('recorded_twice', 'wrong_details', 'wrong_type',
      'wrong_donor', 'transfer_returned', 'refund_to_donor', 'moved_to_another_cause', 'other')
    or (note is not null and (length(note) > 500 or note ~ '[[:cntrl:]]'))
    or (p_category = 'other' and note is null)
  then
    raise exception 'a reversal needs a known reason category, and a note for "other"'
      using errcode = 'invalid_parameter_value';
  end if;

  select d.* into gift from app.donations d
  where d.institute_id = tenant and d.id = p_donation_id
  for update;
  if not found then
    raise exception 'donation not found' using errcode = 'no_data_found';
  end if;
  if gift.status <> 'recorded' then
    raise exception 'donation % is already reversed', gift.receipt_number
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if exists (
    select from app.allocations a
    where a.institute_id = tenant and a.donation_id = gift.id and a.kind = 'to_spending'
      and not a.is_reversal
      and not exists (select from app.allocations r
        where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id)
  ) then
    raise exception 'donation % has been spent; reverse its spending first', gift.receipt_number
      using errcode = 'object_not_in_prerequisite_state';
  end if;

  for placed in
    select a.*, e.id as event_id
    from app.allocations a
    join app.trail_events e on e.institute_id = a.institute_id and e.allocation_id = a.id
      and e.event_type = 'allocated'
    where a.institute_id = tenant and a.donation_id = gift.id
      and a.kind in ('to_cause', 'to_institute') and not a.is_reversal
      and not exists (select from app.allocations r
        where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id)
    order by a.created_at, a.id
  loop
    insert into app.allocations as a (institute_id, kind, donation_id, donation_type, cause_id,
      target_institute_id, amount_paisa, is_reversal, reverses_allocation_id, reason, created_by)
    values (tenant, placed.kind, gift.id, placed.donation_type, placed.cause_id,
      placed.target_institute_id, placed.amount_paisa, true, placed.id, p_category, actor)
    returning a.id into reversal_id;
    insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
      cause_id, allocation_id, reverses_event_id, reason, recorded_by)
    values (tenant, gift.id, 'reversal', today, placed.amount_paisa, placed.cause_id, reversal_id,
      placed.event_id, p_category, actor);
  end loop;

  insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
    reverses_event_id, reason, recorded_by)
  select tenant, gift.id, 'reversal', today, e.amount_paisa, e.id, p_category, actor
  from app.trail_events e
  where e.institute_id = tenant and e.donation_id = gift.id and e.event_type = 'received';

  update app.donations set status = 'reversed' where institute_id = tenant and id = gift.id;

  insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
    action, entity_table, entity_id, changes, reason, request_id)
  select tenant, actor, 'user', array_agg(r.role order by r.role),
    'donations.reversed', 'donations', gift.id::text, jsonb_build_object('category', jsonb_build_object('old', null, 'new', p_category)), note,
    nullif(current_setting('app.request_id', true), '')
  from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
end
$function$;
--> statement-breakpoint
-- The admin's audit reading (04 §12, 05 §9, P1-E5-T40): actor names resolved
-- and redaction kept. A name is shown only for an actor who acted under a
-- staff role, so no donor name or student real name can appear (05 §9.2).
-- Field values pass only through identity.audit_value; every other changed
-- field is counted as hidden. Not granted to the runtime roles: the reader
-- below checks a fresh two-factor admin session first. The reader returns
-- only whether a reason exists: it is free text and could hold a name.
create view app.audit_entries with (security_barrier = true) as
select a.id, a.institute_id, a.occurred_at, a.actor_user_id, a.actor_kind, a.actor_roles,
  case when a.actor_kind = 'user' and a.actor_roles && array['admin', 'teacher', 'editor', 'finance_officer']
    then u.full_name end as actor_name,
  a.action, a.entity_table,
  case when a.entity_id ~ '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}(/[a-z_]+)?$'
     or a.entity_id in ('home', 'about', 'facilities', 'daily-life')
    then a.entity_id end as entity_ref,
  details.visible as changes, details.hidden as hidden_fields, a.reason
from app.audit_log a
left join app.users u on (u.institute_id, u.id) = (a.institute_id, a.actor_user_id)
  cross join lateral (
    select coalesce(jsonb_object_agg(field, jsonb_build_object('old', old_value, 'new', new_value))
      filter (where old_value is not null and new_value is not null), '{}') as visible,
      count(*) filter (where old_value is null or new_value is null)::integer as hidden
    from (
      select field,
        case when jsonb_typeof(value) = 'object' and value ?& array['old', 'new']
          then identity.audit_value(field, value -> 'old') end as old_value,
        case when jsonb_typeof(value) = 'object' and value ?& array['old', 'new']
          then identity.audit_value(field, value -> 'new') end as new_value
      from jsonb_each(a.changes) as change(field, value)
      where field in ('status', 'role', 'preferred_language', 'visibility',
        'can_widen_scope', 'is_active', 'community_enabled', 'must_change_password', 'category')
      union all
      select field, null, null from jsonb_object_keys(a.changes) as other(field)
      where field not in ('status', 'role', 'preferred_language', 'visibility',
        'can_widen_scope', 'is_active', 'community_enabled', 'must_change_password', 'category')
    ) filtered
  ) details
where a.institute_id = app.current_institute_id() and app.has_role('admin');
--> statement-breakpoint
revoke all on app.audit_entries from public, tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
drop function identity.read_audit_log(uuid, integer, text, text, integer);
--> statement-breakpoint
create function identity.read_audit_log(
  session_id uuid, recent_days integer, event_action text, event_entity text, page_offset integer,
  event_actor uuid default null, event_entity_id text default null
) returns table (
  id text, occurred_at timestamptz, actor_id uuid, actor_name text, actor_kind text,
  roles text[], action text, entity text, entity_ref text, changes jsonb, hidden_fields integer,
  has_reason boolean
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select e.id::text, e.occurred_at, e.actor_user_id, e.actor_name, e.actor_kind, e.actor_roles,
    e.action, e.entity_table, e.entity_ref, e.changes, e.hidden_fields, e.reason is not null
  from app.audit_entries e
  where identity.is_staff_admin_session(session_id)
    and (recent_days is null or e.occurred_at >= now() - make_interval(days => recent_days))
    and (event_action is null or e.action = event_action)
    and (event_entity is null or e.entity_table = event_entity)
    and (event_actor is null or e.actor_user_id = event_actor)
    and (event_entity_id is null or e.entity_ref = event_entity_id)
  order by e.occurred_at desc, e.id desc
  limit 51 offset greatest(0, least(page_offset, 10000))
$function$;
--> statement-breakpoint
revoke all on function identity.read_audit_log(uuid, integer, text, text, integer, uuid, text) from public;
--> statement-breakpoint
grant execute on function identity.read_audit_log(uuid, integer, text, text, integer, uuid, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
