SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Named gifts are allowed once a donor or the recorder chooses them
-- (REQ-DPR-006). The old check kept every row anonymous until that switch
-- existed. New transfers still start anonymous unless the form says otherwise.
alter table app.donations drop constraint donations_anonymity_check;
--> statement-breakpoint
-- A public handle for a donor profile (REQ-DPR-005). It is not a name, so two
-- donors can share a display name and a renamed profile keeps its address.
alter table app.donors add column public_ref text;
--> statement-breakpoint
update app.donors set public_ref = app.new_public_ref() where public_ref is null;
--> statement-breakpoint
alter table app.donors alter column public_ref set default app.new_public_ref();
--> statement-breakpoint
alter table app.donors alter column public_ref set not null;
--> statement-breakpoint
alter table app.donors add constraint donors_public_ref_check check (public_ref ~ '^[a-z2-7]{10}$');
--> statement-breakpoint
create unique index donors_public_ref on app.donors (institute_id, public_ref);
--> statement-breakpoint
-- Recording may now store a named gift. Retries must repeat that choice.
create or replace function identity.record_manual_donation_core(
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
  receipt text;
  prior app.donations%rowtype;
  guest_id uuid;
  recorded_id uuid;
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
    or p_anonymous is null
    or (guest_email is not null and (length(guest_email) > 254
      or guest_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'))
  then
    return query select 'invalid'::text, null::uuid, null::text;
    return;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(tenant::text || '/' || p_operation_id::text, 294751));
  select d.* into prior from app.donations d
  where d.institute_id = tenant and d.operation_id = p_operation_id;
  if found then
    if prior.bank_account_id = p_bank_account_id and prior.bank_reference = reference
      and prior.credited_on = p_credited_on and prior.amount_paisa = p_amount_paisa
      and prior.donation_type = p_donation_type and prior.cause_id is not distinct from p_cause_id
      and prior.receipt_locale = p_receipt_locale and prior.is_anonymous = p_anonymous
      and guest_email is not distinct from (
        select guest.email from app.donors guest where guest.institute_id = tenant and guest.id = prior.donor_id
      )
    then return query select 'existing'::text, prior.id, prior.receipt_number;
    else return query select 'operation_conflict'::text, null::uuid, null::text;
    end if;
    return;
  end if;

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

  if not exists (select from app.institute_settings s where s.institute_id = tenant) then
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
  else
    insert into app.donors as guest (institute_id, email, preferred_language)
    values (tenant, null, p_receipt_locale)
    returning guest.id into guest_id;
  end if;

  select r.donation_id, r.receipt_number into recorded_id, receipt
  from app.record_donation(p_operation_id, guest_id, p_cause_id, p_donation_type, p_amount_paisa,
    p_credited_on, p_bank_account_id, reference, p_receipt_locale, p_anonymous) r;

  return query select 'recorded'::text, recorded_id, receipt;
end
$function$;
--> statement-breakpoint
-- A wall name is set only when this gift is named and the donor has none yet.
-- An existing public name is left as the donor wrote it.
create function identity.attach_wall_name(p_session_id uuid, p_donation_id uuid, p_display_name text)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  gift app.donations%rowtype;
  label text := btrim(p_display_name);
begin
  if not identity.is_finance_session(p_session_id) then return 'denied'; end if;
  if label is null or length(label) not between 1 and 80 or label ~ '[[:cntrl:]]' then
    return 'invalid';
  end if;
  select d.* into gift from app.donations d
  where d.institute_id = tenant and d.id = p_donation_id and d.recorded_by = actor;
  if not found then return 'not_found'; end if;
  if gift.is_anonymous then return 'anonymous'; end if;
  update app.donors set display_name = label
  where institute_id = tenant and id = gift.donor_id and display_name is null and erased_at is null;
  return 'named';
end
$function$;
--> statement-breakpoint
create function identity.all_needs_request(p_pool text, p_parts jsonb)
returns text
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  part jsonb;
  target uuid;
  wanted bigint;
  total bigint := 0;
  available bigint;
begin
  if p_pool is null or p_pool not in ('zakat', 'general')
    or jsonb_typeof(p_parts) is distinct from 'array'
  then
    return 'invalid';
  end if;
  if jsonb_array_length(p_parts) not between 1 and 12 then
    return 'invalid';
  end if;
  for part in select value from jsonb_array_elements(p_parts) loop
    begin
      target := (part ->> 'cause_id')::uuid;
      wanted := (part ->> 'amount_paisa')::bigint;
    exception when invalid_text_representation or numeric_value_out_of_range then
      return 'invalid';
    end;
    if target is null or wanted is null or wanted < 100 or wanted % 100 <> 0 then
      return 'invalid';
    end if;
    if not exists (select from app.causes c
      where c.institute_id = tenant and c.id = target and c.status in ('active', 'closed')
        and (p_pool <> 'zakat' or c.accepts_zakat))
    then
      return 'cause';
    end if;
    total := total + wanted;
  end loop;
  select coalesce(sum(u.unallocated_paisa), 0) into available
  from app.unallocated_all_needs u where u.pool = p_pool;
  if total > available then return 'over'; end if;
  return 'ok';
end
$function$;
--> statement-breakpoint
-- Admin split screen (REQ-ROL-006, D-012). Finance officers do not split.
create function identity.all_needs_workspace(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
begin
  if not identity.is_staff_admin_session(p_session_id) then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'pools', coalesce((
      select jsonb_agg(jsonb_build_object(
        'pool', p.pool, 'unallocated_paisa', p.total::text, 'gifts', p.gifts
      ) order by p.pool)
      from (
        select u.pool, sum(u.unallocated_paisa) as total, count(*)::int as gifts
        from app.unallocated_all_needs u group by u.pool
      ) p
    ), '[]'::jsonb),
    'gifts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'pool', g.pool, 'donation_id', g.donation_id, 'receipt_number', g.receipt_number,
        'credited_on', to_char(g.credited_on, 'YYYY-MM-DD'),
        'unallocated_paisa', g.unallocated_paisa::text
      ) order by g.pool, g.credited_on, g.receipt_number)
      from (
        select u.* from app.unallocated_all_needs u
        order by u.pool, u.credited_on, u.receipt_number
        limit 40
      ) g
    ), '[]'::jsonb),
    'causes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'title', c.title, 'accepts_zakat', c.accepts_zakat, 'status', c.status
      ) order by c.display_order, c.slug)
      from app.causes c
      where c.institute_id = tenant and c.status in ('active', 'closed')
    ), '[]'::jsonb)
  );
