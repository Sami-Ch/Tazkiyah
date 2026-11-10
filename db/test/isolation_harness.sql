-- Cross-institute behaviour tests generated from the catalog (04 §6.6).
-- Fixture institutes A and B get the same shape of data. Their text carries
-- ZZA- and ZZB- markers so a leak is visible in any column of any relation.
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

do $fixture$
declare
  tenant uuid;
  mark text;
  n int := 0;
begin
  foreach mark in array array['ZZA', 'ZZB'] loop
    n := n + 1;
    tenant := ('14000000-0000-4000-8000-00000000000' || n)::uuid;
    insert into app.institutes (id, slug) values (tenant, lower(mark) || '-harness');
    insert into app.institute_domains (institute_id, domain, is_primary)
    values (tenant, lower(mark) || '-harness.example', true);
    insert into app.users (id, institute_id, email, username, full_name, status, two_factor_enabled, must_change_password)
    values (('14000000-0000-4000-8000-00000000030' || n)::uuid, tenant, lower(mark) || '-admin@example.test',
      lower(mark) || '-admin', mark || '-Admin', 'active', true, false);
    insert into app.user_roles (institute_id, user_id, role, granted_by)
    values (tenant, ('14000000-0000-4000-8000-00000000030' || n)::uuid, 'admin',
      ('14000000-0000-4000-8000-00000000030' || n)::uuid);
    -- A class created by its teacher, who joins it as a member.
    insert into app.user_roles (institute_id, user_id, role, granted_by)
    values (tenant, ('14000000-0000-4000-8000-00000000030' || n)::uuid, 'teacher',
      ('14000000-0000-4000-8000-00000000030' || n)::uuid);
    insert into app.classes (institute_id, name, year_label, created_by)
    values (tenant, jsonb_build_object('en', mark || '-Class'), mark || '-Year',
      ('14000000-0000-4000-8000-00000000030' || n)::uuid);
    insert into app.media_assets
      (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, width, height, status, uploaded_by)
    values (('14000000-0000-4000-8000-00000000010' || n)::uuid, tenant, 'image', 'logo', 'public',
      tenant || '/' || mark || '-logo.webp', 'image/webp', 1000, 96, 96, 'ready',
      ('14000000-0000-4000-8000-00000000030' || n)::uuid);
    update app.users set photo_media_id = ('14000000-0000-4000-8000-00000000010' || n)::uuid
    where id = ('14000000-0000-4000-8000-00000000030' || n)::uuid;
    insert into app.media_assets
      (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, width, height, status, uploaded_by)
    values (('14000000-0000-4000-8000-00000000025' || n)::uuid, tenant, 'image', 'donor_photo', 'public',
      tenant || '/' || mark || '-donor.webp', 'image/webp', 1000, 96, 96, 'ready',
      ('14000000-0000-4000-8000-00000000030' || n)::uuid);

    insert into app.institute_settings
      (institute_id, name, address, theme, receipt_prefix, logo_media_id, principal_user_id, updated_by)
    values (tenant, jsonb_build_object('en', mark || '-Institute'), jsonb_build_object('en', mark || '-Address'),
      '{}', mark, ('14000000-0000-4000-8000-00000000010' || n)::uuid,
      ('14000000-0000-4000-8000-00000000030' || n)::uuid, ('14000000-0000-4000-8000-00000000030' || n)::uuid);
    insert into app.institute_bank_accounts
      (id, institute_id, label, bank_name, account_title, account_number, show_on_donate)
    values (('14000000-0000-4000-8000-00000000020' || n)::uuid, tenant,
      jsonb_build_object('en', mark || '-Account'), mark || '-Bank', mark || '-Title', mark || '-0001', true);

    insert into identity.accounts (institute_id, user_id, provider_id, account_id, password)
    values (tenant, ('14000000-0000-4000-8000-00000000030' || n)::uuid, 'credential',
      ('14000000-0000-4000-8000-00000000030' || n), mark || '-password-hash');
    insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
    values (tenant, ('14000000-0000-4000-8000-00000000030' || n)::uuid, mark || '-secret', mark || '-codes', true);
    insert into identity.sessions (id, institute_id, user_id, token, expires_at, two_factor_verified_at)
    values (('14000000-0000-4000-8000-00000000040' || n)::uuid, tenant,
      ('14000000-0000-4000-8000-00000000030' || n)::uuid, mark || '-session', now() + interval '1 hour', now());
    insert into identity.verification (institute_id, identifier, value, expires_at)
    values (tenant, mark || '-identifier', mark || '-value', now() + interval '1 hour');
    insert into identity.rate_limit (institute_id, key, count, last_request)
    values (tenant, mark || '-key', 1, 0);
    insert into identity.staff_invitations (institute_id, user_id, token_hash, expires_at)
    values (tenant, ('14000000-0000-4000-8000-00000000030' || n)::uuid, repeat(case mark when 'ZZA' then 'c' else 'd' end, 64),
      now() + interval '1 day');

    insert into app.site_pages (institute_id, slug, title, body, status, published_at, cover_media_id)
    values (tenant, 'about', jsonb_build_object('en', mark || '-About'), jsonb_build_object('en', mark || '-Body'),
      'published', now(), ('14000000-0000-4000-8000-00000000010' || n)::uuid);
    insert into app.site_page_drafts (institute_id, slug, title, body)
    values (tenant, 'about', jsonb_build_object('en', mark || '-Draft'), jsonb_build_object('en', mark || '-Body'));
    insert into app.causes
      (id, institute_id, slug, cause_type, title, summary, status, target_period, cover_media_id)
    values (('14000000-0000-4000-8000-00000000050' || n)::uuid, tenant, lower(mark) || '-wheat', 'ongoing',
      jsonb_build_object('en', mark || '-Wheat'), jsonb_build_object('en', mark || '-Summary'), 'active', 'yearly',
      ('14000000-0000-4000-8000-00000000010' || n)::uuid);
  end loop;
