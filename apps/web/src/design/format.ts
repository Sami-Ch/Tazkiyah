import type { Locale } from "@tazkiyah/i18n/routing";

const englishMonths = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

const urduMonths = [
  "جنوری",
  "فروری",
  "مارچ",
  "اپریل",
  "مئی",
  "جون",
  "جولائی",
  "اگست",
  "ستمبر",
  "اکتوبر",
  "نومبر",
  "دسمبر",
];

function grouped(whole: bigint) {
  return whole.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/** Whole percent of a target, capped only by the caller when it draws a bar. */
export function percentOf(raised: bigint, target: bigint) {
  if (target <= 0n) return 0;
  return Number((raised * 100n) / target);
}

/** Rupee amount in Western digits (02 §8). Paisa are the minor unit. */
export function formatAmount(paisa: bigint, locale: Locale) {
  const negative = paisa < 0n;
  const abs = negative ? -paisa : paisa;
  const whole = abs / 100n;
  const fraction = abs % 100n;
  const digits = fraction
    ? `${grouped(whole)}.${fraction.toString().padStart(2, "0")}`
    : grouped(whole);
  const signed = negative ? `−${digits}` : digits;
  return locale === "ur" ? `${signed} روپے` : `Rs ${signed}`;
}

function dateParts(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (!match) return undefined;
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) return undefined;
  return { year: match[1], month, day };
}

/** `12 Nov 2026` in English and `12 نومبر 2026` in Urdu (02 §8). */
export function formatDate(value: string, locale: Locale) {
  const parts = dateParts(value);
  if (!parts) return value;
  const month =
    locale === "ur"
      ? urduMonths[parts.month - 1]
      : englishMonths[parts.month - 1];
  return `${parts.day} ${month} ${parts.year}`;
}

function clock(value: string) {
  const match = /T(\d{2}):(\d{2})/.exec(value);
  if (!match) return undefined;
  const hour = Number(match[1]);
  const minute = match[2];
  if (hour > 23) return undefined;
  const hour12 = hour % 12 || 12;
  const suffix = hour < 12 ? "am" : "pm";
  return { hour12, minute, suffix };
}

/** Admin and trail date-times. The clock stays in Western digits. */
export function formatDateTime(value: string, locale: Locale) {
  const date = formatDate(value, locale);
  const time = clock(value);
  if (!time || date === value) return date;
  const clockLabel = `${time.hour12}:${time.minute} ${time.suffix}`;
  return locale === "ur"
    ? `${date}، ${clockLabel} ${time.suffix === "am" ? "صبح" : "بعد دوپہر"}`.replace(
        ` ${time.suffix} `,
        " ",
      )
    : `${date}, ${clockLabel}`;
}

/** Short relative time for public lists. Falls back to a calendar date. */
export function formatRelative(
  value: string,
  locale: Locale,
  now = Date.now(),
) {
  const time = Date.parse(value);
  if (!Number.isFinite(time)) return formatDate(value, locale);
  const minutes = Math.round((now - time) / 60_000);
  const phrase = (count: number, en: [string, string], ur: [string, string]) =>
    locale === "ur"
      ? `${count} ${count === 1 ? ur[0] : ur[1]}`
      : `${count} ${count === 1 ? en[0] : en[1]}`;
  if (minutes < 1) return locale === "ur" ? "ابھی" : "Just now";
  if (minutes < 60) {
    return phrase(
      minutes,
      ["minute ago", "minutes ago"],
      ["منٹ پہلے", "منٹ پہلے"],
    );
  }
  const hours = Math.round(minutes / 60);
  if (hours < 24) {
    return phrase(
      hours,
      ["hour ago", "hours ago"],
      ["گھنٹہ پہلے", "گھنٹے پہلے"],
    );
  }
  const days = Math.round(hours / 24);
  if (days < 14) {
    return phrase(days, ["day ago", "days ago"], ["دن پہلے", "دن پہلے"]);
  }
  return formatDate(value, locale);
}
