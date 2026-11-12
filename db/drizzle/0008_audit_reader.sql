SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
create function identity.audit_value(field text, value jsonb) returns jsonb
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
  else null
end;
--> statement-breakpoint
create function identity.read_audit_log(
  session_id uuid, recent_days integer, event_action text, event_entity text, page_offset integer
) returns table (
  id text, occurred_at timestamptz, actor_id uuid, actor_kind text,
  roles text[], action text, entity text, entity_ref text, changes jsonb, hidden_fields integer
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select event.id::text, event.occurred_at, event.actor_user_id, event.actor_kind,
    event.actor_roles, event.action, event.entity_table,
    case when event.entity_id ~ '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}(/[a-z_]+)?$'
       or event.entity_id in ('home', 'about', 'facilities', 'daily-life')
      then event.entity_id end,
    details.visible, details.hidden
  from (
    select a.* from app.audit_log a
    where identity.is_staff_admin_session(session_id)
      and a.institute_id = app.current_institute_id()
      and (recent_days is null or a.occurred_at >= now() - make_interval(days => recent_days))
      and (event_action is null or a.action = event_action)
      and (event_entity is null or a.entity_table = event_entity)
    order by a.occurred_at desc, a.id desc
    limit 51 offset greatest(0, least(page_offset, 10000))
  ) event
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
      from jsonb_each(event.changes) as change(field, value)
      where field in ('status', 'role', 'preferred_language', 'visibility',
        'can_widen_scope', 'is_active', 'community_enabled', 'must_change_password')
      union all
      select field, null, null from jsonb_object_keys(event.changes) as other(field)
      where field not in ('status', 'role', 'preferred_language', 'visibility',
        'can_widen_scope', 'is_active', 'community_enabled', 'must_change_password')
    ) filtered
  ) details
  order by event.occurred_at desc, event.id desc
$function$;
--> statement-breakpoint
revoke all on function identity.audit_value(text, jsonb) from public;
revoke all on function identity.read_audit_log(uuid, integer, text, text, integer) from public;
grant execute on function identity.read_audit_log(uuid, integer, text, text, integer) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