end
$fixture$;

-- Donations, allocations, trail events, donors, receipts and trail links come
-- from the same definer functions the admin screens use.
reset role;
set local role tazkiyah_auth;
do $fixture$
declare
  n int;
  mark text;
  link int;
  result record;
begin
  for n in 1..2 loop
    mark := (array['ZZA', 'ZZB'])[n];
    perform set_config('app.institute_id', '14000000-0000-4000-8000-00000000000' || n, true);
    perform set_config('app.user_id', '14000000-0000-4000-8000-00000000030' || n, true);
    perform set_config('app.receipt_email_confirmed', 'true', true);
    select * into strict result from identity.record_manual_donation(
      ('14000000-0000-4000-8000-00000000040' || n)::uuid, gen_random_uuid(),
      ('14000000-0000-4000-8000-00000000020' || n)::uuid, mark || '-reference',
      (now() at time zone 'Asia/Karachi')::date, 250000, 'general',
      ('14000000-0000-4000-8000-00000000050' || n)::uuid, lower(mark) || '-donor@example.test', 'en',
      true, true, true
    );
    assert result.code = 'recorded', 'Fixture donation was not recorded: ' || result.code;
    for link in 0..1 loop
      assert identity.issue_trail_link(
        ('14000000-0000-4000-8000-00000000040' || n)::uuid, result.receipt_number,
        lower(mark) || '-donor@example.test',
        repeat(case mark when 'ZZA' then 'a' else 'b' end || link, 32), 'hnt' || link
      ) = 'issued', 'Fixture trail link was not issued';
    end loop;
  end loop;
end
$fixture$;
reset role;
set local role tazkiyah_schema_owner;
-- A spend from the cause allocation and its reversal, with their trail events,
-- so the source, reversed-allocation and reversed-event keys have rows.
do $fixture$
declare
  given record;
  spend_id uuid;
  spent_event bigint;
  reversal_id uuid;
  entry_id uuid;
  report_id uuid;
  n int := 0;
