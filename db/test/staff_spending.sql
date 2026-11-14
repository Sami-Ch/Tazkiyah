-- Staff spending drafts, balances, FIFO recording and reversal (P2-E1-T01, T03, T04, T05).
begin;
grant tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('b6000000-0000-4000-8000-000000000001', 'staff-spend');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('b6000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SSP');
insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password) values
  ('b6000000-0000-4000-8000-000000000011', 'b6000000-0000-4000-8000-000000000001', 'finance@staff-spend.test', 'Finance', 'active', true, false),
  ('b6000000-0000-4000-8000-000000000012', 'b6000000-0000-4000-8000-000000000001', 'editor@staff-spend.test', 'Editor', 'active', false, false);
insert into app.user_roles (institute_id, user_id, role) values
  ('b6000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000011', 'finance_officer'),
  ('b6000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000012', 'editor');
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified) values
  ('b6000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000011', 'secret', 'codes', true);
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('b6000000-0000-4000-8000-000000000031', 'b6000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status) values
  ('b6000000-0000-4000-8000-000000000041', 'b6000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat","ur":"گندم"}', '{"en":"Wheat"}', 'monthly', 'active');
insert into app.donors (id, institute_id, preferred_language)
values ('b6000000-0000-4000-8000-000000000051', 'b6000000-0000-4000-8000-000000000001', 'en');

select set_config('app.institute_id', 'b6000000-0000-4000-8000-000000000001', true);
insert into identity.sessions (id, institute_id, user_id, token, expires_at, updated_at, two_factor_verified_at) values
  ('b6000000-0000-4000-8000-000000000061', 'b6000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000011', 'finance-session',
    now() + interval '1 hour', now(), now()),
  ('b6000000-0000-4000-8000-000000000062', 'b6000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000012', 'editor-session',
    now() + interval '1 hour', now(), null);

select set_config('app.user_id', 'b6000000-0000-4000-8000-000000000011', true);
select donation_id from app.record_donation(
  'b6000000-0000-4000-8000-000000000071',
  'b6000000-0000-4000-8000-000000000051',
  'b6000000-0000-4000-8000-000000000041',
  'general', 100000, current_date,
  'b6000000-0000-4000-8000-000000000031', 'wheat-gift', 'en');

reset role;
set local role tazkiyah_auth;
select set_config('app.institute_id', 'b6000000-0000-4000-8000-000000000001', true),
  set_config('app.user_id', 'b6000000-0000-4000-8000-000000000012', true);

do $test$
declare
  finance constant uuid := 'b6000000-0000-4000-8000-000000000061';
  editor constant uuid := 'b6000000-0000-4000-8000-000000000062';
  wheat constant uuid := 'b6000000-0000-4000-8000-000000000041';
  actor constant uuid := 'b6000000-0000-4000-8000-000000000011';
  saved_code text;
  saved_id uuid;
  big_id uuid;
  result record;
  workspace jsonb;
begin
  select code, entry_id into saved_code, saved_id from identity.save_spending_draft(
    editor, wheat, 40000, current_date, '{"en":"Flour"}'::jsonb, true);
  assert saved_code = 'denied' and saved_id is null, saved_code;

  perform set_config('app.user_id', actor::text, true);
  select code, entry_id into saved_code, saved_id from identity.save_spending_draft(
    finance, wheat, 40000, current_date, '{"en":"Flour","ur":"آٹا"}'::jsonb, true);
  assert saved_code = 'saved', saved_code;

  select code, entry_id into saved_code, big_id from identity.save_spending_draft(
    finance, wheat, 200000, current_date, '{"en":"Too much"}'::jsonb, true);
  assert saved_code = 'saved_over_balance', saved_code;

  select * into result from identity.record_spending_batch(finance, big_id);
  assert result.code = 'over_balance', result.code;
  workspace := identity.spending_workspace(finance);
  assert exists (
    select from jsonb_array_elements(workspace -> 'entries') entry
    where entry ->> 'id' = big_id::text and entry ->> 'status' = 'draft'
  ), 'over-balance draft was recorded';

  select * into result from identity.record_spending_batch(finance, saved_id);
  assert result.code = 'recorded', result.code;
  assert result.matched_paisa = 40000, result.matched_paisa::text;

  workspace := identity.spending_workspace(finance);
  assert exists (
    select from jsonb_array_elements(workspace -> 'causes') cause
    where cause ->> 'id' = wheat::text
      and exists (
        select from jsonb_array_elements(cause -> 'balances') balance
        where balance ->> 'donation_type' = 'general' and balance ->> 'unspent_paisa' = '60000'
      )
  ), workspace::text;

  assert identity.reverse_spending_entry(finance, saved_id, 'recorded_twice', null) = 'reversed', 'reversal failed';

  workspace := identity.spending_workspace(finance);
  assert (workspace ->> 'allowed')::boolean, 'workspace hidden from finance';
  assert workspace -> 'pools' is not null, 'pools missing';
  assert exists (
    select from jsonb_array_elements(workspace -> 'causes') cause
    where cause ->> 'id' = wheat::text
      and exists (
        select from jsonb_array_elements(cause -> 'balances') balance
        where balance ->> 'donation_type' = 'general' and balance ->> 'unspent_paisa' = '100000'
      )
  ), workspace::text;
  perform set_config('app.user_id', 'b6000000-0000-4000-8000-000000000012', true);
  assert identity.spending_workspace(editor) ->> 'allowed' = 'false', 'editor saw the money';
end
$test$;
