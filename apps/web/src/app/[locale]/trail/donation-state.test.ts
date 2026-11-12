import { describe, expect, it } from "vitest";
import { donationState, type StateEvent } from "./donation-state";

const received = (amount: string): StateEvent<string> => ({
  event_type: "received",
  amount_paisa: amount,
});
const allocated = (amount: string, cause: string): StateEvent<string> => ({
  event_type: "allocated",
  amount_paisa: amount,
  cause_title: cause,
});
const spent = (amount: string): StateEvent<string> => ({
  event_type: "spent",
  amount_paisa: amount,
});
const reported = (amount: string): StateEvent<string> => ({
  event_type: "reported",
  amount_paisa: amount,
});

function state(events: StateEvent<string>[], amount = "4000000") {
  return donationState({ amount_paisa: amount, status: "recorded", events });
}

// The rows of 06 §4.4 after confirmation.
describe("donationState", () => {
  it("waits for a split while no money is assigned", () => {
    expect(state([received("4000000")])).toEqual({ kind: "awaiting_split" });
  });

  it("shows the assigned and waiting parts of a partly split gift", () => {
    expect(
      state([received("4000000"), allocated("2500000", "Wheat stock")]),
    ).toEqual({
      kind: "partly_allocated",
      assigned: 2500000n,
      waiting: 1500000n,
      causes: ["Wheat stock"],
    });
  });

  it("names every cause once all the money is assigned", () => {
    expect(
      state([
        received("4000000"),
        allocated("2500000", "Wheat stock"),
        allocated("1500000", "Kitchen gas"),
      ]),
    ).toEqual({ kind: "allocated", causes: ["Wheat stock", "Kitchen gas"] });
  });

  it("shows the earliest stage when money sits at several", () => {
    // Split in part and partly spent: still partly allocated (06 §4.4).
    expect(
      state([
        received("4000000"),
        allocated("2500000", "Wheat stock"),
        spent("500000"),
      ]).kind,
    ).toBe("partly_allocated");
  });

  it("counts spending once all the money is assigned", () => {
    const events = [received("2500000"), allocated("2500000", "Wheat stock")];
    expect(state([...events, spent("500000")], "2500000")).toEqual({
      kind: "partly_spent",
      spent: 500000n,
      total: 2500000n,
    });
    expect(state([...events, spent("2500000")], "2500000")).toEqual({
      kind: "spent",
    });
    expect(
      state(
        [...events, spent("1000000"), spent("1500000"), reported("2500000")],
        "2500000",
      ),
    ).toEqual({ kind: "reported" });
  });

  it("gives the reason category of a reversal, and nothing unknown", () => {
    expect(
      donationState({
        amount_paisa: "100",
        status: "reversed",
        reversal_reason: "recorded_twice",
        events: [],
      }),
    ).toEqual({ kind: "reversed", reason: "recorded_twice" });
    expect(
      donationState({
        amount_paisa: "100",
        status: "reversed",
        reversal_reason: "a staff note",
        events: [],
      }),
    ).toEqual({ kind: "reversed", reason: null });
  });
});