begin
  for given in
    select a.institute_id, a.id, a.donation_id, a.cause_id, a.created_by, a.donation_type
    from app.allocations a
    where a.institute_id in ('14000000-0000-4000-8000-000000000001', '14000000-0000-4000-8000-000000000002')
      and a.kind = 'to_cause'
    order by a.institute_id
  loop
    -- A published report, a receipt upload and an entry in it.
    n := n + 1;
    insert into app.media_assets
      (institute_id, kind, purpose, visibility, storage_key, mime_type, bytes, width, height, status, uploaded_by)
    values (given.institute_id, 'image', 'receipt', 'public',
      given.institute_id || '/' || (array['ZZA', 'ZZB'])[n] || '-receipt.webp', 'image/webp', 1000, 96, 96,
      'ready', given.created_by);
    insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
    values (given.institute_id, 'daily', current_date, current_date,
      jsonb_build_object('en', (array['ZZA', 'ZZB'])[n] || '-Report'), given.created_by)
    returning id into report_id;
    insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description,
      receipt_media_id, report_id, status, recorded_by)
    select given.institute_id, given.cause_id, 100000, current_date,
      jsonb_build_object('en', (array['ZZA', 'ZZB'])[n] || '-Wheat purchase'), m.id, report_id, 'recorded',
      given.created_by
    from app.media_assets m where m.institute_id = given.institute_id and m.purpose = 'receipt'
    returning id into entry_id;
    update app.spending_reports set status = 'published', published_at = now(), published_by = given.created_by
    where id = report_id;
    insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
      spending_report_id, recorded_by)
    values (given.institute_id, given.donation_id, 'reported', current_date, 1000, report_id, given.created_by);
    insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id,
      cause_id, spending_entry_id, amount_paisa, created_by)
    values (given.institute_id, 'to_spending', given.donation_id, given.donation_type, given.id,
      given.cause_id, entry_id, 1000, given.created_by)
    returning id into spend_id;
    insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
      cause_id, allocation_id, spending_entry_id, recorded_by)
    values (given.institute_id, given.donation_id, 'spent', current_date, 1000, given.cause_id, spend_id,
      entry_id, given.created_by)
    returning id into spent_event;
    insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id,
      cause_id, spending_entry_id, amount_paisa, is_reversal, reverses_allocation_id, reason, created_by)
    values (given.institute_id, 'to_spending', given.donation_id, given.donation_type, given.id,
      given.cause_id, entry_id, 1000, true, spend_id,
      'Fixture correction', given.created_by)
    returning id into reversal_id;
    insert into app.trail_events (institute_id, donation_id, event_type, occurred_on, amount_paisa,
      cause_id, allocation_id, spending_entry_id, reverses_event_id, reason, recorded_by)
    values (given.institute_id, given.donation_id, 'reversal', current_date, 1000, given.cause_id,
      reversal_id, entry_id, spent_event, 'Fixture correction', given.created_by);
  end loop;
end
$fixture$;
-- A pledge per institute and one payment linked to it (04 §8.8).
insert into app.recurring_pledges (id, institute_id, donor_id, cause_id, donation_type, frequency,
  amount_paisa, starts_on)
select ('14000000-0000-4000-8000-00000000070' || n.i)::uuid, d.institute_id, d.donor_id, d.cause_id,
  'general', 'monthly', 500000, current_date
from (values (1), (2)) as n(i)
cross join lateral (select * from app.donations
  where institute_id = ('14000000-0000-4000-8000-00000000000' || n.i)::uuid limit 1) d;
insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
  amount_minor, amount_paisa, donation_type, donor_id, pledge_id, receipt_number, receipt_locale, recorded_by)
select p.institute_id, gen_random_uuid(), ('14000000-0000-4000-8000-00000000020' || n.i)::uuid,
  n.mark || '-pledge-payment', current_date, 500000, 500000, 'general', p.donor_id, p.id,
  n.mark || '-PLEDGE-1', 'en', ('14000000-0000-4000-8000-00000000030' || n.i)::uuid
from (values (1, 'ZZA'), (2, 'ZZB')) as n(i, mark)
join app.recurring_pledges p on p.id = ('14000000-0000-4000-8000-00000000070' || n.i)::uuid;
update app.receipt_email_jobs j set trail_link_id = l.id
from app.trail_links l
where l.institute_id = j.institute_id and l.donor_id = j.donor_id and l.revoked_at is null;
-- Private and public donor profile fields (04 §8.2), each carrying its marker.
update app.donors d set
  user_id = ('14000000-0000-4000-8000-00000000030' || n.i)::uuid,
  photo_media_id = ('14000000-0000-4000-8000-00000000025' || n.i)::uuid,
  legal_name = n.mark || '-Legal', phone = '+92 300 000000' || n.i,
  display_name = n.mark || '-Display', profile_public = true,
  profile_links = jsonb_build_array(jsonb_build_object('label', n.mark || '-Link', 'url', 'https://example.test/' || n.mark)),
  email_verified_at = now(), claimed_at = now()
from (values (1, 'ZZA'), (2, 'ZZB')) as n(i, mark)
where d.institute_id = ('14000000-0000-4000-8000-00000000000' || n.i)::uuid;

-- Public trails, so public_api.public_trails has rows of both institutes.
update app.donations set trail_public = true
where institute_id in ('14000000-0000-4000-8000-000000000001', '14000000-0000-4000-8000-000000000002');

