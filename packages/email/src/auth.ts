import type { EmailContent } from "./email-sender";

type AuthLocale = "en" | "ur";

export type AuthEmail = {
  kind: "verify-email" | "reset-password";
  locale: AuthLocale;
  instituteName: string;
  url: string;
  origin: string;
};

// Auth emails greet nobody by name and carry only the one-hour link (03 §10.4).
const copy = {
  en: {
    "verify-email": {
      subject: "Confirm your email address",
      body: (name: string) =>
        `A donor account was created at ${name} with this email address. Open the link below to confirm it.`,
      action: "Confirm my email address",
    },
    "reset-password": {
      subject: "Reset your password",
      body: (name: string) =>
        `We received a request to reset the password of your account at ${name}. Open the link below to choose a new password. This signs you out on every device.`,
      action: "Choose a new password",
    },
    expiry: "The link works for one hour.",
    ignore: "If this was not you, you can ignore this email.",
  },
  ur: {
    "verify-email": {
      subject: "اپنا ای میل پتہ تصدیق کریں",
      body: (name: string) =>
        `${name} پر اس ای میل پتے سے عطیہ دہندہ کا اکاؤنٹ بنایا گیا ہے۔ تصدیق کے لیے نیچے دیا گیا لنک کھولیں۔`,
      action: "میرا ای میل پتہ تصدیق کریں",
    },
    "reset-password": {
      subject: "اپنا پاس ورڈ دوبارہ ترتیب دیں",
      body: (name: string) =>
        `${name} پر آپ کے اکاؤنٹ کا پاس ورڈ بدلنے کی درخواست موصول ہوئی ہے۔ نیا پاس ورڈ چننے کے لیے نیچے دیا گیا لنک کھولیں۔ اس سے آپ ہر ڈیوائس سے سائن آؤٹ ہو جائیں گے۔`,
      action: "نیا پاس ورڈ چنیں",
    },
    expiry: "یہ لنک ایک گھنٹے تک کام کرے گا۔",
    ignore: "اگر یہ آپ نے نہیں کیا تو اس ای میل کو نظر انداز کر دیں۔",
  },
} as const;

const entities: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (character) => entities[character]);
}

function trustedAuthLink(url: string, origin: string) {
  try {
    const base = new URL(origin);
    const link = new URL(url);
    const local =
      base.protocol === "http:" &&
      ["localhost", "127.0.0.1", "[::1]"].includes(base.hostname);
    if (
      (base.protocol === "https:" || local) &&
      base.href === `${base.origin}/` &&
      link.origin === base.origin &&
      !link.username &&
      !link.password &&
      /^\/api\/auth\/(verify-email|reset-password\/[A-Za-z0-9_-]+)$/.test(
        link.pathname,
      )
    )
      return link.href;
  } catch {
    return undefined;
  }
}

export function renderAuthEmail(email: AuthEmail): EmailContent {
  const { kind, locale } = email;
  const instituteName = email.instituteName
    .replace(/[\u0000-\u001f\u007f]+/g, " ")
    .trim();
  const link = trustedAuthLink(email.url, email.origin);
  if (
    (locale !== "en" && locale !== "ur") ||
    (kind !== "verify-email" && kind !== "reset-password") ||
    !instituteName ||
    !link
  )
    throw new Error("invalid_auth_email");

  const labels = copy[locale];
  const message = labels[kind];
  const body = message.body(instituteName);
  const rtl = locale === "ur";
  const direction = rtl ? "rtl" : "ltr";
  const align = rtl ? "right" : "left";
  const font = rtl
    ? "'Noto Naskh Arabic', 'Geeza Pro', Tahoma, serif"
    : "Arial, sans-serif";

  const text = [
    message.subject,
    "",
    body,
    "",
    link,
    "",
    labels.expiry,
    labels.ignore,
  ].join("\n");

  const html = `<!doctype html>
<html lang="${locale}" dir="${direction}">
<head><meta charset="utf-8"><title>${message.subject}</title></head>
<body lang="${locale}" dir="${direction}" style="margin:0;padding:24px;background:#faf8f3;color:#1b2333;font-family:${font};line-height:1.6">
<div lang="${locale}" dir="${direction}" style="max-width:560px;margin:0 auto;padding:24px;border:1px solid #d9d4c7;background:#fff;text-align:${align}">
<h1 style="margin:0 0 12px;color:#0d254d;font-size:24px">${message.subject}</h1>
<p>${escapeHtml(body)}</p>
<p><a href="${escapeHtml(link)}" rel="noreferrer" style="color:#0d254d">${message.action}</a></p>
<p style="color:#4f5868">${labels.expiry} ${labels.ignore}</p>
</div>
</body>
</html>`;

  return { subject: message.subject, text, html };
}
