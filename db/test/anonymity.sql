-- The donor wall and anonymity across every public view and the audit log
-- (04 §8.5, 06 §10, P2-E5-T41, REQ-DPR-009).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('a3000000-0000-4000-8000-000000000001', 'anonymity-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('a3000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'ANO');
insert into app.users (id, institute_id, email, full_name, status) values
  ('a3000000-0000-4000-8000-000000000011', 'a3000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('a3000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000011', 'admin');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('a3000000-0000-4000-8000-000000000031', 'a3000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values
  ('a3000000-0000-4000-8000-000000000041', 'a3000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat"}', '{"en":"Wheat"}', 'monthly', 'active', true),
  ('a3000000-0000-4000-8000-000000000042', 'a3000000-0000-4000-8000-000000000001', 'hidden', 'ongoing',
    '{"en":"Hidden"}', '{"en":"Hidden"}', 'monthly', 'draft', false);
-- The donor has every personal field set and a public profile.
insert into app.donors (id, institute_id, email, legal_name, phone, display_name, profile_public, preferred_language)
values ('a3000000-0000-4000-8000-000000000051', 'a3000000-0000-4000-8000-000000000001',
  'qx-email@example.test', 'Qx Legal Name', '+92 300 0000000', 'Qx Display', true, 'en');

do $fixture$
declare
  tenant constant uuid := 'a3000000-0000-4000-8000-000000000001';
  admin constant uuid := 'a3000000-0000-4000-8000-000000000011';
  donor constant uuid := 'a3000000-0000-4000-8000-000000000051';
  bank constant uuid := 'a3000000-0000-4000-8000-000000000031';
  wheat constant uuid := 'a3000000-0000-4000-8000-000000000041';
  to_cause uuid; pooled uuid; returned uuid; report uuid; entry uuid;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);
  select donation_id into to_cause from app.record_donation(gen_random_uuid(), donor, wheat, 'zakat', 500000,
    date '2026-11-01', bank, 'Qx Bank Ref 1', 'en');
  select donation_id into pooled from app.record_donation(gen_random_uuid(), donor, null, 'sadaqah', 300000,
    date '2026-11-02', bank, 'Qx Bank Ref 2', 'en');
  select donation_id into returned from app.record_donation(gen_random_uuid(), donor, wheat, 'general', 100000,
    date '2026-11-02', bank, 'Qx Bank Ref 3', 'en');
  perform app.reverse_donation(returned, 'transfer_returned');
  update app.donations set trail_public = true where id in (to_cause, pooled);
  insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
  values (tenant, 'daily', date '2026-11-03', date '2026-11-03', '{"en":"Day"}', admin) returning id into report;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, report_id, status,
    recorded_by)
  values (tenant, wheat, 200000, date '2026-11-03', '{"en":"Wheat"}', report, 'recorded', admin) returning id into entry;
  perform app.match_spending(entry);
  perform app.publish_spending_report(report);
  -- A donor profile change is audited too.
  update app.donors set display_name = 'Qx Display Two', legal_name = 'Qx Legal Two' where id = donor;
end
$fixture$;

-- Audit rows of the donor and its donations carry none of the personal values.
do $test$
declare
  logged text;
begin
  select string_agg(to_jsonb(a)::text, ' ') into logged from app.audit_log a
  where a.institute_id = 'a3000000-0000-4000-8000-000000000001';
  assert logged ~ 'donations.recorded' and logged ~ 'donors', 'expected donation and donor audit rows';
  assert logged !~* 'qx', 'the audit log holds a personal value: ' || substring(logged from '(?i)(qx[^"]*)');
end
$test$;

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := 'a3000000-0000-4000-8000-000000000001';
  view_name regclass;
  seen text;
  shown bigint;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '', true);

  -- The donor wall: every recorded donation, amount and cause, no label.
  assert (select array_agg(amount_paisa || ':' || coalesce(cause_id::text, 'all needs') order by amount_paisa)
    from public_api.donor_wall)
    = array['300000:all needs', '500000:a3000000-0000-4000-8000-000000000041'], 'unexpected donor wall';
  assert not exists (select from public_api.donor_wall where donor_label is not null);
  assert not exists (select from pg_attribute where attrelid = 'public_api.donor_wall'::regclass and attnum > 0
    and attname in ('donor_id', 'email', 'receipt_number', 'donation_type', 'legal_name', 'bank_reference'));

  -- No public view, now or later, shows a personal value, the bank reference
  -- or the donation type of this institute's anonymous donations.
  for view_name in
    select c.oid::regclass from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public_api' and c.relkind = 'v'
  loop
    -- Values only: a column such as accepts_zakat may carry the word in its name.
    execute format('select count(distinct v::text), coalesce(string_agg(f.value, %L), %L)
      from %s v cross join lateral jsonb_each_text(to_jsonb(v)) f', ' ', '', view_name)
      into shown, seen;
    assert seen !~* 'qx|zakat|sadaqah|\+92', view_name || ' shows ' || substring(seen from '(?i)(qx[^"]*|zakat|sadaqah|\+92[^"]*)');
  end loop;
  -- The check ran over real rows in the money views.
  assert (select count(*) from public_api.public_trails) > 0 and (select count(*) from public_api.cause_spending) > 0;
end
$test$;

-- Named donations wait for donor accounts: the table still refuses them.
reset role;
set local role tazkiyah_schema_owner;
do $test$
begin
  update app.donations set is_anonymous = false where institute_id = 'a3000000-0000-4000-8000-000000000001';
  assert false, 'a named donation was stored before named giving exists';
exception when check_violation then null;
end
$test$;
