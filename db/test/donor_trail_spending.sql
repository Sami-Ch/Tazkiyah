-- P2-E2-T05: a donor's private trail shows the share of a purchase and a
-- published report, and never a private receipt photo.
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('9b000000-0000-4000-8000-000000000001', 'trail-spend');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('9b000000-0000-4000-8000-000000000001', '{"en":"Institute","ur":"ادارہ"}', '{"en":"A"}', '{}', 'TRL');
insert into app.users (id, institute_id, email, full_name, status, email_verified) values
  ('9b000000-0000-4000-8000-000000000011', '9b000000-0000-4000-8000-000000000001', 'finance@trail.test', 'Finance', 'active', true);
insert into app.user_roles (institute_id, user_id, role) values
  ('9b000000-0000-4000-8000-000000000001', '9b000000-0000-4000-8000-000000000011', 'finance_officer'),
  ('9b000000-0000-4000-8000-000000000001', '9b000000-0000-4000-8000-000000000011', 'admin');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('9b000000-0000-4000-8000-000000000031', '9b000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status) values
  ('9b000000-0000-4000-8000-000000000041', '9b000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat","ur":"گندم"}', '{"en":"Wheat"}', 'monthly', 'active');
insert into app.media_assets (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes,
  width, height, status, shows_face, uploaded_by) values
  ('9b000000-0000-4000-8000-000000000061', '9b000000-0000-4000-8000-000000000001', 'image', 'receipt', 'public',
    '9b000000-0000-4000-8000-000000000001/public.webp', 'image/webp', 1000, 96, 96, 'ready', false,
    '9b000000-0000-4000-8000-000000000011'),
  ('9b000000-0000-4000-8000-000000000062', '9b000000-0000-4000-8000-000000000001', 'image', 'receipt', 'private',
    '9b000000-0000-4000-8000-000000000001/private.webp', 'image/webp', 1000, 96, 96, 'ready', false,
    '9b000000-0000-4000-8000-000000000011');
insert into app.donors (id, institute_id, preferred_language)
values ('9b000000-0000-4000-8000-000000000051', '9b000000-0000-4000-8000-000000000001', 'ur');

set constraints all immediate;
do $test$
declare
  tenant constant uuid := '9b000000-0000-4000-8000-000000000001';
  actor constant uuid := '9b000000-0000-4000-8000-000000000011';
  wheat constant uuid := '9b000000-0000-4000-8000-000000000041';
  donor constant uuid := '9b000000-0000-4000-8000-000000000051';
  gift uuid;
  public_entry uuid;
  private_entry uuid;
  report uuid;
  events jsonb;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', actor::text, true);
  select donation_id into gift from app.record_donation(gen_random_uuid(),
    donor, wheat, 'sadaqah', 200000, current_date,
    '9b000000-0000-4000-8000-000000000031', 'trail-ref', 'ur');

  insert into app.spending_entries (id, institute_id, cause_id, amount_paisa, spent_on, description,
    receipt_media_id, receipt_public, status, recorded_by)
  values ('9b000000-0000-4000-8000-000000000071', tenant, wheat, 150000, current_date,
    '{"en":"40 kg of wheat","ur":"40 کلو گندم"}',
    '9b000000-0000-4000-8000-000000000061', true, 'recorded', actor)
  returning id into public_entry;
  insert into app.spending_entries (id, institute_id, cause_id, amount_paisa, spent_on, description,
    receipt_media_id, receipt_public, status, recorded_by)
  values ('9b000000-0000-4000-8000-000000000072', tenant, wheat, 50000, current_date,
    '{"en":"Teacher salary share","ur":"تنخواہ کا حصہ"}',
    '9b000000-0000-4000-8000-000000000062', false, 'recorded', actor)
  returning id into private_entry;
  perform app.match_spending(public_entry);
  perform app.match_spending(private_entry);

  insert into app.spending_reports (id, institute_id, period_kind, period_start, period_end, title, created_by)
  values ('9b000000-0000-4000-8000-000000000081', tenant, 'daily', current_date, current_date,
    '{"en":"12 November report","ur":"12 نومبر کی رپورٹ"}', actor)
  returning id into report;
  update app.spending_entries set report_id = report
  where institute_id = tenant and id in (public_entry, private_entry);
  perform app.publish_spending_report(report);

  select t.events into events from identity.donation_trail_page(donor, null, null, null) t;
  assert (select count(*) from jsonb_array_elements(events) e where e->>'event_type' = 'spent') = 2,
    'both purchases are on the private trail';
  assert exists (
    select from jsonb_array_elements(events) e
    where e->>'event_type' = 'spent' and e->'description'->>'ur' = '40 کلو گندم'
      and e->>'amount_paisa' = '150000'
      and e->>'receipt_key' = '9b000000-0000-4000-8000-000000000001/public.webp'
  ), 'the public wheat receipt is included with the donor share';
  assert exists (
    select from jsonb_array_elements(events) e
    where e->>'event_type' = 'spent' and e->'description'->>'en' = 'Teacher salary share'
      and e->>'receipt_key' is null
  ), 'a private receipt photo stays off the donor trail';
  assert exists (
    select from jsonb_array_elements(events) e
    where e->>'event_type' = 'reported' and e->>'amount_paisa' = '200000'
      and e->'description'->>'en' = '12 November report'
  ), 'the published report is one event for the donation';
  assert not exists (
    select from jsonb_array_elements(events) e where e::text like '%private.webp%'
  ), 'the private storage key never leaves the database';
end
$test$;
rollback;