create temp table harness_relations on commit drop as
select c.oid::regclass as rel, c.relkind = 'v' as is_view,
  case when c.oid = 'app.institutes'::regclass then 'id'
    when exists (select from pg_attribute a where a.attrelid = c.oid and a.attname = 'institute_id' and not a.attisdropped)
    then 'institute_id' end as tenant_column
from pg_class c join pg_namespace s on s.oid = c.relnamespace
where (s.nspname in ('app', 'identity') and c.relkind in ('r', 'p'))
  or (s.nspname = 'public_api' and c.relkind = 'v');
grant select on harness_relations to tazkiyah_app, tazkiyah_auth;

-- Coverage: a new table without fixture rows in both institutes fails here.
do $coverage$
declare
  r record;
  rows_a bigint;
  rows_b bigint;
begin
  for r in select * from harness_relations where not is_view loop
    assert r.tenant_column is not null, r.rel || ' has no institute column';
    execute format('select count(*) filter (where %1$I = $1), count(*) filter (where %1$I = $2) from %2$s',
      r.tenant_column, r.rel)
      into rows_a, rows_b
      using '14000000-0000-4000-8000-000000000001'::uuid, '14000000-0000-4000-8000-000000000002'::uuid;
    assert rows_a > 0 and rows_b > 0, 'Add isolation fixture rows for ' || r.rel;
  end loop;
end
$coverage$;

-- Run the deferred ledger checks now, so the triggers can be switched off below.
set constraints all immediate;

-- 4: a row in A cannot point at a row in B through any composite foreign key.
do $foreign_keys$
declare
  fk record;
  child_cols text[];
  parent_cols text[];
  assignments text;
  filled text;
  affected bigint;
begin
  for fk in
    select c.conrelid::regclass as child, c.confrelid::regclass as parent, c.conkey, c.confkey, c.conname
    from pg_constraint c join harness_relations h on h.rel = c.conrelid
    where c.contype = 'f' and h.tenant_column = 'institute_id' and cardinality(c.conkey) > 1
  loop
    select array_agg(a.attname order by k.ord), array_agg(p.attname order by k.ord)
      into child_cols, parent_cols
    from unnest(fk.conkey, fk.confkey) with ordinality as k(child_att, parent_att, ord)
    join pg_attribute a on a.attrelid = fk.child and a.attnum = k.child_att
    join pg_attribute p on p.attrelid = fk.parent and p.attnum = k.parent_att;
    assert 'institute_id' = any(child_cols), fk.conname || ' does not include institute_id';

    select string_agg(format('%I = b.%I', c, p), ', ') into assignments
    from unnest(child_cols, parent_cols) as x(c, p) where c <> 'institute_id';
    select string_agg(format('%I is not null', c), ' and ') into filled
    from unnest(child_cols) as x(c) where c <> 'institute_id';
    begin
      execute format('alter table %s disable trigger user', fk.child);
      execute format(
        'with t as (update %1$s t set %2$s from (select * from %3$s where %4$I = $2 limit 1) b
         where t.ctid = (select ctid from %1$s where institute_id = $1 and %5$s limit 1) returning 1)
         select count(*) from t',
        fk.child, assignments, fk.parent,
        case when fk.parent = 'app.institutes'::regclass then 'id' else 'institute_id' end, filled)
        into affected
        using '14000000-0000-4000-8000-000000000001'::uuid, '14000000-0000-4000-8000-000000000002'::uuid;
      assert affected > 0, 'Add an isolation fixture row in ' || fk.child || ' that sets ' || fk.conname;
      raise exception 'Cross-institute link accepted by %', fk.conname using errcode = 'TZ001';
    exception when foreign_key_violation then
      null;
    end;
  end loop;
end
$foreign_keys$;

-- Runtime checks, once per runtime role.
create function pg_temp.harness_check(runtime_role text) returns void
language plpgsql as $check$
declare
  a constant uuid := '14000000-0000-4000-8000-000000000001';
  b constant uuid := '14000000-0000-4000-8000-000000000002';
  admin_a constant text := '14000000-0000-4000-8000-000000000301';
  admin_b constant text := '14000000-0000-4000-8000-000000000302';
  r record;
  leaked bigint;
  visitor_rows bigint;
  foreign_user_rows bigint;
  affected bigint;
  columns text;
  readable int := 0;
  sample jsonb;