end
$function$;
--> statement-breakpoint
-- Same order as app.split_all_needs: oldest credit date, then receipt number.
-- Nothing is written. The save calls the ledger function, which locks the pool.
create function identity.preview_all_needs_split(p_session_id uuid, p_pool text, p_parts jsonb)
returns jsonb
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  answer text;
  part jsonb;
  target uuid;
  wanted bigint;
  money record;
  take bigint;
  left_over jsonb := '{}'::jsonb;
  draws jsonb := '[]'::jsonb;
begin
  if not identity.is_staff_admin_session(p_session_id) then
    return jsonb_build_object('code', 'denied');
  end if;
  answer := identity.all_needs_request(p_pool, p_parts);
  if answer <> 'ok' then return jsonb_build_object('code', answer); end if;

  select coalesce(jsonb_object_agg(u.donation_id, u.unallocated_paisa), '{}'::jsonb)
  into left_over from app.unallocated_all_needs u where u.pool = p_pool;

  for part in select value from jsonb_array_elements(p_parts) loop
    target := (part ->> 'cause_id')::uuid;
    wanted := (part ->> 'amount_paisa')::bigint;
    for money in
      select u.donation_id, u.receipt_number, u.unallocated_paisa
      from app.unallocated_all_needs u
      where u.pool = p_pool
      order by u.credited_on, u.receipt_number
    loop
      exit when wanted = 0;
      take := least(coalesce((left_over ->> money.donation_id::text)::bigint, 0), wanted);
      continue when take <= 0;
      draws := draws || jsonb_build_array(jsonb_build_object(
        'cause_id', target, 'donation_id', money.donation_id,
        'receipt_number', money.receipt_number, 'amount_paisa', take::text
      ));
      left_over := jsonb_set(left_over, array[money.donation_id::text], to_jsonb(
        (left_over ->> money.donation_id::text)::bigint - take));
      wanted := wanted - take;
    end loop;
  end loop;
  return jsonb_build_object('code', 'preview', 'draws', draws);
