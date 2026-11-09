import type { EmailContent } from "./email-sender";

type ReceiptLocale = "en" | "ur";

export type ReceiptEmail = {
  locale: ReceiptLocale;
  instituteName: string;
  receiptNumber: string;
  creditedOn: string;
  amountPaisa: string;
  causeTitle?: string | null;
  trailLink?: { url: string; origin: string };
};

const copy = {
  en: {
    subject: "Your donation receipt",
    title: "Donation receipt",
    thanks: (name: string) => `Thank you for your donation to ${name}.`,
    number: "Receipt number",
    amount: "Amount",
    date: "Transfer date",
    cause: "Giving cause",
    allNeeds: "All needs",
    trail: "Open your private donation trail",
    privacy: "Please keep your private link to yourself.",
    notice: "This donation receipt cannot be used to claim a tax deduction.",
  },
  ur: {
    subject: "آپ کے عطیے کی رسید",
    title: "عطیے کی رسید",
    thanks: (name: string) => `${name} کو عطیہ دینے کا شکریہ۔`,
    number: "رسید نمبر",
    amount: "رقم",
    date: "منتقلی کی تاریخ",
    cause: "عطیے کی مد",
    allNeeds: "تمام ضروریات",
    trail: "اپنے عطیات کا نجی ریکارڈ کھولیں",
    privacy: "اپنا نجی لنک کسی کے ساتھ شیئر نہ کریں۔",
    notice: "اس رسید کی بنیاد پر ٹیکس میں کٹوتی کا دعویٰ نہیں کیا جا سکتا۔",
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

function textLine(value: string) {
  return value.replace(/[\u0000-\u001f\u007f]+/g, " ").trim();
}

function trustedTrailLink(link: ReceiptEmail["trailLink"], locale: ReceiptLocale) {
  if (!link) return undefined;
  try {
    const origin = new URL(link.origin);
    const url = new URL(link.url);
    if (
      origin.protocol === "https:" &&
      origin.href === `${origin.origin}/` &&
      url.origin === origin.origin &&
      url.protocol === "https:" &&
      !url.username &&
      !url.password &&
      url.href === `${origin.origin}/${locale}/trail${url.hash}` &&
      /^#[A-Za-z0-9_-]{43}$/.test(url.hash)
    )
      return url.href;
  } catch {
    return undefined;
  }
}

export function renderReceiptEmail(receipt: ReceiptEmail): EmailContent {
  const { locale, receiptNumber, creditedOn, amountPaisa, trailLink } = receipt;
  const instituteName = textLine(receipt.instituteName);
  const date = new Date(`${creditedOn}T00:00:00Z`);
  if (
    (locale !== "en" && locale !== "ur") ||
    !instituteName ||
    !/^[A-Z0-9]{1,64}-\d{4}-\d{5,19}$/.test(receiptNumber) ||
    !/^[1-9]\d{0,11}00$/.test(amountPaisa) ||
    !/^(?!0000)\d{4}-\d{2}-\d{2}$/.test(creditedOn) ||
    !Number.isFinite(date.getTime()) ||
    date.toISOString().slice(0, 10) !== creditedOn
  )
    throw new Error("invalid_receipt_email");

  const labels = copy[locale];
  const rtl = locale === "ur";
  const direction = rtl ? "rtl" : "ltr";
  const align = rtl ? "right" : "left";
  const font = rtl
    ? "'Noto Naskh Arabic', 'Geeza Pro', Tahoma, serif"
    : "Arial, sans-serif";
  const currency = new Intl.NumberFormat(`${locale}-PK`, {
    style: "currency",
    currency: "PKR",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(BigInt(amountPaisa) / 100n);
  const dateLabel = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "long",
    timeZone: "UTC",
  }).format(date);
  const thanks = labels.thanks(instituteName);
  const link = trustedTrailLink(trailLink, locale);
  const fields = [
    { label: labels.number, value: receiptNumber, dir: "ltr" },
    { label: labels.amount, value: currency, dir: "auto" },
    { label: labels.date, value: dateLabel, dir: "auto" },
    {
      label: labels.cause,
      value: textLine(receipt.causeTitle ?? "") || labels.allNeeds,
      dir: "auto",
    },
  ];

  const text = [
    labels.title,
    "",
    thanks,
    "",
    ...fields.map(({ label, value }) => `${label} · ${value}`),
    ...(link ? ["", labels.trail, link, labels.privacy] : []),
    "",
    labels.notice,
  ].join("\n");

  const html = `<!doctype html>
<html lang="${locale}" dir="${direction}">
<head><meta charset="utf-8"><title>${labels.title}</title></head>
<body lang="${locale}" dir="${direction}" style="margin:0;padding:24px;background:#faf8f3;color:#1b2333;font-family:${font};line-height:1.6">
<div lang="${locale}" dir="${direction}" style="max-width:560px;margin:0 auto;padding:24px;border:1px solid #d9d4c7;background:#fff;text-align:${align}">
<h1 style="margin:0 0 12px;color:#0d254d;font-size:24px">${labels.title}</h1>
<p>${escapeHtml(thanks)}</p>
<table style="width:100%;border-collapse:collapse;text-align:${align}">
${fields
  .map(
    ({ label, value, dir }) =>
      `<tr><th scope="row" style="padding:6px 0;border-bottom:1px solid #d9d4c7;text-align:${align}">${label}</th><td style="padding:6px 12px;border-bottom:1px solid #d9d4c7"><span dir="${dir}">${escapeHtml(value)}</span></td></tr>`,
  )
  .join("\n")}
</table>
${link ? `<p><a href="${escapeHtml(link)}" rel="noreferrer" style="color:#0d254d">${labels.trail}</a><br>${labels.privacy}</p>` : ""}
<p style="color:#4f5868">${labels.notice}</p>
</div>
</body>
</html>`;

  return { subject: `${labels.subject} ${receiptNumber}`, text, html };
}
