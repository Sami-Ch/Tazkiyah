import {
  type EmailFailureReason,
  type EmailSender,
  type EmailSendResult,
  uuidPattern,
} from "./email-sender";

type ResendConfig = {
  apiKey: string;
  from: string;
  replyTo?: string;
  fetch?: typeof fetch;
};

const endpoint = "https://api.resend.com/emails";
const mailbox = /^[^\s<>,;@]+@[^\s<>,;@.]+(?:\.[^\s<>,;@.]+)+$/;
const singleLine = /^[^\u0000-\u001f\u007f]+$/;

function isSender(value: string) {
  const address = /^[^<>]+ <([^<>]+)>$/.exec(value)?.[1] ?? value;
  return singleLine.test(value) && mailbox.test(address);
}

function failure(
  reason: EmailFailureReason,
  retryable: boolean,
  retryAfterSeconds?: number,
): EmailSendResult {
  return {
    status: "failed",
    reason,
    retryable,
    ...(retryAfterSeconds === undefined ? {} : { retryAfterSeconds }),
  };
}

function retryDelay(response: Response) {
  const value = response.headers.get("Retry-After");
  if (!value) return undefined;
  if (/^\d+$/.test(value)) {
    const seconds = Number(value);
    return Number.isSafeInteger(seconds) ? seconds : undefined;
  }
  const date = Date.parse(value);
  return Number.isFinite(date)
    ? Math.max(0, Math.ceil((date - Date.now()) / 1_000))
    : undefined;
}

function failureFor(response: Response, name: unknown): EmailSendResult {
  const delay = retryDelay(response);
  switch (response.status) {
    case 401:
    case 403:
    case 404:
    case 405:
      return failure("configuration", false);
    case 409:
      return name === "concurrent_idempotent_requests" ||
        name === "resource_locked"
        ? failure("temporarily_unavailable", true, delay)
        : failure("idempotency_conflict", false);
    case 429:
      if (name === "monthly_quota_exceeded")
        return failure("quota_exceeded", false);
      if (name === "daily_quota_exceeded") {
        // Resend resets the daily quota at midnight UTC.
        const secondsToReset = Math.ceil(
          (86_400_000 - (Date.now() % 86_400_000)) / 1_000,
        );
        return failure("quota_exceeded", true, delay ?? secondsToReset);
      }
      return failure("rate_limited", true, delay);
    case 503:
      return failure("temporarily_unavailable", true, delay);
    default:
      return response.status >= 500 || response.status === 408
        ? failure("unconfirmed", true, delay)
        : failure("invalid_message", false);
  }
}

export function createResendEmailSender(config: ResendConfig): EmailSender {
  const { apiKey, from, replyTo } = config;
  const configured =
    /^re_[A-Za-z0-9_-]+$/.test(apiKey) &&
    isSender(from) &&
    (replyTo === undefined || (singleLine.test(replyTo) && mailbox.test(replyTo)));
  const transport: typeof fetch =
    config.fetch ?? ((input, init) => globalThis.fetch(input, init));

  return {
    async send({ to, idempotencyKey, subject, text, html }) {
      if (!configured) return failure("configuration", false);
      if (
        !singleLine.test(to) ||
        !mailbox.test(to) ||
        !/^[A-Za-z0-9._:/-]{1,256}$/.test(idempotencyKey) ||
        !subject.trim() ||
        !singleLine.test(subject) ||
        !text.trim() ||
        !html.trim()
      )
        return failure("invalid_message", false);

      try {
        const response = await transport(endpoint, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
            "Idempotency-Key": idempotencyKey,
          },
          body: JSON.stringify({
            from,
            to: [to],
            subject,
            text,
            html,
            ...(replyTo === undefined ? {} : { reply_to: replyTo }),
          }),
          redirect: "error",
          signal: AbortSignal.timeout(10_000),
        });
        const data: { id?: unknown; name?: unknown } | null = await response
          .json()
          .catch(() => null);
        if (!response.ok) return failureFor(response, data?.name);
        return typeof data?.id === "string" && uuidPattern.test(data.id)
          ? { status: "accepted", providerId: data.id }
          : failure("unconfirmed", true);
      } catch {
        // A transport failure cannot distinguish a dropped response from a dropped request.
        return failure("unconfirmed", true);
      }
    },
  };
}
