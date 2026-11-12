-- P0-E2-T19: query plans of the policy helpers and the donation reads with
-- seeded volume (04 §13.1). 5,000 donations in one institute and 1,000 in a
-- second one go through the real recording function, then every read that
-- looks up a few rows must use an index. 20,000 hub posts follow, read under
-- row-level security as a student and a teacher.
begin;
set local plpgsql.check_asserts = on;
set local role tazkiyah_schema_owner;

insert into app.institutes (id, slug) values
  ('19000000-0000-4000-8000-000000000001', 'plan-fixture-a'),
  ('19000000-0000-4000-8000-000000000002', 'plan-fixture-b');
insert into app.institute_settings (institute_id, name, address, theme, receipt_prefix)
select id, '{"en":"Plan institute"}', '{"en":"Plan address"}', '{}', 'PLAN'
from app.institutes where slug in ('plan-fixture-a', 'plan-fixture-b');
insert into app.institute_domains (institute_id, domain)
values ('19000000-0000-4000-8000-000000000001', 'plan-a.example.test');

insert into app.users (id, institute_id, email, full_name, status, two_factor_enabled, must_change_password)
select ('19000000-0000-4000-8000-00000000001' || n)::uuid, ('19000000-0000-4000-8000-00000000000' || n)::uuid,
  'plan-admin-' || n || '@example.test', 'Plan admin', 'active', true, false
from generate_series(1, 2) n;
insert into app.user_roles (institute_id, user_id, role)
select institute_id, id, 'admin' from app.users where full_name = 'Plan admin';
-- Donor and student accounts, so sign-in lookups face realistic volume.
insert into app.users (institute_id, email, username, full_name, status)
select '19000000-0000-4000-8000-000000000001',
  case when n % 2 = 0 then 'plan-user-' || n || '@example.test' end,
  case when n % 2 = 1 then 'plan-' || lpad(n::text, 4, '0') end, 'Plan user', 'active'
from generate_series(1, 2000) n;
insert into identity.two_factor (institute_id, user_id, secret, backup_codes, verified)
select institute_id, id, 'fixture-secret', 'fixture-codes', true from app.users where full_name = 'Plan admin';
insert into identity.sessions (id, institute_id, user_id, token, expires_at, two_factor_verified_at)
select ('19000000-0000-4000-8000-00000000002' || n)::uuid, ('19000000-0000-4000-8000-00000000000' || n)::uuid,
  ('19000000-0000-4000-8000-00000000001' || n)::uuid, 'plan-session-' || n, now() + interval '1 hour', now()
from generate_series(1, 2) n;
insert into app.institute_bank_accounts (id, institute_id, label, bank_name, account_title, account_number)
select ('19000000-0000-4000-8000-00000000003' || n)::uuid, ('19000000-0000-4000-8000-00000000000' || n)::uuid,
  '{"en":"Plan account"}', 'Plan bank', 'Plan institute', 'plan-account-' || n
from generate_series(1, 2) n;
insert into app.causes (id, institute_id, slug, cause_type, title, summary, status, target_period)
select ('19000000-0000-4000-8000-0000000001' || lpad(n::text, 2, '0'))::uuid,
  ('19000000-0000-4000-8000-00000000000' || (1 + n % 2))::uuid,
  'plan-cause-' || n, 'ongoing', '{"en":"Cause","ur":"مد"}', '{"en":"Cause","ur":"مد"}', 'active', 'yearly'
from generate_series(1, 20) n;

reset role;
set local role tazkiyah_auth;
do $seed$
declare
  result record;
  today constant date := (now() at time zone 'Asia/Karachi')::date;
begin
  for tenant in 1..2 loop
    perform set_config('app.institute_id', '19000000-0000-4000-8000-00000000000' || tenant, true);
    perform set_config('app.user_id', '19000000-0000-4000-8000-00000000001' || tenant, true);
    for n in 1..(case tenant when 1 then 5000 else 1000 end) loop
      select * into strict result from identity.record_manual_donation(
        ('19000000-0000-4000-8000-00000000002' || tenant)::uuid, gen_random_uuid(),
        ('19000000-0000-4000-8000-00000000003' || tenant)::uuid, 'plan-ref-' || n,
        today - (n % 365), 10000 + (n % 50) * 100, 'general',
        case when n % 4 = 0 then null
          else ('19000000-0000-4000-8000-0000000001' || lpad((2 * (n % 10) + 3 - tenant)::text, 2, '0'))::uuid end,
        'plan-donor-' || (n % 500) || '@example.test', 'en', true, false, true
      );
      assert result.code = 'recorded', 'Fixture donation was not recorded: ' || result.code;
    end loop;
  end loop;
