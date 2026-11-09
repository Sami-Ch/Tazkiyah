import { createHash } from "node:crypto";
import type pg from "pg";
import { expect, it, vi } from "vitest";
import type { EmailSender } from "../../../../packages/email/src/index";
import { runReceiptJobs } from "./receipt-worker";

it("reuses the exact message after an uncertain send and blocks payload changes", async () => {
  const jobId = "e2dd077f-3a82-4e68-8962-9c96b199b029";
  const claimToken = "fe997d1b-ec93-45a2-b927-7ba79f263a67";
  let preparedHash: string | null = null;
  let tokenDigest: string | null = null;
  const finishes: string[] = [];
  const row = {
    outcome: "ready",
    to_email: "guest@example.test",
    receipt_number: "MAA-2026-00001",
    receipt_locale: "en",
    credited_on: "2026-11-08",
    amount_paisa: "1500000",
    institute_name: { en: "Markaz Al Azeem" },
    cause_title: { en: "Wheat stock" },
    domain: "example.test",
    include_trail: true,
  };
  const query = vi.fn(async (statement: string, parameters: unknown[] = []) => {
    if (statement.includes("current_user"))
      return { rows: [{ role: "tazkiyah_mail" }] };
    if (statement.includes("claim_receipt_emails"))
      return { rows: [{ job_id: jobId, claim_token: claimToken }] };
    expect(parameters.slice(0, 2)).toEqual([jobId, claimToken]);
    if (statement.includes("finish_receipt_email")) {
      finishes.push(String(parameters[2]));
      return { rows: [] };
    }
    tokenDigest = String(parameters[2]);
    if (parameters[3]) {
      const candidate = String(parameters[3]);
      if (preparedHash && preparedHash !== candidate)
        return { rows: [{ outcome: "payload_changed" }] };
      preparedHash = candidate;
    }
    return { rows: [row] };
  });
  const db = { query } as unknown as Pick<pg.Client, "query">;
  const send = vi
    .fn<EmailSender["send"]>()
    .mockResolvedValueOnce({
      status: "failed",
      reason: "unconfirmed",
      retryable: true,
    })
    .mockResolvedValueOnce({ status: "accepted", providerId: "fixture-id" });
  const config = { from: "receipts@example.test", linkKey: "6f".repeat(32) };

  await runReceiptJobs(db, config, { send });
  await runReceiptJobs(db, config, { send });
  expect(send).toHaveBeenCalledTimes(2);
  expect(send.mock.calls[0][0]).toEqual(send.mock.calls[1][0]);
  expect(send.mock.calls[0][0].idempotencyKey).toBe(
    `donation-receipt/${jobId}`,
  );
  const link = send.mock.calls[0][0].text.match(
    /\/en\/trail#([A-Za-z0-9_-]{43})/,
  )?.[1];
  expect(link).toBeDefined();
  expect(tokenDigest).toBe(createHash("sha256").update(link!).digest("hex"));
  expect(JSON.stringify(query.mock.calls)).not.toContain(link);
  expect(finishes).toEqual(["network_error", "sent"]);

  await runReceiptJobs(db, { ...config, from: "other@example.test" }, { send });
  expect(send).toHaveBeenCalledTimes(2);
  expect(finishes).toEqual(["network_error", "sent", "payload_changed"]);
});
