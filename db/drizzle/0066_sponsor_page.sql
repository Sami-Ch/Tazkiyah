SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The signed-in sponsor's children (REQ-ORP-002, REQ-ORP-003). Photos are
-- left out: a public address for a child's picture is not safe, and private
-- short-lived links are not available yet. The full name and class names
-- come only from app.sponsor_child_view, which hides them the moment consent
-- is withdrawn.
create function identity.read_sponsor_children(p_session uuid) returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
begin
  if not identity.is_donor_session(p_session) then
    return jsonb_build_object('code', 'denied');
  end if;
  return jsonb_build_object('code', 'ok', 'children', coalesce((
    select jsonb_agg(jsonb_build_object(
      'sponsorship_id', v.sponsorship_id,
      'persona_name', v.persona_name,
      'age_years', v.age_years,
      'updates', v.updates,
      'full_profile', v.full_profile,
      'full_name', case when v.full_profile then v.full_name end,
      'class_names', case when v.full_profile then v.class_names else '[]'::jsonb end
    ) order by v.sponsorship_id)
    from app.sponsor_child_view() v
  ), '[]'::jsonb));
end
$function$;
--> statement-breakpoint
-- Messages between the sponsor and the madrasa (REQ-ORP-007). The child is
-- never a sender, a recipient or a field in the result.
create function identity.read_sponsor_messages(p_session uuid, p_sponsorship uuid) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
begin
  if not identity.is_donor_session(p_session) or p_sponsorship is null
    or not exists (select from app.sponsorships s
      where s.institute_id = tenant and s.id = p_sponsorship
        and s.sponsor_donor_id = app.my_account_donor_id())
  then
    return jsonb_build_object('code', 'denied');
  end if;
  update app.sponsor_messages set read_at = clock_timestamp()
  where institute_id = tenant and sponsorship_id = p_sponsorship
    and direction = 'to_sponsor' and read_at is null;
  return jsonb_build_object('code', 'ok', 'messages', coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', m.id, 'direction', m.direction, 'body', m.body,
      'language', m.language, 'created_at', m.created_at
    ) order by m.created_at, m.id)
    from app.sponsor_messages m
    where m.institute_id = tenant and m.sponsorship_id = p_sponsorship
  ), '[]'::jsonb));
end
$function$;
--> statement-breakpoint
create function identity.send_sponsor_message(
  p_session uuid, p_sponsorship uuid, p_body text, p_language text
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  message text := btrim(p_body);
begin
  if not identity.is_donor_session(p_session) then return 'denied'; end if;
  if p_sponsorship is null or p_language not in ('ur', 'en')
    or message is null or length(message) not between 1 and 2000
  then
    return 'invalid';
  end if;
  if app.has_contact_details(message) then return 'contact_details'; end if;
  insert into app.sponsor_messages (
    institute_id, sponsorship_id, direction, body, language, sender_donor_id
  ) values (
    tenant, p_sponsorship, 'to_madrasa', message, p_language, app.my_account_donor_id()
  );
  return 'sent';
exception when check_violation then
  return 'unavailable';
end
$function$;
--> statement-breakpoint
revoke all on function identity.read_sponsor_children(uuid),
  identity.read_sponsor_messages(uuid, uuid),
  identity.send_sponsor_message(uuid, uuid, text, text) from public;
--> statement-breakpoint
grant execute on function identity.read_sponsor_children(uuid),
  identity.read_sponsor_messages(uuid, uuid),
  identity.send_sponsor_message(uuid, uuid, text, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