end
$seed$;

-- One private trail link for each of the 500 guest donors.
reset role;
create temporary table plan_receipts on commit drop as
select distinct on (o.id) o.email, d.receipt_number from app.donations d
join app.donors o on (o.institute_id, o.id) = (d.institute_id, d.donor_id)
where d.institute_id = '19000000-0000-4000-8000-000000000001'
order by o.id, d.recorded_at;
grant select on plan_receipts to tazkiyah_auth;
set local role tazkiyah_auth;
do $link$
declare
  donor record;
begin
  perform set_config('app.institute_id', '19000000-0000-4000-8000-000000000001', true);
  perform set_config('app.user_id', '19000000-0000-4000-8000-000000000011', true);
  for donor in select * from plan_receipts loop
    assert identity.issue_trail_link(
      '19000000-0000-4000-8000-000000000021', donor.receipt_number, donor.email,
      case when donor.email = 'plan-donor-7@example.test' then repeat('7', 64)
        else encode(sha256(convert_to(donor.email, 'UTF8')), 'hex') end, 'plan'
    ) = 'issued', 'Fixture trail link was not issued';
  end loop;
end
$link$;

reset role;
analyze app.donations, app.donors, app.allocations, app.trail_events, app.trail_links, app.causes,
  app.users, app.user_roles;

create function pg_temp.plan_of(query text) returns text
language plpgsql as $function$
declare
  line text;
  plan text := '';
begin
  for line in execute 'explain (costs off) ' || query loop
    plan := plan || line || E'\n';
  end loop;
  return plan;
end
$function$;

-- The plan must reach the rows through the named index, not scan a table or
-- read every row of the institute through a wider index.
create function pg_temp.assert_indexed(label text, index_name text, query text) returns void
language plpgsql as $function$
declare
  plan text := pg_temp.plan_of(query);
begin
  assert plan ~ ('(using|Index Scan on) ' || index_name || '\M') and plan !~ 'Seq Scan on',
    label || ' does not use ' || index_name || ':' || E'\n' || plan;
end
$function$;

do $test$
declare
  tenant constant text := '19000000-0000-4000-8000-000000000001';
  a_donation uuid;
  a_receipt text;
  a_donor uuid;
