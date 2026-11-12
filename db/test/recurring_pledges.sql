-- 04 §8.8 recurring pledges (P1-E3-T47) and donations.pledge_id.
begin;
grant tazkiyah_app, tazkiyah_auth to current_user;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values ('96000000-0000-4000-8000-000000000001', 'pledge-fixture');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
values ('96000000-0000-4000-8000-000000000001', '{"en":"Institute"}', '{"en":"A"}', '{}', 'PLG');
insert into app.users (id, institute_id, email, full_name, status) values
  ('96000000-0000-4000-8000-000000000011', '96000000-0000-4000-8000-000000000001', 'admin@example.test', 'Admin', 'active');
insert into app.user_roles (institute_id, user_id, role) values
  ('96000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000011', 'admin');
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
values ('96000000-0000-4000-8000-000000000031', '96000000-0000-4000-8000-000000000001',
  '{"en":"Main"}', 'Bank', 'Title', 'number');
insert into app.causes (id, institute_id, slug, cause_type, title, summary, target_period, status, accepts_zakat)
values
  ('96000000-0000-4000-8000-000000000041', '96000000-0000-4000-8000-000000000001', 'gas', 'ongoing',
    '{"en":"Gas"}', '{"en":"Gas"}', 'monthly', 'active', false),
  ('96000000-0000-4000-8000-000000000042', '96000000-0000-4000-8000-000000000001', 'wheat', 'ongoing',
    '{"en":"Wheat"}', '{"en":"Wheat"}', 'monthly', 'active', true);
insert into app.donors (id, institute_id, preferred_language) values
  ('96000000-0000-4000-8000-000000000051', '96000000-0000-4000-8000-000000000001', 'en'),
  ('96000000-0000-4000-8000-000000000052', '96000000-0000-4000-8000-000000000001', 'en');

do $test$
declare
  tenant constant uuid := '96000000-0000-4000-8000-000000000001';
  donor constant uuid := '96000000-0000-4000-8000-000000000051';
  other_donor constant uuid := '96000000-0000-4000-8000-000000000052';
  gas constant uuid := '96000000-0000-4000-8000-000000000041';
  wheat constant uuid := '96000000-0000-4000-8000-000000000042';
  pledge uuid;
  payment uuid;
begin
  assert not has_table_privilege('tazkiyah_app', 'app.recurring_pledges', 'SELECT, INSERT, UPDATE, DELETE');
  assert not has_table_privilege('tazkiyah_auth', 'app.recurring_pledges', 'SELECT, INSERT, UPDATE, DELETE');
  perform set_config('app.institute_id', tenant::text, true);
  perform set_config('app.user_id', '96000000-0000-4000-8000-000000000011', true);

  begin
    insert into app.recurring_pledges (institute_id, donor_id, cause_id, donation_type, frequency, amount_paisa, starts_on)
    values (tenant, donor, gas, 'zakat', 'monthly', 500000, date '2026-12-01');
    assert false, 'a Zakat pledge went to a cause that does not accept Zakat';
  exception when check_violation then null;
  end;
  begin
    insert into app.recurring_pledges (institute_id, donor_id, donation_type, frequency, amount_paisa, starts_on)
    values (tenant, donor, 'general', 'weekly', 500000, date '2026-12-01');
    assert false, 'a weekly pledge was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into app.recurring_pledges (institute_id, donor_id, donation_type, frequency, amount_paisa, starts_on)
    values (tenant, donor, 'general', 'monthly', 500050, date '2026-12-01');
    assert false, 'a pledge in part-rupees was accepted';
  exception when check_violation then null;
  end;
  insert into app.recurring_pledges (institute_id, donor_id, cause_id, donation_type, frequency, amount_paisa, starts_on)
  values (tenant, donor, wheat, 'zakat', 'monthly', 500000, date '2026-12-01')
  returning id into pledge;
  assert (select is_anonymous and status = 'active' and missed_periods = 0
    from app.recurring_pledges where id = pledge);
  assert exists (select from app.audit_log where entity_table = 'recurring_pledges' and entity_id = pledge::text);

  -- Payments are ordinary donations from the pledge's donor.
  begin
    insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
      amount_minor, amount_paisa, donation_type, donor_id, cause_id, pledge_id, receipt_number,
      receipt_locale, recorded_by)
    values (tenant, gen_random_uuid(), '96000000-0000-4000-8000-000000000031', 'other-donor',
      date '2026-12-02', 500000, 500000, 'zakat', other_donor, wheat, pledge, 'PLG-T-1', 'en',
      '96000000-0000-4000-8000-000000000011');
    assert false, 'a pledge payment came from another donor';
  exception when check_violation then null;
  end;
  insert into app.donations (institute_id, operation_id, bank_account_id, bank_reference, credited_on,
    amount_minor, amount_paisa, donation_type, donor_id, cause_id, pledge_id, receipt_number,
    receipt_locale, recorded_by)
  values (tenant, gen_random_uuid(), '96000000-0000-4000-8000-000000000031', 'pledge-payment',
    date '2026-12-02', 500000, 500000, 'zakat', donor, wheat, pledge, 'PLG-T-2', 'en',
    '96000000-0000-4000-8000-000000000011')
  returning id into payment;
  assert (select frequency from app.donations where id = payment) = 'one_off';
  begin
    update app.donations set pledge_id = null where id = payment;
    assert false, 'a payment was unlinked from its pledge';
  exception when object_not_in_prerequisite_state then null;
  end;

  -- The promise is fixed; only the state moves, and cancelled is final.
  begin
    update app.recurring_pledges set amount_paisa = 600000 where id = pledge;
    assert false, 'a pledge amount changed';
  exception when object_not_in_prerequisite_state then null;
  end;
  update app.recurring_pledges set missed_periods = 3, status = 'lapsed' where id = pledge;
  update app.recurring_pledges set missed_periods = 0, status = 'active' where id = pledge;
  begin
    update app.recurring_pledges set status = 'cancelled' where id = pledge;
    assert false, 'a pledge was cancelled with no time';
  exception when check_violation then null;
  end;
  update app.recurring_pledges set status = 'cancelled', cancelled_at = now() where id = pledge;
  begin
    update app.recurring_pledges set status = 'active', cancelled_at = null where id = pledge;
    assert false, 'a cancelled pledge was restarted';
  exception when object_not_in_prerequisite_state then null;
  end;
end
$test$;
