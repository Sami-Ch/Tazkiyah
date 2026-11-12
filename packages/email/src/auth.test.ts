import { describe, expect, it } from "vitest";
import { renderAuthEmail } from "./auth";
import { createConsoleEmailSender } from "./console";

const origin = "https://azeem-lateef.com";
const verify = `${origin}/api/auth/verify-email?token=abc&callbackURL=%2F`;

describe("auth emails (03 §10.4)", () => {
  it("renders Urdu right to left with a plain-text part holding the link", () => {
    const email = renderAuthEmail({
      kind: "verify-email",
      locale: "ur",
      instituteName: "مرکز العظیم",
      url: verify,
      origin,
    });
    expect(email.html).toContain('lang="ur" dir="rtl"');
    expect(email.text).toContain(verify);
    expect(email.subject).not.toMatch(/@/);
  });

  it("refuses links to another origin or another path", () => {
    for (const url of [
      `https://evil.example/api/auth/verify-email?token=abc`,
      `${origin}/en/admin`,
      `https://user:pass@azeem-lateef.com/api/auth/verify-email`,
    ])
      expect(() =>
        renderAuthEmail({
          kind: "verify-email",
          locale: "en",
          instituteName: "Markaz Al Azeem",
          url,
          origin,
        }),
      ).toThrow("invalid_auth_email");
  });

  it("escapes the institute name in HTML", () => {
    const email = renderAuthEmail({
      kind: "reset-password",
      locale: "en",
      instituteName: "<b>Markaz</b>",
      url: `${origin}/api/auth/reset-password/tok_123`,
      origin,
    });
    expect(email.html).toContain("&lt;b&gt;Markaz&lt;/b&gt;");
  });

  it("prints the message but never the recipient in the console adapter", async () => {
    const lines: string[] = [];
    const sender = createConsoleEmailSender((line) => lines.push(line));
    const result = await sender.send({
      to: "donor@example.test",
      subject: "Subject",
      text: "Body",
      html: "<p>Body</p>",
      idempotencyKey: "k",
    });
    expect(result.status).toBe("accepted");
    expect(lines.join("\n")).not.toContain("donor@example.test");
  });
});