begin
  assert (select count(*) from app.donations where institute_id = tenant::uuid) = 5000,
    'Seeded volume is not 5,000 donations';
  select id, receipt_number, donor_id into strict a_donation, a_receipt, a_donor
  from app.donations where institute_id = tenant::uuid order by recorded_at limit 1;

  -- Reads inside definer functions run as the owner; their SQL is checked here.
  perform pg_temp.assert_indexed('Recent donations list (identity.list_manual_donations)',
    'donations_institute_id_recorded_at_id_index', format($q$
    select d.id from app.donations d
    where d.institute_id = %L and d.status = 'recorded'
    order by d.recorded_at desc, d.id desc limit 50 $q$, tenant));
  perform pg_temp.assert_indexed('Receipt lookup (identity.issue_trail_link)',
    'donations_institute_id_receipt_number_unique', format($q$
    select d.id from app.donations d where d.institute_id = %L and upper(d.receipt_number) = upper(%L)
      and d.receipt_number = %L $q$, tenant, a_receipt, a_receipt));
  perform pg_temp.assert_indexed('Guest trail page (identity.read_guest_trail)',
    'donations_guest_trail_index', format($q$
    select d.id, e.id from app.trail_links link
    join app.donations d on (d.institute_id, d.donor_id) = (link.institute_id, link.donor_id)
    left join app.trail_events e on e.institute_id = d.institute_id and e.donation_id = d.id
    where link.institute_id = %L and link.revoked_at is null and link.token_hash = %L
    order by d.recorded_at desc, d.id desc limit 21 $q$, tenant, repeat('7', 64)));
  perform pg_temp.assert_indexed('Trail link by token (identity.read_guest_trail)',
    'trail_links_token_hash_unique', format($q$
    select link.id from app.trail_links link
    where link.institute_id = %L and link.revoked_at is null and link.token_hash = %L $q$,
    tenant, repeat('7', 64)));
  perform pg_temp.assert_indexed('Donor history', 'donations_guest_trail_index', format($q$
    select d.id from app.donations d where d.institute_id = %L and d.donor_id = %L
    order by d.recorded_at desc, d.id desc limit 20 $q$, tenant, a_donor));
  perform pg_temp.assert_indexed('Allocations of one donation (reversals)', 'allocations_donation', format($q$
    select a.id from app.allocations a where a.institute_id = %L and a.donation_id = %L $q$,
    tenant, a_donation));
  perform pg_temp.assert_indexed('Trail events of one donation', 'trail_events_donation_index', format($q$
    select e.id from app.trail_events e where e.institute_id = %L and e.donation_id = %L $q$,
    tenant, a_donation));
  perform pg_temp.assert_indexed('Guest donor lookup by email', 'donors_institute_id_email_unique', format($q$
    select o.id from app.donors o where o.institute_id = %L and o.email = 'plan-donor-7@example.test' $q$,
    tenant));
  perform pg_temp.assert_indexed('Donations of one cause', 'donations_cause', format($q$
    select d.id from app.donations d
    where d.institute_id = %L and d.cause_id = '19000000-0000-4000-8000-000000000102' $q$, tenant));
end
$test$;

-- The runtime roles read donations only through definer functions. What they
-- query directly under row-level security is the auth data, on every request.
-- These tables are small here, so sequential scans are switched off: if a
-- plan still scans, the policy predicate stops the index from being used.
set local role tazkiyah_auth;
select set_config('app.institute_id', '19000000-0000-4000-8000-000000000001', true);
set local enable_seqscan = off;
do $test$
declare
  check_query record;
begin
  for check_query in select * from (values
    ('Session by token', 'sessions_institute_id_token_unique',
      $q$ select id from identity.sessions where token = 'plan-session-1' $q$),
    ('Sessions of a user', 'sessions_institute_id_user_id_index', $q$ select id from identity.sessions
      where user_id = '19000000-0000-4000-8000-000000000011' $q$),
    ('User by email (Better Auth)', 'users_email_lookup',
      $q$ select id from app.users where email = 'plan-admin-1@example.test' $q$),
    ('User by username (Better Auth)', 'users_username_lookup',
      $q$ select id from app.users where username = 'maa-2026-0001' $q$),
    ('Credential of a user', 'accounts_institute_id_user_id_index', $q$ select id from identity.accounts
      where user_id = '19000000-0000-4000-8000-000000000011' $q$),
    ('Verification token', 'verification_institute_id_identifier_index',
      $q$ select id from identity.verification where identifier = 'plan' $q$)
  ) as queries(label, index_name, query)
  loop
    perform pg_temp.assert_indexed(check_query.label || ' under RLS', check_query.index_name,
      check_query.query);
  end loop;
end
$test$;
reset enable_seqscan;

reset role;
set local role tazkiyah_app;
select set_config('app.institute_id', '19000000-0000-4000-8000-000000000001', true);
do $test$
declare
  plan text := pg_temp.plan_of($q$
    select raised_paisa from public_api.causes where slug = 'plan-cause-2' $q$);
begin
  -- One cause's totals read that cause's allocations through the index.
  assert plan ~ 'allocations_institute_id_cause_id_donation_id_index'
    and plan !~ 'Seq Scan on (allocations|donations)',
    'Public cause totals scan every allocation:' || E'\n' || plan;
end
$test$;

-- The hub: 20 classes with a teacher and 10 students each, every student with
-- a persona, 1,500 class threads, 500 madrasa threads and 20,000 posts, all in
-- the first institute (04 §13.1).
reset role;
set local role tazkiyah_schema_owner;
insert into app.users (id, institute_id, username, email, full_name, status)
select ('19000000-0000-4000-8001-' || lpad(n::text, 12, '0'))::uuid, '19000000-0000-4000-8000-000000000001',
  case when n <= 200 then 'hubplan-' || n end, case when n > 200 then 'hubplan-' || n || '@example.test' end,
  case when n <= 200 then 'Plan student' else 'Plan teacher' end, 'active'
