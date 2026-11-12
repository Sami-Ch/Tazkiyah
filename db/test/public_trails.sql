-- public_api.cause_spending and public_api.public_trails (04 §6.5, P2-E6-T40).
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('9f000000-0000-4000-8000-000000000001', 'public-trail-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('9f000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'PUB');
insert into app.users (id, institute_id, email, full_name, status) values
  ('9f000000-0000-4000-8000-000000000011', '9f000000-0000-4000-8000-000000000001', 'admin@example.test',
    'Secret Admin Name', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('9f000000-0000-4000-8000-000000000001', '9f000000-0000-4000-8000-000000000011', 'admin');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('9f000000-0000-4000-8000-000000000031', '9f000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values ('9f000000-0000-4000-8000-000000000041', '9f000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
  '{"en":"Wheat"}', '{"en":"Wheat"}', 'monthly', 'active', true);
insert into app.donors (id, institute_id, email, legal_name, display_name, profile_public, preferred_language) values
  ('9f000000-0000-4000-8000-000000000051', '9f000000-0000-4000-8000-000000000001', 'secret-anon@example.test',
    'Secret Legal Anon', 'Secret Display Anon', true, 'en'),
  ('9f000000-0000-4000-8000-000000000052', '9f000000-0000-4000-8000-000000000001', 'secret-named@example.test',
    'Secret Legal Named', 'Ayesha', true, 'en');
insert into app.media_assets (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes,
  width, height, status, uploaded_by) values
  ('9f000000-0000-4000-8000-000000000061', '9f000000-0000-4000-8000-000000000001', 'image', 'receipt', 'public',
    '9f000000-0000-4000-8000-000000000001/r1.webp', 'image/webp', 1000, 96, 96, 'ready',
    '9f000000-0000-4000-8000-000000000011'),
  ('9f000000-0000-4000-8000-000000000062', '9f000000-0000-4000-8000-000000000001', 'image', 'receipt', 'public',
    '9f000000-0000-4000-8000-000000000001/r2.webp', 'image/webp', 1000, 96, 96, 'ready',
    '9f000000-0000-4000-8000-000000000011');

do $fixture$
declare
  tenant constant uuid := '9f000000-0000-4000-8000-000000000001';
  admin constant uuid := '9f000000-0000-4000-8000-000000000011';
  bank constant uuid := '9f000000-0000-4000-8000-000000000031';
  wheat constant uuid := '9f000000-0000-4000-8000-000000000041';
  anon uuid; named uuid; private_gift uuid; returned uuid;
  published uuid; pending uuid;
  shown uuid; hidden_receipt uuid; unpublished uuid;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', admin::text, true);
  select donation_id into anon from app.record_donation(gen_random_uuid(), '9f000000-0000-4000-8000-000000000051',
    wheat, 'zakat', 500000, date '2026-11-01', bank, 'Secret Ref A', 'en', true);
  select donation_id into named from app.record_donation(gen_random_uuid(), '9f000000-0000-4000-8000-000000000052',
    wheat, 'general', 300000, date '2026-11-02', bank, 'Secret Ref N', 'en', true);
  select donation_id into private_gift from app.record_donation(gen_random_uuid(), '9f000000-0000-4000-8000-000000000052',
    wheat, 'general', 200000, date '2026-11-03', bank, 'Secret Ref P', 'en', true);
  select donation_id into returned from app.record_donation(gen_random_uuid(), '9f000000-0000-4000-8000-000000000052',
    wheat, 'general', 100000, date '2026-11-03', bank, 'Secret Ref R', 'en', true);
  update app.donations set trail_public = true where id in (anon, named, returned);
  perform app.reverse_donation(returned, 'recorded_twice', 'Secret note about the donor');

  insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
  values (tenant, 'weekly', date '2026-11-01', date '2026-11-07', '{"en":"Week 1"}', admin) returning id into published;
  insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
  values (tenant, 'weekly', date '2026-11-08', date '2026-11-14', '{"en":"Week 2"}', admin) returning id into pending;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, receipt_media_id,
    report_id, status, recorded_by)
  values (tenant, wheat, 600000, date '2026-11-04', '{"en":"Wheat, 10 maunds"}',
    '9f000000-0000-4000-8000-000000000061', published, 'recorded', admin) returning id into shown;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, receipt_media_id,
    receipt_public, report_id, status, recorded_by)
  values (tenant, wheat, 100000, date '2026-11-05', '{"en":"Milling"}',
    '9f000000-0000-4000-8000-000000000062', false, published, 'recorded', admin) returning id into hidden_receipt;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, report_id, status,
    recorded_by)
  values (tenant, wheat, 50000, date '2026-11-09', '{"en":"Not yet reported"}', pending, 'recorded', admin)
  returning id into unpublished;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, recorded_by)
  values (tenant, wheat, 50000, date '2026-11-09', '{"en":"Draft"}', admin);
  perform app.match_spending(shown);
  perform app.match_spending(hidden_receipt);
  perform app.match_spending(unpublished);
  update app.spending_reports set status = 'published', published_at = now(), published_by = admin
  where id = published;
