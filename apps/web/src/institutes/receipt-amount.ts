import type { Locale } from "@tazkiyah/i18n/routing";

const englishUnits = [
  "zero",
  "one",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight",
  "nine",
  "ten",
  "eleven",
  "twelve",
  "thirteen",
  "fourteen",
  "fifteen",
  "sixteen",
  "seventeen",
  "eighteen",
  "nineteen",
];
const englishTens = [
  "",
  "",
  "twenty",
  "thirty",
  "forty",
  "fifty",
  "sixty",
  "seventy",
  "eighty",
  "ninety",
];
const englishScales = [
  [10n ** 15n, "quadrillion"],
  [10n ** 12n, "trillion"],
  [10n ** 9n, "billion"],
  [10n ** 6n, "million"],
  [1_000n, "thousand"],
  [100n, "hundred"],
] as const;

// Urdu uses distinct words from zero through ninety-nine.
const urduUnits = [
  "صفر ایک دو تین چار پانچ چھ سات آٹھ نو",
  "دس گیارہ بارہ تیرہ چودہ پندرہ سولہ سترہ اٹھارہ انیس",
  "بیس اکیس بائیس تئیس چوبیس پچیس چھبیس ستائیس اٹھائیس انتیس",
  "تیس اکتیس بتیس تینتیس چونتیس پینتیس چھتیس سینتیس اڑتیس انتالیس",
  "چالیس اکتالیس بیالیس تینتالیس چوالیس پینتالیس چھیالیس سینتالیس اڑتالیس انچاس",
  "پچاس اکیاون باون تریپن چون پچپن چھپن ستاون اٹھاون انسٹھ",
  "ساٹھ اکسٹھ باسٹھ تریسٹھ چونسٹھ پینسٹھ چھیاسٹھ سڑسٹھ اڑسٹھ انہتر",
  "ستر اکہتر بہتر تہتر چوہتر پچہتر چھہتر ستہتر اٹھہتر انیاسی",
  "اسی اکیاسی بیاسی تراسی چوراسی پچاسی چھیاسی ستاسی اٹھاسی نواسی",
  "نوے اکیانوے بانوے ترانوے چورانوے پچانوے چھیانوے ستانوے اٹھانوے ننانوے",
]
  .join(" ")
  .split(" ");
const urduScales = [
  [10n ** 11n, "کھرب"],
  [10n ** 9n, "ارب"],
  [10n ** 7n, "کروڑ"],
  [10n ** 5n, "لاکھ"],
  [1_000n, "ہزار"],
  [100n, "سو"],
] as const;

function spellNumber(value: bigint, locale: Locale): string {
  const scale = (locale === "ur" ? urduScales : englishScales).find(
    ([size]) => value >= size,
  );
  if (scale) {
    const [size, name] = scale;
    const remainder = value % size;
    const leading = `${spellNumber(value / size, locale)} ${name}`;
    return remainder ? `${leading} ${spellNumber(remainder, locale)}` : leading;
  }

  const number = Number(value);
  if (locale === "ur") return urduUnits[number];
  if (number < 20) return englishUnits[number];
  const tens = englishTens[Math.floor(number / 10)];
  const units = number % 10;
  return units ? `${tens}-${englishUnits[units]}` : tens;
}

export function receiptAmountInWords(value: string, locale: Locale) {
  const amount = BigInt(value);
  const rupees = amount / 100n;
  const paise = amount % 100n;
  if (locale === "ur") {
    const whole = `${spellNumber(rupees, locale)} ${rupees === 1n ? "روپیہ" : "روپے"}`;
    return paise
      ? `${whole} اور ${spellNumber(paise, locale)} ${paise === 1n ? "پیسہ" : "پیسے"}`
      : whole;
  }

  const whole = `${spellNumber(rupees, locale)} ${rupees === 1n ? "rupee" : "rupees"}`;
  return paise
    ? `${whole} and ${spellNumber(paise, locale)} ${paise === 1n ? "paisa" : "paise"}`
    : whole;
}
