import type { EmailSender } from "./email-sender";

// Local development only, until the sending service of Q-06 has an adapter
// (P1-E3-T30). It prints the subject and plain-text body, which holds the
// link, and never the recipient's address.
export function createConsoleEmailSender(
  write: (line: string) => void = (line) => console.info(line),
): EmailSender {
  let sent = 0;
  return {
    async send(message) {
      sent += 1;
      write(`[email ${sent}] ${message.subject}\n${message.text}`);
      return { status: "accepted", providerId: `console-${sent}` };
    },
  };
}
