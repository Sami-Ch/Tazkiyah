SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- The second Zakat ring-fence (04 §9.4, P2-E3-T40). The first, on donations,
-- came with P1-E3-T41. The third (no switching Zakat off while unspent Zakat
-- remains) waits for proposed REQ-TRL-015; until then the cause editor locks
-- the Zakat setting once a cause holds recorded money.
create or replace function app.allocations_rules() returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $function$
declare
  gift app.donations%rowtype;
  source app.allocations%rowtype;
  original app.allocations%rowtype;
begin
  select d.* into gift from app.donations d
  where d.institute_id = new.institute_id and d.id = new.donation_id
  for no key update;
  if not found then
    raise exception 'allocation needs a donation of its institute' using errcode = 'foreign_key_violation';
  end if;
  if new.donation_type <> gift.donation_type then
    raise exception 'allocation type % must equal the donation type %', new.donation_type, gift.donation_type
      using errcode = 'check_violation';
  end if;

  -- Zakat goes only into, and is spent only from, causes that accept it at
  -- that moment (04 §9.4 rule 2, REQ-TRL-006). A reversal only takes money back.
  if new.donation_type = 'zakat' and new.kind in ('to_cause', 'to_spending') and not new.is_reversal
    and not exists (select from app.causes c
      where c.institute_id = new.institute_id and c.id = new.cause_id and c.accepts_zakat)
  then
    raise exception 'Zakat money can only go to a cause that accepts Zakat' using errcode = 'check_violation';
  end if;

  if new.is_reversal then
    select a.* into original from app.allocations a
    where a.institute_id = new.institute_id and a.id = new.reverses_allocation_id;
    if original.is_reversal or original.donation_id <> new.donation_id or original.kind <> new.kind
      or original.amount_paisa <> new.amount_paisa or original.donation_type <> new.donation_type
      or original.cause_id is distinct from new.cause_id
      or original.from_allocation_id is distinct from new.from_allocation_id
      or original.spending_entry_id is distinct from new.spending_entry_id
      or original.target_institute_id is distinct from new.target_institute_id
    then
      raise exception 'a reversal must mirror the allocation it reverses, which must not be a reversal'
        using errcode = 'check_violation';
    end if;
  elsif new.kind = 'to_spending' then
    select a.* into source from app.allocations a
    where a.institute_id = new.institute_id and a.id = new.from_allocation_id
    for no key update;
    if source.kind <> 'to_cause' or source.is_reversal or source.donation_id <> new.donation_id
      or source.cause_id <> new.cause_id
    then
      raise exception 'spending must draw on a cause allocation of the same donation and cause'
        using errcode = 'check_violation';
    end if;
    -- The entry is locked too, so its per-entry cap is checked on a stable ledger.
    if not exists (
      select from app.spending_entries e
      where e.institute_id = new.institute_id and e.id = new.spending_entry_id
        and e.cause_id = new.cause_id and e.status = 'recorded'
      for no key update
    ) then
      raise exception 'spending must match a recorded spending entry of the same cause'
        using errcode = 'check_violation';
    end if;
  elsif new.kind = 'to_institute' then
    -- REQ-TRL-014: the shape exists, but only a platform fund may use it (§9.5).
    if not exists (select from app.institutes i where i.id = new.institute_id and i.kind = 'platform_fund') then
      raise exception 'transfers to an institute are only possible from a platform fund'
        using errcode = 'check_violation';
    end if;
    if new.target_institute_id = new.institute_id or not exists (
      select from app.institutes i where i.id = new.target_institute_id and i.kind = 'institute'
    ) then
      raise exception 'a transfer must go to another institute' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end
$function$;
--> statement-breakpoint
RESET ROLE;
