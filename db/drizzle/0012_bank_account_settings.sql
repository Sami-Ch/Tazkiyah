SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
create function identity.read_bank_accounts(session_id uuid) returns table (
  id uuid, label jsonb, bank_name text, account_title text,
  account_number text, iban text, branch text, for_donation_types text[],
  is_active boolean, show_on_donate boolean
)
language sql stable security definer
set search_path = pg_catalog, pg_temp
as $function$
  select b.id, b.label::jsonb, b.bank_name, b.account_title,
    b.account_number, b.iban, b.branch, b.for_donation_types, b.is_active, b.show_on_donate
  from app.institute_bank_accounts b
  where identity.is_staff_admin_session(session_id)
    and b.institute_id = app.current_institute_id()
  order by b.is_active desc, b.display_order, b.id
$function$;
--> statement-breakpoint
create function identity.create_bank_account(
  session_id uuid, account_label jsonb, bank text, holder text,
  account_no text, account_iban text, bank_branch text, donation_types text[]
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  normalized_bank text := btrim(bank);
  normalized_holder text := btrim(holder);
  normalized_no text := nullif(btrim(account_no), '');
  normalized_iban text := nullif(upper(replace(btrim(account_iban), ' ', '')), '');
  normalized_branch text := nullif(btrim(bank_branch), '');
  en text := btrim(account_label ->> 'en');
  ur text := btrim(account_label ->> 'ur');
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  if jsonb_typeof(account_label -> 'en') is distinct from 'string'
    or jsonb_typeof(account_label -> 'ur') is distinct from 'string'
    or length(en) not between 1 and 90 or length(ur) not between 1 and 90
    or coalesce(length(normalized_bank), 0) not between 1 and 120
    or coalesce(length(normalized_holder), 0) not between 1 and 120
    or length(normalized_branch) > 120
    or concat(en, ur, normalized_bank, normalized_holder, normalized_branch) ~ '[[:cntrl:]]'
    or (normalized_no is null and normalized_iban is null)
    or (normalized_no is not null and normalized_no !~ '^[a-zA-Z0-9][a-zA-Z0-9 -]{2,39}$')
    or (normalized_iban is not null and normalized_iban !~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$')
    or donation_types is null or cardinality(donation_types) not between 1 and 3
    or array_position(donation_types, null) is not null
    or not donation_types <@ array['general', 'sadaqah', 'zakat']
  then return 'invalid'; end if;

  perform pg_advisory_xact_lock(hashtextextended(tenant::text || ':bank-settings', 0));
  if exists (
    select from app.institute_bank_accounts b
    where b.institute_id = tenant and (
      upper(replace(btrim(b.iban), ' ', '')) = normalized_iban
      or (lower(btrim(b.bank_name)) = lower(normalized_bank)
        and upper(translate(btrim(b.account_number), ' -', '')) =
          upper(translate(normalized_no, ' -', '')))
    )
  ) then return 'duplicate'; end if;

  insert into app.institute_bank_accounts (
    institute_id, label, bank_name, account_title, account_number, iban, branch,
    for_donation_types, is_active, show_on_donate
  ) values (
    tenant, jsonb_build_object('en', en, 'ur', ur), normalized_bank, normalized_holder,
    normalized_no, normalized_iban, normalized_branch,
    array(select distinct kind from unnest(donation_types) kind order by kind), true, false
  );
  return 'created';
end
$function$;
--> statement-breakpoint
create function identity.set_bank_account_publication(
  session_id uuid, account_id uuid, publish boolean, confirmed boolean
) returns text
language plpgsql security definer
set search_path = pg_catalog, pg_temp
as $function$
declare
  tenant uuid := app.current_institute_id();
  account app.institute_bank_accounts%rowtype;
begin
  if not identity.is_staff_admin_session(session_id) then return 'denied'; end if;
  if publish is null or (publish and confirmed is distinct from true)
  then return 'invalid'; end if;

  select b.* into account from app.institute_bank_accounts b
  where b.institute_id = tenant and b.id = account_id
  for update;
  if not found then return 'denied'; end if;
  if publish and not account.is_active then return 'inactive'; end if;

  update app.institute_bank_accounts b set show_on_donate = publish
  where b.institute_id = tenant and b.id = account_id and b.show_on_donate <> publish;
  return 'updated';
end
$function$;
--> statement-breakpoint
revoke all on function identity.read_bank_accounts(uuid),
  identity.create_bank_account(uuid, jsonb, text, text, text, text, text, text[]),
  identity.set_bank_account_publication(uuid, uuid, boolean, boolean) from public;
--> statement-breakpoint
grant execute on function identity.read_bank_accounts(uuid),
  identity.create_bank_account(uuid, jsonb, text, text, text, text, text, text[]),
  identity.set_bank_account_publication(uuid, uuid, boolean, boolean) to tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