begin
  for r in select * from harness_relations order by rel::text loop
    -- 2: inserting a row for B while in A's context fails, granted or not.
    if not r.is_view then
      execute format('set local role %I', current_setting('harness.owner'));
      execute format('select to_jsonb(t) from %s t where %I = $1 limit 1', r.rel, r.tenant_column)
        into sample using b;
      select string_agg(quote_ident(attname), ', ' order by attnum) into columns
      from pg_attribute
      where attrelid = r.rel and attnum > 0 and not attisdropped and attgenerated = ''
        and attidentity = '' and attname <> 'id';
      execute format('set local role %I', runtime_role);
      perform set_config('app.institute_id', a::text, true);
      perform set_config('app.user_id', admin_a, true);
      begin
        execute format('insert into %1$s (%2$s) select %2$s from jsonb_populate_record(null::%1$s, $1)',
          r.rel, columns) using sample;
        raise exception '% inserted a B row into % from A', runtime_role, r.rel using errcode = 'TZ002';
      exception when insufficient_privilege then
        null;
      end;

      -- 3: updates and deletes of B's rows touch nothing.
      begin
        execute format('with t as (update %1$s set %2$I = %2$I where %2$I = $1 returning 1) select count(*) from t',
          r.rel, r.tenant_column) into affected using b;
        assert affected = 0, runtime_role || ' updated B rows in ' || r.rel;
      exception when insufficient_privilege then
        null;
      end;
      begin
        execute format('with t as (delete from %1$s where %2$I = $1 returning 1) select count(*) from t',
          r.rel, r.tenant_column) into affected using b;
        assert affected = 0, runtime_role || ' deleted B rows in ' || r.rel;
      exception when insufficient_privilege then
        null;
      end;
    end if;

    if not has_table_privilege(runtime_role, r.rel, 'select') then
      continue;
    end if;
    readable := readable + 1;

    -- 1: A's admin sees nothing of B.
    perform set_config('app.institute_id', a::text, true);
    perform set_config('app.user_id', admin_a, true);
    execute format('select count(*) from %s t where t::text like ''%%ZZB-%%''', r.rel) into leaked;
    assert leaked = 0, runtime_role || ' read B rows from ' || r.rel || ' in A';
    if r.tenant_column is not null then
      execute format('select count(*) from %s where %I <> $1', r.rel, r.tenant_column) into leaked using a;
      assert leaked = 0, runtime_role || ' read foreign rows from ' || r.rel || ' in A';
    end if;

    -- 7: a user id from B carries no rights in A beyond a visitor's.
    perform set_config('app.user_id', '', true);
    execute format('select count(*) from %s', r.rel) into visitor_rows;
    perform set_config('app.user_id', admin_b, true);
    execute format('select count(*) from %s', r.rel) into foreign_user_rows;
    assert foreign_user_rows = visitor_rows, runtime_role || ' gave B''s admin extra rows of ' || r.rel || ' in A';

    -- 5: B's admin sees nothing of A.
    perform set_config('app.institute_id', b::text, true);
    perform set_config('app.user_id', admin_b, true);
    execute format('select count(*) from %s t where t::text like ''%%ZZA-%%''', r.rel) into leaked;
    assert leaked = 0, runtime_role || ' read A rows from ' || r.rel || ' in B';

    -- 6: no institute context, no rows.
    perform set_config('app.institute_id', '', true);
    perform set_config('app.user_id', '', true);
    execute format('select count(*) from %s', r.rel) into leaked;
    assert leaked = 0, runtime_role || ' read ' || r.rel || ' without an institute';
  end loop;
  assert readable > 0, runtime_role || ' can read no relation, so the checks proved nothing';
end
$check$;

select set_config('harness.owner', 'tazkiyah_schema_owner', true);
select pg_temp.harness_check('tazkiyah_app');
set local role tazkiyah_schema_owner;
select pg_temp.harness_check('tazkiyah_auth');

-- 8: B's trail token opens nothing in A, and still opens B's own trail in B.
set local role tazkiyah_auth;
do $token$
begin
  perform set_config('app.institute_id', '14000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '', true);
  assert not exists (select from identity.read_guest_trail(repeat('b1', 32), null, null)),
    'B''s trail token opened a trail in A';
  perform set_config('app.institute_id', '14000000-0000-4000-8000-000000000002', true);
  assert exists (select from identity.read_guest_trail(repeat('b1', 32), null, null)),
    'Control failed: B''s trail token does not open B''s trail';
end
$token$;

rollback;