end
$fixture$;

set local role tazkiyah_app;
do $test$
declare
  tenant constant uuid := '9f000000-0000-4000-8000-000000000001';
  everything text;
  forbidden text;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '', true);

  -- Spending: only entries in a published report, receipts only where public.
  assert (select array_agg(description ->> 'en' order by spent_on) from public_api.cause_spending)
    = array['Wheat, 10 maunds', 'Milling'], 'unpublished or draft entries are public';
  assert (select receipt_media_id from public_api.cause_spending where description ->> 'en' = 'Wheat, 10 maunds')
    = '9f000000-0000-4000-8000-000000000061';
  assert (select receipt_media_id from public_api.cause_spending where description ->> 'en' = 'Milling') is null,
    'a private receipt is public';
  -- 500,000 Zakat then 100,000 of the named gift cover the first entry; the rest
  -- of the named gift covers the second.
  assert (select (matched_paisa, uncovered_paisa) = (600000::bigint, 0::bigint)
    from public_api.cause_spending where description ->> 'en' = 'Wheat, 10 maunds');

  -- Public trails: only donations made public, and the reversed one shows its correction.
  assert (select count(distinct public_ref) from public_api.public_trails) = 3;
  assert not exists (select from public_api.public_trails where donation_amount_paisa = 200000),
    'a private trail is public';
  assert (select array_agg(event_type order by event_id) from public_api.public_trails
    where donation_amount_paisa = 500000) = array['received', 'allocated', 'spent'];
  assert (select spending_description ->> 'en' from public_api.public_trails
    where donation_amount_paisa = 500000 and event_type = 'spent') = 'Wheat, 10 maunds';
  assert (select array_agg(coalesce(reversal_category, '-') order by event_id) from public_api.public_trails
    where donation_amount_paisa = 100000) = array['-', '-', 'recorded_twice', 'recorded_twice'];

  -- Every donation is anonymous for now (donations_anonymity_check), so no label
  -- shows, though both donors have public profiles.
  assert not exists (select from public_api.public_trails where donor_label is not null);

  -- No column of either view carries a secret, the donation type or a staff name (REQ-DPR-009, REQ-TRL-010).
  select string_agg(to_jsonb(t)::text, ' ') into everything from public_api.public_trails t;
  everything := everything || (select string_agg(to_jsonb(s)::text, ' ') from public_api.cause_spending s);
  assert everything !~* 'secret|zakat|general', 'a public view leaked: ' || substring(everything from '(?i)(secret[^"]*|zakat|general)');
  select string_agg(attname, ', ') into forbidden from pg_attribute
  where attrelid in ('public_api.public_trails'::regclass, 'public_api.cause_spending'::regclass) and attnum > 0
    and attname in ('donor_id', 'donation_type', 'receipt_number', 'bank_reference', 'bank_account_id',
      'recorded_by', 'created_by', 'email', 'legal_name', 'private_note', 'operation_id');
  assert forbidden is null, 'public views expose ' || forbidden;
end
$test$;
