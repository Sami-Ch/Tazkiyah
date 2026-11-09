export type EmailContent = {
  subject: string;
  text: string;
  html: string;
};

export type EmailMessage = EmailContent & {
  to: string;
  idempotencyKey: string;
};

export type EmailFailureReason =
  | "configuration"
  | "invalid_message"
  | "idempotency_conflict"
  | "rate_limited"
  | "quota_exceeded"
  | "temporarily_unavailable"
  | "unconfirmed";

export type EmailSendResult =
  | { status: "accepted"; providerId: string }
  | {
      status: "failed";
      reason: EmailFailureReason;
      retryable: boolean;
      retryAfterSeconds?: number;
    };

export interface EmailSender {
  send(message: EmailMessage): Promise<EmailSendResult>;
}

export const uuidPattern =
  /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;

export function receiptEmailIdempotencyKey(jobId: string) {
  if (!uuidPattern.test(jobId)) throw new Error("invalid_receipt_email_job");
  return `donation-receipt/${jobId.toLowerCase()}`;
}
