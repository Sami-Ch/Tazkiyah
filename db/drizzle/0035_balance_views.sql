SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Balances over the money ledger (04 §9.2, §9.7, P2-E2-T42). "Effective"
-- rows are originals that have not been reversed. The views run as their
-- owner, so each one keeps to the session's institute itself, and none is
-- granted to the runtime roles: admin screens read them through definer
-- functions (REQ-TRL-013).
create view app.allocations_effective with (security_barrier = true) as
select a.*
from app.allocations a
where a.institute_id = (select app.current_institute_id())
  and not a.is_reversal
  and not exists (select from app.allocations r
    where r.institute_id = a.institute_id and r.reverses_allocation_id = a.id);
--> statement-breakpoint
-- What is left of each to_cause allocation after its effective spends.
create view app.allocation_balances with (security_barrier = true) as
select a.institute_id, a.id as allocation_id, a.donation_id, a.donation_type, a.cause_id,
  a.amount_paisa, coalesce(spent.total, 0)::bigint as spent_paisa,
  (a.amount_paisa - coalesce(spent.total, 0))::bigint as unspent_paisa
from app.allocations_effective a
left join lateral (
  select sum(o.amount_paisa) as total from app.allocations_effective o
  where o.institute_id = a.institute_id and o.from_allocation_id = a.id
) spent on true
where a.kind = 'to_cause';
--> statement-breakpoint
-- One row per cause and donation type. Raised is all money that entered the
-- cause, by gift or by split (06 §9.4); spent is what recorded entries have
-- matched; unspent is the difference.
create view app.cause_balances with (security_barrier = true) as
select c.institute_id, c.id as cause_id, t.donation_type,
  coalesce(sum(b.amount_paisa), 0)::bigint as raised_paisa,
  coalesce(sum(b.spent_paisa), 0)::bigint as spent_paisa,
  coalesce(sum(b.unspent_paisa), 0)::bigint as unspent_paisa
from app.causes c
cross join (values ('zakat'), ('sadaqah'), ('general')) as t (donation_type)
left join app.allocation_balances b on b.cause_id = c.id and b.donation_type = t.donation_type
where c.institute_id = (select app.current_institute_id())
group by c.institute_id, c.id, t.donation_type;
--> statement-breakpoint
-- The reconciliation query (04 §9.1), run in tests and by the nightly job:
-- every allocation has exactly one trail event of its own kind (allocated for
-- money placed, spent for a match, reversal for a reversal). Each row returned
-- is a problem.
create view app.allocation_event_gaps with (security_barrier = true) as
select a.institute_id, a.id as allocation_id, a.kind, a.is_reversal,
  case when a.is_reversal then 'reversal' when a.kind = 'to_spending' then 'spent' else 'allocated' end
    as expected_event,
  count(e.id) filter (where e.event_type =
    case when a.is_reversal then 'reversal' when a.kind = 'to_spending' then 'spent' else 'allocated' end)
    as matching_events,
  count(e.id) as all_events
from app.allocations a
left join app.trail_events e on e.institute_id = a.institute_id and e.allocation_id = a.id
where a.institute_id = (select app.current_institute_id())
group by a.institute_id, a.id, a.kind, a.is_reversal
having count(e.id) <> 1 or count(e.id) filter (where e.event_type =
    case when a.is_reversal then 'reversal' when a.kind = 'to_spending' then 'spent' else 'allocated' end) <> 1;
--> statement-breakpoint
revoke all on app.allocations_effective, app.allocation_balances, app.cause_balances, app.allocation_event_gaps
from public, tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