from generate_series(1, 220) n;
insert into app.user_roles (institute_id, user_id, role)
select institute_id, id, case full_name when 'Plan student' then 'student' else 'teacher' end
from app.users where full_name in ('Plan student', 'Plan teacher');
insert into app.classes (id, institute_id, name, created_by)
select ('19000000-0000-4000-8002-' || lpad(c::text, 12, '0'))::uuid, '19000000-0000-4000-8000-000000000001',
  jsonb_build_object('en', 'Class ' || c), ('19000000-0000-4000-8001-' || lpad((200 + c)::text, 12, '0'))::uuid
from generate_series(1, 20) c;
-- Student n is in class ((n - 1) % 20) + 1; teacher 200 + c teaches class c.
insert into app.class_members (institute_id, class_id, user_id, member_role)
select '19000000-0000-4000-8000-000000000001',
  ('19000000-0000-4000-8002-' || lpad((((n - 1) % 20) + 1)::text, 12, '0'))::uuid,
  ('19000000-0000-4000-8001-' || lpad(n::text, 12, '0'))::uuid, 'student'
from generate_series(1, 200) n
on conflict do nothing;
insert into app.class_members (institute_id, class_id, user_id, member_role)
select '19000000-0000-4000-8000-000000000001', ('19000000-0000-4000-8002-' || lpad(c::text, 12, '0'))::uuid,
  ('19000000-0000-4000-8001-' || lpad((200 + c)::text, 12, '0'))::uuid, 'teacher'
from generate_series(1, 20) c
on conflict do nothing;
insert into app.personas (id, institute_id, display_name)
select ('19000000-0000-4000-8003-' || lpad(n::text, 12, '0'))::uuid, '19000000-0000-4000-8000-000000000001',
  'Plan ' || n
from generate_series(1, 200) n;
insert into app.persona_links (institute_id, persona_id, user_id, created_by)
select '19000000-0000-4000-8000-000000000001', ('19000000-0000-4000-8003-' || lpad(n::text, 12, '0'))::uuid,
  ('19000000-0000-4000-8001-' || lpad(n::text, 12, '0'))::uuid,
  ('19000000-0000-4000-8001-' || lpad((200 + ((n - 1) % 20) + 1)::text, 12, '0'))::uuid
from generate_series(1, 200) n;
-- Thread k (1 to 1,500) is in class (k % 20) + 1, started by one of its
-- students; threads 1,501 to 2,000 are madrasa threads started by a teacher.
insert into app.threads (id, institute_id, class_id, scope, title, language, author_persona_id, author_user_id)
select ('19000000-0000-4000-8004-' || lpad(k::text, 12, '0'))::uuid, '19000000-0000-4000-8000-000000000001',
  case when k <= 1500 then ('19000000-0000-4000-8002-' || lpad((k % 20 + 1)::text, 12, '0'))::uuid end,
  case when k <= 1500 then 'class' else 'madrasa' end, 'Thread ' || k, 'ur',
  case when k <= 1500 then ('19000000-0000-4000-8003-'
    || lpad((20 * ((k / 20) % 10) + k % 20 + 1)::text, 12, '0'))::uuid end,
  case when k > 1500 then ('19000000-0000-4000-8001-' || lpad((201 + k % 20)::text, 12, '0'))::uuid end
from generate_series(1, 2000) k;
-- Ten posts in each thread, by students of the class or by the teacher.
insert into app.posts (institute_id, thread_id, post_type, language, body, author_persona_id, author_user_id)
select '19000000-0000-4000-8000-000000000001', ('19000000-0000-4000-8004-' || lpad(k::text, 12, '0'))::uuid,
  case when j = 0 then 'question' else 'message' end, 'ur', 'Post ' || j || ' in thread ' || k,
  case when k <= 1500 then ('19000000-0000-4000-8003-'
    || lpad((20 * ((k / 20 + j) % 10) + k % 20 + 1)::text, 12, '0'))::uuid end,
  case when k > 1500 then ('19000000-0000-4000-8001-' || lpad((201 + k % 20)::text, 12, '0'))::uuid end
