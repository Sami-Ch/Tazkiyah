SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Staff matching of one sponsor to one orphan (06 §12.1, P4-E1-T01).
-- The child is named by persona. The admin also sees the real name, because
-- only an admin can open this screen.
create function identity.sponsorship_workspace(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
begin
  if not identity.staff_session_ok(p_session_id) or not app.has_role('admin') then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'matches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id,
        'persona', p.display_name,
        'real_name', u.full_name,
        'status', s.status,
        'started_on', to_char(s.started_on, 'YYYY-MM-DD'),
        'sponsor', sponsor.full_name
      ) order by s.started_on desc, s.id)
      from app.sponsorships s
      join app.personas p on p.institute_id = s.institute_id and p.id = s.child_persona_id
      join app.persona_links l on l.institute_id = s.institute_id and l.persona_id = p.id
      join app.users u on u.institute_id = l.institute_id and u.id = l.user_id
      join app.donors d on d.institute_id = s.institute_id and d.id = s.sponsor_donor_id
      left join app.users sponsor on sponsor.institute_id = d.institute_id and sponsor.id = d.user_id
      where s.institute_id = tenant and s.status <> 'ended'
    ), '[]'::jsonb),
    'orphans', coalesce((
      select jsonb_agg(jsonb_build_object(
        'persona_id', p.id,
        'persona', p.display_name,
        'real_name', u.full_name
      ) order by p.display_name)
      from app.personas p
      join app.persona_links l on l.institute_id = p.institute_id and l.persona_id = p.id
      join app.users u on u.institute_id = l.institute_id and u.id = l.user_id and u.is_orphan
      where p.institute_id = tenant
        and not exists (
          select from app.sponsorships s
          where s.institute_id = tenant and s.child_persona_id = p.id and s.status <> 'ended'
        )
    ), '[]'::jsonb),
    'sponsors', coalesce((
      select jsonb_agg(jsonb_build_object('id', d.id, 'name', u.full_name) order by u.full_name)
      from app.donors d
      join app.users u on u.institute_id = d.institute_id and u.id = d.user_id
      where d.institute_id = tenant and d.erased_at is null and u.status = 'active'
    ), '[]'::jsonb),
    'causes', coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title) order by c.display_order, c.slug)
      from app.causes c
      where c.institute_id = tenant and c.status = 'active'
    ), '[]'::jsonb)
  );
end
$function$;
--> statement-breakpoint
create function identity.match_sponsorship(
  p_session_id uuid, p_donor_id uuid, p_persona_id uuid, p_cause_id uuid
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
begin
  if not identity.staff_session_ok(p_session_id) or not app.has_role('admin') then
    return 'denied';
  end if;
  if p_donor_id is null or p_persona_id is null or p_cause_id is null then
    return 'invalid';
  end if;
  begin
    insert into app.sponsorships (institute_id, sponsor_donor_id, child_persona_id, cause_id, matched_by)
    values (tenant, p_donor_id, p_persona_id, p_cause_id, actor);
    return 'matched';
  exception
    when unique_violation then return 'already_matched';
    when check_violation or foreign_key_violation then return 'unavailable';
  end;
end
$function$;
--> statement-breakpoint
create function identity.end_sponsorship(p_session_id uuid, p_sponsorship_id uuid)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
begin
  if not identity.staff_session_ok(p_session_id) or not app.has_role('admin') then
    return 'denied';
  end if;
  update app.sponsorships set status = 'ended'
  where institute_id = tenant and id = p_sponsorship_id and status <> 'ended';
  if not found then
    return 'not_found';
  end if;
  return 'ended';
end
$function$;
--> statement-breakpoint
revoke all on function identity.sponsorship_workspace(uuid),
  identity.match_sponsorship(uuid, uuid, uuid, uuid),
  identity.end_sponsorship(uuid, uuid) from public;
--> statement-breakpoint
grant execute on function identity.sponsorship_workspace(uuid),
  identity.match_sponsorship(uuid, uuid, uuid, uuid),
  identity.end_sponsorship(uuid, uuid) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
