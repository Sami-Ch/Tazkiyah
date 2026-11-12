SET LOCAL ROLE tazkiyah_schema_owner;
--> statement-breakpoint
-- Public money figures per cause (04 §6.5, P1-E1-T40): the cause text and
-- type, target, Zakat flag and scholar name from public_api.causes, plus
-- spent and unspent from the ledger. Built only from allocation sums, so no
-- donor field can appear (REQ-TRL-010). Spent is the effective to_spending
-- total; unspent is everything placed in the cause minus that, and the sum
-- checks keep it from going negative. Shortfalls join here with
-- spending_entries (P2-E1-T40).
create view public_api.cause_summary with (security_barrier = true) as
select c.id, c.slug, c.cause_type, c.title, c.summary, c.status, c.target_paisa, c.target_period,
  c.stock_year_start_month, c.starts_on, c.ends_on, c.accepts_zakat, c.zakat_approved_by,
  c.display_order, c.raised_paisa, c.lifetime_raised_paisa,
  spending.spent_paisa,
  c.lifetime_raised_paisa - spending.spent_paisa as unspent_paisa
from public_api.causes c
cross join lateral (
  select coalesce(sum(case when a.is_reversal then -a.amount_paisa else a.amount_paisa end), 0) as spent_paisa
  from app.allocations a
  where a.institute_id = app.current_institute_id() and a.cause_id = c.id and a.kind = 'to_spending'
) spending;
--> statement-breakpoint
grant select on public_api.cause_summary to tazkiyah_app, tazkiyah_auth;
--> statement-breakpoint
RESET ROLE;