end
$function$;
--> statement-breakpoint
create function identity.apply_all_needs_split(p_session_id uuid, p_pool text, p_parts jsonb)
returns jsonb
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  answer text;
  placed jsonb;
begin
  if not identity.is_staff_admin_session(p_session_id) then
    return jsonb_build_object('code', 'denied');
  end if;
  answer := identity.all_needs_request(p_pool, p_parts);
  if answer <> 'ok' then return jsonb_build_object('code', answer); end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'donation_id', s.donation_id, 'cause_id', s.cause_id, 'amount_paisa', s.amount_paisa::text
  )), '[]'::jsonb) into placed
  from app.split_all_needs(p_pool, p_parts) s;
  return jsonb_build_object('code', 'split', 'placed', placed);
end
$function$;
--> statement-breakpoint
-- Spending reports (REQ-TRL-012). Publishing still goes through
-- app.publish_spending_report, which writes one reported event per donation.
create function identity.spending_reports_workspace(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
begin
  if not identity.is_finance_session(p_session_id) then
    return jsonb_build_object('allowed', false);
  end if;
  return jsonb_build_object(
    'allowed', true,
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'cause_id', e.cause_id, 'amount_paisa', e.amount_paisa::text,
        'spent_on', to_char(e.spent_on, 'YYYY-MM-DD'), 'description', e.description,
        'report_id', e.report_id
      ) order by e.spent_on, e.created_at)
      from app.spending_entries e
      left join app.spending_reports r on r.institute_id = e.institute_id and r.id = e.report_id
      where e.institute_id = tenant and e.status = 'recorded'
        and (e.report_id is null or r.status = 'draft')
    ), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'period_kind', r.period_kind,
        'period_start', to_char(r.period_start, 'YYYY-MM-DD'),
        'period_end', to_char(r.period_end, 'YYYY-MM-DD'),
        'title', r.title, 'notes', r.notes, 'status', r.status
      ) order by r.period_start desc, r.created_at desc)
      from app.spending_reports r
      where r.institute_id = tenant
        and (r.status = 'draft' or r.published_at > now() - interval '180 days')
    ), '[]'::jsonb),
    'causes', coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title) order by c.display_order, c.slug)
      from app.causes c where c.institute_id = tenant
    ), '[]'::jsonb)
  );
end
$function$;
--> statement-breakpoint
create function identity.save_spending_report(
  p_session_id uuid, p_period_kind text, p_period_start date, p_period_end date,
  p_title jsonb, p_notes jsonb, p_entry_ids uuid[]
) returns table (code text, report_id uuid)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  saved uuid;
  attached integer;
