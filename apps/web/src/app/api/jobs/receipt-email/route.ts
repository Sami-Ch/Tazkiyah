import { timingSafeEqual } from "node:crypto";
import { runConfiguredReceiptJobs } from "@/jobs/receipt-worker";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 180;

export async function GET(request: Request) {
  const headers = { "Cache-Control": "private, no-store" };
  const secret = process.env.CRON_SECRET;
  const auth = request.headers.get("authorization");
  if (!secret || !auth?.startsWith("Bearer ")) {
    return new Response(null, { status: 401, headers });
  }
  const presented = Buffer.from(auth.slice(7));
  const expected = Buffer.from(secret);
  if (
    presented.length !== expected.length ||
    !timingSafeEqual(presented, expected)
  ) {
    return new Response(null, { status: 401, headers });
  }

  try {
    await runConfiguredReceiptJobs({
      RECEIPT_JOBS_DATABASE_URL: process.env.RECEIPT_JOBS_DATABASE_URL,
      RECEIPT_EMAIL_LINK_KEY: process.env.RECEIPT_EMAIL_LINK_KEY,
      RECEIPT_EMAIL_FROM: process.env.RECEIPT_EMAIL_FROM,
      RECEIPT_EMAIL_REPLY_TO: process.env.RECEIPT_EMAIL_REPLY_TO,
      RESEND_API_KEY: process.env.RESEND_API_KEY,
    });
    return new Response(null, { status: 204, headers });
  } catch {
    return new Response(null, { status: 503, headers });
  }
}