from generate_series(1, 2000) k cross join generate_series(0, 9) j
order by k, j;

reset role;
analyze app.posts, app.threads, app.class_members, app.personas, app.persona_links, app.classes,
  app.users, app.user_roles;

do $test$
begin
  assert (select count(*) from app.posts where institute_id = '19000000-0000-4000-8000-000000000001') = 20000,
    'Seeded volume is not 20,000 posts';
end
$test$;

-- The lookups inside the policy helpers run as their owner, once per row
-- checked. Memberships and persona links stay small, so sequential scans are
-- switched off to show the index serves them.
set local enable_seqscan = off;
do $test$
declare
  tenant constant text := '19000000-0000-4000-8000-000000000001';
begin
  perform pg_temp.assert_indexed('Class membership (app.is_class_member)',
    'class_members_(one_open|class_role|user)', format($q$
    select from app.class_members m where m.institute_id = %L
      and m.class_id = '19000000-0000-4000-8002-000000000001'
      and m.user_id = '19000000-0000-4000-8001-000000000001' and m.ended_at is null $q$, tenant));
  perform pg_temp.assert_indexed('Teachers of a student (app.is_teacher_of)',
    'class_members_(one_open|class_role|user)', format($q$
    select from app.class_members t
    join app.class_members s on s.institute_id = t.institute_id and s.class_id = t.class_id
    where t.institute_id = %L and t.user_id = '19000000-0000-4000-8001-000000000201'
      and t.member_role = 'teacher' and t.ended_at is null
      and s.user_id = '19000000-0000-4000-8001-000000000001' and s.member_role = 'student' $q$, tenant));
  perform pg_temp.assert_indexed('Own persona (app.current_persona_id)', 'persona_links_user', format($q$
    select l.persona_id from app.persona_links l
    where l.institute_id = %L and l.user_id = '19000000-0000-4000-8001-000000000001' $q$, tenant));
end
$test$;
reset enable_seqscan;

-- What a student and a teacher read on every hub page, under row-level
-- security. The role checks must run once per statement (an InitPlan), and
-- the per-row class checks only on the rows the index returns.
create function pg_temp.assert_hub_reads() returns void
language plpgsql as $function$
declare
  check_query record;
begin
  for check_query in select * from (values
    ('Posts of one thread', 'posts_thread', $q$ select id from app.posts
      where thread_id = '19000000-0000-4000-8004-000000000001' order by created_at limit 50 $q$),
    ('Threads of one class', 'threads_class_recent', $q$ select id from app.threads
      where class_id = '19000000-0000-4000-8002-000000000002' order by last_post_at desc limit 20 $q$),
    ('Madrasa threads', 'threads_scope_recent', $q$ select id from app.threads
      where scope = 'madrasa' order by last_post_at desc limit 20 $q$),
    ('Posts of one persona', 'posts_author_persona', $q$ select id from app.posts
      where author_persona_id = '19000000-0000-4000-8003-000000000001' $q$),
    ('Replies to one post', 'posts_parent', $q$ select id from app.posts
      where parent_post_id = '19000000-0000-4000-8004-000000000001' $q$),
    ('Approval queue', 'posts_approval_queue', $q$ select id from app.posts
      where moderation_state = 'submitted' $q$)
  ) as queries(label, index_name, query)
  loop
    perform pg_temp.assert_indexed(check_query.label || ' as ' || current_setting('app.user_id'),
      check_query.index_name, check_query.query);
    assert pg_temp.plan_of(check_query.query) ~ 'InitPlan',
      check_query.label || ' does not run the role checks once per statement';
  end loop;
end
$function$;

set local role tazkiyah_app;
select set_config('app.institute_id', '19000000-0000-4000-8000-000000000001', true);
-- A student of class 2 and the teacher of class 2.
select set_config('app.user_id', '19000000-0000-4000-8001-000000000002', true);
select pg_temp.assert_hub_reads();
select set_config('app.user_id', '19000000-0000-4000-8001-000000000202', true);
select pg_temp.assert_hub_reads();

rollback;