begin
  if not identity.is_finance_session(p_session_id) then
    return query select 'denied'::text, null::uuid;
    return;
  end if;
  if p_period_kind is null or p_period_kind not in ('daily', 'weekly', 'custom')
    or p_period_start is null or p_period_end is null or p_period_end < p_period_start
    or (p_period_kind = 'daily' and p_period_end <> p_period_start)
    or (p_period_kind = 'weekly' and p_period_end <> p_period_start + 6)
    or p_title is null or not app.valid_localized_text(p_title)
    or exists (
      select from jsonb_each(p_title) as item(language, body)
      where language not in ('en', 'ur') or length(body #>> '{}') > 120
        or (body #>> '{}') ~ '[[:cntrl:]]'
    )
    or (p_notes is not null and (
      not app.valid_localized_text(p_notes) or exists (
        select from jsonb_each(p_notes) as item(language, body)
        where language not in ('en', 'ur') or length(body #>> '{}') > 500
          or (body #>> '{}') ~ '[[:cntrl:]]'
      )
    ))
    or p_entry_ids is null or cardinality(p_entry_ids) not between 1 and 40
    or cardinality(p_entry_ids) <> (select count(distinct id) from unnest(p_entry_ids) as id)
  then
    return query select 'invalid'::text, null::uuid;
    return;
  end if;

  insert into app.spending_reports (
    institute_id, period_kind, period_start, period_end, title, notes, created_by
  ) values (
    tenant, p_period_kind, p_period_start, p_period_end, p_title, p_notes, actor
  ) returning id into saved;

  update app.spending_entries e set report_id = saved
  where e.institute_id = tenant and e.id = any (p_entry_ids)
    and e.status = 'recorded' and e.report_id is null;
  get diagnostics attached = row_count;
  if attached <> cardinality(p_entry_ids) then
    raise exception 'spending report entries are not free recorded lines'
      using errcode = 'check_violation';
  end if;
  return query select 'saved'::text, saved;
exception
  when check_violation then
    return query select 'entries'::text, null::uuid;
end
$function$;
--> statement-breakpoint
create function identity.publish_staff_report(p_session_id uuid, p_report_id uuid)
returns table (code text, events integer)
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  written integer;
begin
  if not identity.is_finance_session(p_session_id) then
    return query select 'denied'::text, null::integer;
    return;
  end if;
  if p_report_id is null then
    return query select 'invalid'::text, null::integer;
    return;
  end if;
  written := app.publish_spending_report(p_report_id);
  return query select 'published'::text, written;
exception
  when insufficient_privilege then
    return query select 'denied'::text, null::integer;
  when no_data_found then
    return query select 'not_found'::text, null::integer;
  when object_not_in_prerequisite_state then
    return query select 'not_ready'::text, null::integer;
end
$function$;
--> statement-breakpoint
-- Donor and guest-link holders choose both ways. Staff can only make a gift
-- anonymous or its trail private (05 §7). A donor's own switch is not audited.
create function identity.set_donation_visibility(
  p_session_id uuid, p_token_hash text, p_public_ref text, p_receipt text,
  p_anonymous boolean, p_trail_public boolean
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  owner uuid;
  staff boolean := false;
  gift app.donations%rowtype;
  receipt text := nullif(upper(btrim(p_receipt)), '');
begin
  if p_anonymous is null and p_trail_public is null then return 'invalid'; end if;
  -- A receipt is the staff path, so a finance officer who is also a donor
  -- does not edit someone else's gift through their own donor session.
  if receipt is not null then
    if not identity.is_finance_session(p_session_id) then return 'denied'; end if;
    staff := true;
  elsif p_token_hash ~ '^[0-9a-f]{64}$' then
    select link.donor_id into owner
    from app.trail_links link
    join app.donors donor on (donor.institute_id, donor.id) = (link.institute_id, link.donor_id)
    where link.institute_id = tenant and link.token_hash = p_token_hash and link.revoked_at is null
      and donor.user_id is null and donor.erased_at is null;
    if owner is null or p_public_ref is null then return 'denied'; end if;
  elsif identity.is_donor_session(p_session_id) then
    if p_public_ref is null then return 'invalid'; end if;
    select d.id into owner from app.donors d
    where d.institute_id = tenant and d.user_id = actor and d.erased_at is null;
    if owner is null then return 'denied'; end if;
  else
    return 'denied';
  end if;

  select d.* into gift from app.donations d
  where d.institute_id = tenant
    and (owner is null or d.donor_id = owner)
    and (p_public_ref is null or d.public_ref = p_public_ref)
    and (receipt is null or d.receipt_number = receipt);
  if not found then return 'not_found'; end if;

  if staff and (
    (p_anonymous is false and gift.is_anonymous)
    or (p_trail_public is true and not gift.trail_public)
  ) then
    return 'denied';
  end if;

  update app.donations set
    is_anonymous = coalesce(p_anonymous, is_anonymous),
    trail_public = coalesce(p_trail_public, trail_public)
  where institute_id = tenant and id = gift.id;

  if staff and (p_anonymous is true and not gift.is_anonymous or p_trail_public is false and gift.trail_public) then
    insert into app.audit_log (institute_id, actor_user_id, actor_kind, actor_roles,
      action, entity_table, entity_id, changes, request_id)
    select tenant, actor, 'user', array_agg(r.role order by r.role),
      'donations.visibility', 'donations', gift.id::text,
      jsonb_strip_nulls(jsonb_build_object(
        'is_anonymous', case when p_anonymous is true and not gift.is_anonymous
          then jsonb_build_object('old', false, 'new', true) end,
        'trail_public', case when p_trail_public is false and gift.trail_public
          then jsonb_build_object('old', true, 'new', false) end
      )),
      nullif(current_setting('app.request_id', true), '')
    from app.user_roles r where r.institute_id = tenant and r.user_id = actor;
  end if;
  return 'saved';
end
$function$;
--> statement-breakpoint
create function identity.donor_profile_workspace(p_session_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  donor app.donors%rowtype;
begin
  if not identity.is_donor_session(p_session_id) then
    return jsonb_build_object('allowed', false);
  end if;
  select d.* into donor from app.donors d
  where d.institute_id = tenant and d.user_id = actor and d.erased_at is null;
  if not found then return jsonb_build_object('allowed', false); end if;
  return jsonb_build_object(
    'allowed', true,
    'public_ref', donor.public_ref,
    'display_name', donor.display_name,
    'profile_public', donor.profile_public,
    'profile_links', donor.profile_links,
    'photo', 'unavailable'
  );
end
$function$;
--> statement-breakpoint
create function identity.save_donor_profile(
  p_session_id uuid, p_display_name text, p_profile_public boolean, p_links jsonb
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  actor uuid := app.current_user_id();
  label text := nullif(btrim(p_display_name), '');
begin
  if not identity.is_donor_session(p_session_id) then return 'denied'; end if;
  if p_profile_public is null or p_links is null or not app.valid_profile_links(p_links) then
    return 'invalid';
  end if;
  if label is not null and (length(label) > 80 or label ~ '[[:cntrl:]]') then return 'invalid'; end if;
  if p_profile_public and label is null then return 'name'; end if;
  update app.donors set display_name = label, profile_public = p_profile_public, profile_links = p_links
  where institute_id = tenant and user_id = actor and erased_at is null;
  if not found then return 'denied'; end if;
  return 'saved';
end
$function$;
--> statement-breakpoint
-- A guest has no public profile page. The name is only the wall label.
create function identity.save_guest_display_name(p_token_hash text, p_display_name text)
returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  owner uuid;
  label text := btrim(p_display_name);
begin
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then return 'denied'; end if;
  if label is null or length(label) not between 1 and 80 or label ~ '[[:cntrl:]]' then
    return 'invalid';
  end if;
  select link.donor_id into owner
  from app.trail_links link
  join app.donors donor on (donor.institute_id, donor.id) = (link.institute_id, link.donor_id)
  where link.institute_id = tenant and link.token_hash = p_token_hash and link.revoked_at is null
    and donor.user_id is null and donor.erased_at is null;
  if owner is null then return 'denied'; end if;
  update app.donors set display_name = label
  where institute_id = tenant and id = owner;
  return 'saved';
end
$function$;
--> statement-breakpoint
alter type identity.donation_trail_row
  add attribute is_anonymous boolean,
  add attribute trail_public boolean;
--> statement-breakpoint
create or replace function identity.donation_trail_page(
  p_donor uuid, p_before_recorded_at timestamptz, p_before_donation_id uuid, p_public_ref text
) returns setof identity.donation_trail_row
language sql stable
set search_path = pg_catalog, pg_temp
as $function$
  with page as materialized (
    select d.institute_id, d.id, d.receipt_number, d.receipt_locale, d.credited_on,
      d.amount_paisa, d.donation_type, d.status, d.recorded_at, d.cause_id, d.public_ref,
      d.bank_reference, d.is_anonymous, d.trail_public, d.donor_id, d.replaces_donation_id
    from app.donations d
    where d.institute_id = app.current_institute_id() and d.donor_id = p_donor
      and (p_public_ref is null or d.public_ref = p_public_ref)
      and ((p_before_recorded_at is null and p_before_donation_id is null) or
        (isfinite(p_before_recorded_at) and p_before_donation_id is not null
          and (d.recorded_at, d.id) < (p_before_recorded_at, p_before_donation_id)))
    order by d.recorded_at desc nulls last, d.id desc nulls last
    limit 21
  )
  select d.id, d.receipt_number, d.receipt_locale, to_char(d.credited_on, 'YYYY-MM-DD'),
    d.amount_paisa::text, d.donation_type, d.status,
    to_char(d.recorded_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    coalesce(trail.events, '[]'::jsonb),
    (select r.reason from app.trail_events r
      join app.trail_events o on o.institute_id = r.institute_id and o.id = r.reverses_event_id
      where r.institute_id = d.institute_id and r.donation_id = d.id and o.event_type = 'received'),
    original_cause.title::jsonb, d.public_ref, right(d.bank_reference, 4),
    case when not d.is_anonymous then coalesce(donor.display_name, account.full_name) end,
    settings.name::jsonb, settings.address::jsonb, i.slug, logo.storage_key,
    d.replaces_donation_id is not null, replaced.receipt_number,
    d.is_anonymous, d.trail_public
  from page d
  join app.institutes i on i.id = d.institute_id
  left join app.institute_settings settings on settings.institute_id = i.id
  left join public_api.institute_logo logo on logo.institute_id = i.id
  join app.donors donor on (donor.institute_id, donor.id) = (d.institute_id, d.donor_id)
  left join app.users account on (account.institute_id, account.id) = (donor.institute_id, donor.user_id)
  left join app.donations replaced on (replaced.institute_id, replaced.id, replaced.donor_id)
    = (d.institute_id, d.replaces_donation_id, d.donor_id)
  left join app.causes original_cause on (original_cause.institute_id, original_cause.id) = (d.institute_id, d.cause_id)
  cross join lateral (
    select jsonb_agg(jsonb_build_object(
      'event_type', e.event_type,
      'occurred_on', to_char(e.occurred_on, 'YYYY-MM-DD'),
      'amount_paisa', e.amount_paisa::text,
      'cause_title', c.title
    ) || case
      when e.event_type in ('spent', 'reported') then jsonb_strip_nulls(jsonb_build_object(
        'description', case
          when e.event_type = 'spent' then se.description
          when e.event_type = 'reported' then sr.title
        end,
        'receipt_key', case
          when e.event_type = 'spent' and se.receipt_public
            and m.visibility = 'public' and m.status = 'ready' and not m.shows_face
          then m.storage_key
        end
      ))
      else '{}'::jsonb
    end order by e.id) as events
    from app.trail_events e
    left join app.causes c on (c.institute_id, c.id) = (e.institute_id, e.cause_id)
    left join app.spending_entries se on e.event_type = 'spent'
      and (se.institute_id, se.id) = (e.institute_id, e.spending_entry_id)
      and se.status = 'recorded'
    left join app.media_assets m on se.receipt_media_id is not null
      and (m.institute_id, m.id) = (se.institute_id, se.receipt_media_id)
    left join app.spending_reports sr on e.event_type = 'reported'
      and (sr.institute_id, sr.id) = (e.institute_id, e.spending_report_id)
      and sr.status = 'published'
    where e.institute_id = d.institute_id and e.donation_id = d.id
      and e.event_type in ('received', 'allocated', 'spent', 'reported')
      and (e.event_type <> 'spent' or se.id is not null)
      and (e.event_type <> 'reported' or sr.id is not null)
      and not exists (select from app.trail_events r
        where r.institute_id = e.institute_id and r.reverses_event_id = e.id)
  ) trail
  order by d.recorded_at desc, d.id desc
$function$;
--> statement-breakpoint
revoke all on function identity.attach_wall_name(uuid, uuid, text),
  identity.all_needs_request(text, jsonb),
  identity.all_needs_workspace(uuid),
  identity.preview_all_needs_split(uuid, text, jsonb),
  identity.apply_all_needs_split(uuid, text, jsonb),
  identity.spending_reports_workspace(uuid),
  identity.save_spending_report(uuid, text, date, date, jsonb, jsonb, uuid[]),
  identity.publish_staff_report(uuid, uuid),
  identity.set_donation_visibility(uuid, text, text, text, boolean, boolean),
  identity.donor_profile_workspace(uuid),
  identity.save_donor_profile(uuid, text, boolean, jsonb),
  identity.save_guest_display_name(text, text) from public;
--> statement-breakpoint
grant execute on function identity.attach_wall_name(uuid, uuid, text),
  identity.all_needs_workspace(uuid),
  identity.preview_all_needs_split(uuid, text, jsonb),
  identity.apply_all_needs_split(uuid, text, jsonb),
  identity.spending_reports_workspace(uuid),
  identity.save_spending_report(uuid, text, date, date, jsonb, jsonb, uuid[]),
  identity.publish_staff_report(uuid, uuid),
  identity.set_donation_visibility(uuid, text, text, text, boolean, boolean),
  identity.donor_profile_workspace(uuid),
  identity.save_donor_profile(uuid, text, boolean, jsonb),
  identity.save_guest_display_name(text, text) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
