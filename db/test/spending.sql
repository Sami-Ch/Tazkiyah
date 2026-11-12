-- 04 §9.7 spending entries and reports (P2-E1-T40): receipt link, column lock
-- after matching, the per-entry cap, published reports, RLS and audit.
begin;
grant tazkiyah_app to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('9a000000-0000-4000-8000-000000000001', 'spending-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('9a000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'SPD');
insert into app.users (id, institute_id, email, full_name, status) values
  ('9a000000-0000-4000-8000-000000000011', '9a000000-0000-4000-8000-000000000001', 'finance@example.test', 'Finance', 'active'),
  ('9a000000-0000-4000-8000-000000000012', '9a000000-0000-4000-8000-000000000001', 'editor@example.test', 'Editor', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('9a000000-0000-4000-8000-000000000001', '9a000000-0000-4000-8000-000000000011', 'finance_officer'),
  ('9a000000-0000-4000-8000-000000000001', '9a000000-0000-4000-8000-000000000012', 'editor');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('9a000000-0000-4000-8000-000000000031', '9a000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status) values
  ('9a000000-0000-4000-8000-000000000041', '9a000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat"}', '{"en":"Wheat"}', 'monthly', 'active'),
  ('9a000000-0000-4000-8000-000000000042', '9a000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
    '{"en":"Gas"}', '{"en":"Gas"}', 'monthly', 'closed'),
  ('9a000000-0000-4000-8000-000000000043', '9a000000-0000-4000-8000-000000000001', 'draft', 'ongoing',
    '{"en":"Draft"}', '{"en":"Draft"}', 'monthly', 'draft');
insert into app.media_assets (id, institute_id, kind, purpose, visibility, storage_key, mime_type, bytes,
  width, height, status, uploaded_by) values
  ('9a000000-0000-4000-8000-000000000061', '9a000000-0000-4000-8000-000000000001', 'image', 'receipt', 'public',
    '9a000000-0000-4000-8000-000000000001/receipt.webp', 'image/webp', 1000, 96, 96, 'ready', '9a000000-0000-4000-8000-000000000011'),
  ('9a000000-0000-4000-8000-000000000062', '9a000000-0000-4000-8000-000000000001', 'image', 'cover', 'public',
    '9a000000-0000-4000-8000-000000000001/cover.webp', 'image/webp', 1000, 96, 96, 'ready', '9a000000-0000-4000-8000-000000000011');
insert into app.donors (id, institute_id, preferred_language)
values ('9a000000-0000-4000-8000-000000000051', '9a000000-0000-4000-8000-000000000001', 'en');

set constraints all immediate;
do $test$
declare
  tenant constant uuid := '9a000000-0000-4000-8000-000000000001';
  actor constant uuid := '9a000000-0000-4000-8000-000000000011';
  wheat constant uuid := '9a000000-0000-4000-8000-000000000041';
  gas constant uuid := '9a000000-0000-4000-8000-000000000042';
  first_gift uuid;
  second_gift uuid;
  first_source uuid;
  second_source uuid;
  entry uuid;
  unmatched uuid;
  report uuid;
begin
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', actor::text, true);
  select donation_id into first_gift from app.record_donation(gen_random_uuid(),
    '9a000000-0000-4000-8000-000000000051', wheat, 'general', 100000, current_date,
    '9a000000-0000-4000-8000-000000000031', 'first', 'en');
  select donation_id into second_gift from app.record_donation(gen_random_uuid(),
    '9a000000-0000-4000-8000-000000000051', wheat, 'general', 100000, current_date,
    '9a000000-0000-4000-8000-000000000031', 'second', 'en');
  select id into first_source from app.allocations where donation_id = first_gift;
  select id into second_source from app.allocations where donation_id = second_gift;

  -- Where an entry may spend from, and what its photo may be.
  begin
    insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, recorded_by)
    values (tenant, '9a000000-0000-4000-8000-000000000043', 10000, current_date, '{"en":"x"}', actor);
    assert false, 'an entry spent from a draft cause';
  exception when check_violation then null;
  end;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
  values (tenant, gas, 10000, current_date, '{"en":"Last cylinder"}', 'recorded', actor);
  begin
    insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description,
      receipt_media_id, recorded_by)
    values (tenant, wheat, 10000, current_date, '{"en":"x"}', '9a000000-0000-4000-8000-000000000062', actor);
    assert false, 'a cover photo was used as a receipt';
  exception when check_violation then null;
  end;
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description,
    receipt_media_id, recorded_by)
  values (tenant, wheat, 150000, current_date, '{"en":"Wheat, 30 maunds"}',
    '9a000000-0000-4000-8000-000000000061', actor)
  returning id into entry;
  assert not (select receipt_public from app.spending_entries where id = entry),
    'Receipts on unconfigured causes must default to private';
  insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, recorded_by)
  values (tenant, wheat, 10000, current_date, '{"en":"Typo"}', actor)
  returning id into unmatched;
  assert exists (select from app.audit_log where entity_table = 'spending_entries' and entity_id = entry::text);

  -- A draft may change or be deleted, but not be matched, filed in a report or reversed.
  begin
    update app.spending_entries set cause_id = '9a000000-0000-4000-8000-000000000043' where id = unmatched;
    assert false, 'an entry moved to a draft cause';
  exception when check_violation then null;
  end;
  update app.spending_entries set amount_paisa = 160000 where id = entry;
  update app.spending_entries set amount_paisa = 150000 where id = entry;
  begin
    insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
      spending_entry_id, amount_paisa, created_by)
    values (tenant, 'to_spending', first_gift, 'general', first_source, wheat, entry, 100, actor);
    assert false, 'a draft entry was matched';
  exception when check_violation then null;
  end;
  insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
  values (tenant, 'daily', current_date, current_date, '{"en":"Today"}', actor)
  returning id into report;
  begin
    update app.spending_entries set report_id = report where id = entry;
    assert false, 'a draft entry was filed in a report';
  exception when check_violation then null;
  end;
  begin
    update app.spending_entries set status = 'reversed' where id = unmatched;
    assert false, 'a draft entry was reversed';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    insert into app.spending_entries (institute_id, cause_id, amount_paisa, spent_on, description, status, recorded_by)
    values (tenant, wheat, 10000, current_date, '{"en":"x"}', 'reversed', actor);
    assert false, 'an entry started as reversed';
  exception when check_violation then null;
  end;
  delete from app.spending_entries where id = unmatched;

  -- "Record batch": from now on amount, cause and date are fixed, matched or not.
  update app.spending_entries set status = 'recorded' where id = entry;
  begin
    update app.spending_entries set amount_paisa = 140000 where id = entry;
    assert false, 'a recorded entry changed its amount before matching';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.spending_entries set status = 'draft' where id = entry;
    assert false, 'a recorded entry went back to draft';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- Spends match an entry of their own cause, within its amount.
  begin
    insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
      spending_entry_id, amount_paisa, created_by)
    values (tenant, 'to_spending', first_gift, 'general', first_source, wheat,
      (select id from app.spending_entries where cause_id = gas), 100, actor);
    assert false, 'a spend matched an entry of another cause';
  exception when check_violation then null;
  end;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
    spending_entry_id, amount_paisa, created_by)
  values (tenant, 'to_spending', first_gift, 'general', first_source, wheat, entry, 100000, actor);
  begin
    insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
      spending_entry_id, amount_paisa, created_by)
    values (tenant, 'to_spending', second_gift, 'general', second_source, wheat, entry, 50100, actor);
    assert false, 'an entry was matched beyond its amount';
  exception when check_violation then null;
  end;
  insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
    spending_entry_id, amount_paisa, created_by)
  values (tenant, 'to_spending', second_gift, 'general', second_source, wheat, entry, 50000, actor);

  -- After matching: text, receipt and report only; status one way; no delete.
  update app.spending_entries set description = '{"en":"Wheat, 30 maunds, Sahiwal mandi"}', receipt_public = false
  where id = entry;
  begin
    update app.spending_entries set amount_paisa = 140000 where id = entry;
    assert false, 'a matched entry changed its amount';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.spending_entries set spent_on = spent_on - 1 where id = entry;
    assert false, 'a matched entry changed its date';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    delete from app.spending_entries where id = entry;
    assert false, 'a matched entry was deleted';
  exception when object_not_in_prerequisite_state then null;
  end;
  update app.spending_entries set status = 'reversed' where id = entry;
  begin
    update app.spending_entries set status = 'recorded' where id = entry;
    assert false, 'a reversed entry was restored';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    insert into app.allocations (institute_id, kind, donation_id, donation_type, from_allocation_id, cause_id,
      spending_entry_id, amount_paisa, created_by)
    values (tenant, 'to_spending', second_gift, 'general', second_source, wheat, entry, 100, actor);
    assert false, 'a reversed entry was matched';
  exception when check_violation then null;
  end;

  -- Reports: a day is one date; publishing needs who and when; then it is fixed.
  begin
    insert into app.spending_reports (institute_id, period_kind, period_start, period_end, title, created_by)
    values (tenant, 'daily', current_date - 1, current_date, '{"en":"Two days"}', actor);
    assert false, 'a daily report covered two days';
  exception when check_violation then null;
  end;
  update app.spending_entries set report_id = report where id = entry;
  begin
    update app.spending_reports set status = 'published' where id = report;
    assert false, 'a report was published without who and when';
  exception when check_violation then null;
  end;
  update app.spending_reports set status = 'published', published_at = now(), published_by = actor where id = report;
  begin
    update app.spending_reports set title = '{"en":"Edited"}' where id = report;
    assert false, 'a published report changed';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    delete from app.spending_reports where id = report;
    assert false, 'a published report was deleted';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.spending_entries set report_id = null where id = entry;
    assert false, 'an entry left a published report';
  exception when object_not_in_prerequisite_state then null;
  end;
  begin
    update app.spending_entries set report_id = report
    where cause_id = gas;
    assert false, 'a published report gained an entry';
  exception when object_not_in_prerequisite_state then null;
  end;
end
$test$;
set constraints all deferred;

-- RLS: admins and finance officers read; others read nothing; nobody writes directly.
set local role tazkiyah_app;
do $test$
begin
  assert not has_table_privilege('tazkiyah_app', 'app.spending_entries', 'INSERT, UPDATE, DELETE');
  assert not has_table_privilege('tazkiyah_app', 'app.spending_reports', 'INSERT, UPDATE, DELETE');
  perform set_config('app.institute_id', '9a000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '9a000000-0000-4000-8000-000000000011', true);
  assert (select count(*) from app.spending_entries) = 2;
  assert (select count(*) from app.spending_reports) = 1;
  perform set_config('app.user_id', '9a000000-0000-4000-8000-000000000012', true);
  assert not exists (select from app.spending_entries);
  assert not exists (select from app.spending_reports);
  perform set_config('app.user_id', '', true);
  assert not exists (select from app.spending_entries);
end
$test$;
