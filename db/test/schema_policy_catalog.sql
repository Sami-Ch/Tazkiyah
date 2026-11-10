set plpgsql.check_asserts = on;

do $test$
declare
  table_info record;
  view_info record;
  isolation_roles oid[];
begin
  assert exists (
    select 1 from pg_catalog.pg_roles
    where rolname = 'tazkiyah_app' and not rolsuper and not rolbypassrls
      and not rolcreaterole and not rolcreatedb and not rolreplication
  ), 'Runtime role has elevated attributes';
  assert not pg_has_role('tazkiyah_app', 'tazkiyah_schema_owner', 'member'),
    'Runtime role can assume the schema owner';

  for table_info in
    select c.oid, c.relname, c.relowner, c.relrowsecurity, a.attnum as tenant_column
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    left join pg_catalog.pg_attribute a on a.attrelid = c.oid and a.attnotnull
      and a.attname = case when c.relname = 'institutes' then 'id' else 'institute_id' end
    where n.nspname = 'app' and c.relkind in ('r', 'p')
  loop
    isolation_roles := array['tazkiyah_app'::regrole::oid];
    if table_info.relname in ('allocations', 'donations', 'donors', 'receipt_counters', 'recurring_pledges', 'trail_events', 'trail_links', 'receipt_email_jobs') then
      isolation_roles := array_append(isolation_roles, 'tazkiyah_auth'::regrole::oid);
    end if;
    assert table_info.tenant_column is not null, 'Missing tenant key on ' || table_info.relname;
    assert table_info.relowner = 'tazkiyah_schema_owner'::regrole, 'Incorrect owner on ' || table_info.relname;
    assert table_info.relrowsecurity, 'RLS disabled on ' || table_info.relname;
    assert exists (
      select 1 from pg_catalog.pg_policy p
      where p.polrelid = table_info.oid and p.polname = 'iso' and not p.polpermissive
        and p.polcmd = '*' and p.polroles @> isolation_roles and p.polroles <@ isolation_roles
        and p.polqual is not null and p.polwithcheck is not null
    ), 'Missing restrictive isolation policy on ' || table_info.relname;
    assert not has_table_privilege('tazkiyah_app', table_info.oid, 'TRUNCATE, TRIGGER'),
      'Runtime role has whole-table privileges on ' || table_info.relname;
    assert exists (
      select 1 from pg_catalog.pg_constraint c
      where c.conrelid = table_info.oid and c.contype in ('p', 'u')
        and c.conkey[1] = table_info.tenant_column
        and (table_info.relname in ('institutes', 'institute_settings', 'user_roles', 'receipt_counters') or exists (
          select 1 from pg_catalog.pg_attribute a
          where a.attrelid = c.conrelid and a.attnum = c.conkey[2] and a.attname = 'id'
        ))
    ), 'Missing tenant-qualified unique key on ' || table_info.relname;
    assert not exists (
      select 1 from pg_catalog.pg_constraint c
      join pg_catalog.pg_class target on target.oid = c.confrelid
      join pg_catalog.pg_namespace ns on ns.oid = target.relnamespace
      where c.conrelid = table_info.oid and c.contype = 'f'
        and ns.nspname = 'app' and target.relname <> 'institutes'
        -- 04 §9.5: a platform-fund allocation belongs to the fund institute.
        and c.conname <> 'donations_source_allocation_id_allocations_id_fk'
        and not exists (
          select 1 from pg_catalog.pg_attribute a
          where a.attrelid = target.oid and a.attname = 'institute_id'
            and c.conkey[1] = table_info.tenant_column and c.confkey[1] = a.attnum
        )
    ), 'Cross-table foreign key lacks tenant key on ' || table_info.relname;
  end loop;

  for view_info in
    select c.oid, c.relname, c.relowner, c.reloptions
    from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public_api' and c.relkind = 'v'
  loop
    assert view_info.relowner = 'tazkiyah_schema_owner'::regrole
      and view_info.reloptions @> array['security_barrier=true'],
      'Public view lacks its security barrier on ' || view_info.relname;
    assert pg_get_viewdef(view_info.oid) ~ '(app[.]current_institute_id[(]|public_api[.]institute_public)',
      'Public view lacks its tenant scope on ' || view_info.relname;
  end loop;
end
$test$;

-- 04 §13.1: every composite foreign key has an index whose leading columns are
-- the key's columns (P0-E2-T19).
do $test$
declare
  missing text;
begin
  select string_agg(c.conrelid::regclass || ' ' || c.conname, ', ') into missing
  from pg_catalog.pg_constraint c
  join pg_catalog.pg_namespace n on n.oid = c.connamespace
  where c.contype = 'f' and cardinality(c.conkey) > 1
    and n.nspname in ('app', 'identity', 'mail')
    and not exists (
      select 1 from pg_catalog.pg_index i
      where i.indrelid = c.conrelid
        -- A partial index on "column is not null" still serves the key.
        and (i.indpred is null or pg_get_expr(i.indpred, i.indrelid) = format('(%I IS NOT NULL)',
          (select a.attname from pg_catalog.pg_attribute a
           where a.attrelid = c.conrelid and a.attnum = c.conkey[cardinality(c.conkey)])))
        and (i.indkey::int2[])[0:cardinality(c.conkey) - 1] @> c.conkey
        and (i.indkey::int2[])[0:cardinality(c.conkey) - 1] <@ c.conkey
    );
  assert missing is null, 'Foreign keys without a leading index: ' || missing;
end
$test$;
