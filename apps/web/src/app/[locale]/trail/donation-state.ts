// A donation's state in donor words (06 §4.4), worked out from its trail.
// Events are the ones still standing: reversed events and the reversal
// events themselves are left out by the server. Money can sit at several
// stages at once, so the state is the earliest stage any of it is still at.

import {
  reversalCategories,
  type ReversalCategory,
} from "@/institutes/manual-donations";

export type StateEvent<Cause> = {
  event_type: "received" | "allocated" | "spent" | "reported";
  amount_paisa: string;
  cause_title?: Cause | null;
};

export type DonationState<Cause> =
  | { kind: "awaiting_split" }
  | {
      kind: "partly_allocated";
      assigned: bigint;
      waiting: bigint;
      causes: Cause[];
    }
  | { kind: "allocated"; causes: Cause[] }
  | { kind: "partly_spent"; spent: bigint; total: bigint }
  | { kind: "spent" }
  | { kind: "reported" }
  | { kind: "reversed"; reason: ReversalCategory | null };

function total<Cause>(events: StateEvent<Cause>[], type: string) {
  return events
    .filter(({ event_type }) => event_type === type)
    .reduce((sum, { amount_paisa }) => sum + BigInt(amount_paisa), 0n);
}

export function donationState<Cause>(donation: {
  amount_paisa: string;
  status: "recorded" | "reversed";
  reversal_reason?: string | null;
  events: StateEvent<Cause>[];
}): DonationState<Cause> {
  if (donation.status === "reversed") {
    const reason = reversalCategories.find(
      (category) => category === donation.reversal_reason,
    );
    return { kind: "reversed", reason: reason ?? null };
  }

  const amount = BigInt(donation.amount_paisa);
  const assigned = total(donation.events, "allocated");
  const spent = total(donation.events, "spent");
  const reported = total(donation.events, "reported");
  const causes = donation.events
    .filter(({ event_type }) => event_type === "allocated")
    .map(({ cause_title }) => cause_title)
    .filter((title): title is Cause => title != null);

  if (assigned <= 0n) return { kind: "awaiting_split" };
  if (assigned < amount)
    return {
      kind: "partly_allocated",
      assigned,
      waiting: amount - assigned,
      causes,
    };
  if (spent <= 0n) return { kind: "allocated", causes };
  if (spent < amount) return { kind: "partly_spent", spent, total: amount };
  return reported >= amount ? { kind: "reported" } : { kind: "spent" };
}
