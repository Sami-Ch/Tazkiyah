import type { Locale } from "@tazkiyah/i18n/routing";
import type { DonationPurpose } from "./giving";

type GivingCopy = {
  title: string;
  intro: string;
  label: string;
  purpose: string;
  purposes: Record<DonationPurpose, string>;
  cause: string;
  allNeeds: string;
  exploreCauses: string;
  causeUnavailable: string;
  zakatNote: string;
  accounts: string;
  transferNote: string;
  noAccounts: string;
  noMatchingAccounts: string;
  visit: string;
  bank: string;
  accountTitle: string;
  accountNumber: string;
  iban: string;
  branch: string;
  copy: string;
  copied: string;
  copyError: string;
};

export const givingCopy = {
  en: {
    title: "Give to Markaz Al Azeem",
    intro:
      "Choose a giving purpose and see the bank transfer details published by the institute.",
    label: "Give",
    purpose: "Giving purpose",
    purposes: { general: "General giving", sadaqah: "Sadaqah", zakat: "Zakat" },
    cause: "Choose a cause",
    allNeeds: "All needs",
    exploreCauses: "Explore giving causes",
    causeUnavailable:
      "This cause is unavailable for the selected purpose. Choose another cause or give to all needs.",
    zakatNote: "Only causes approved for Zakat appear with this purpose.",
    accounts: "Bank transfer details",
    transferNote:
      "Check the account title and number in your banking app before making a transfer. Contact the institute office for help directing your gift.",
    noAccounts:
      "The institute has yet to publish bank transfer details. Please visit the office for current giving instructions.",
    noMatchingAccounts:
      "The institute has yet to publish bank details for this purpose. Please visit the office for guidance.",
    visit: "Find the institute office",
    bank: "Bank",
    accountTitle: "Account title",
    accountNumber: "Account number",
    iban: "IBAN",
    branch: "Branch",
    copy: "Copy",
    copied: "Copied",
    copyError: "Select and copy the value manually.",
  },
  ur: {
    title: "مرکز العظیم کو عطیہ دیں",
    intro:
      "عطیے کا مقصد منتخب کریں اور ادارے کی جانب سے شائع کردہ بینک تفصیلات دیکھیں۔",
    label: "عطیہ دیں",
    purpose: "عطیے کا مقصد",
    purposes: { general: "عمومی عطیہ", sadaqah: "صدقہ", zakat: "زکوٰۃ" },
    cause: "مد منتخب کریں",
    allNeeds: "تمام ضروریات",
    exploreCauses: "عطیات کی مدات دیکھیں",
    causeUnavailable:
      "یہ مد منتخب مقصد کے لیے دستیاب نہیں۔ کوئی اور مد منتخب کریں یا تمام ضروریات کے لیے عطیہ دیں۔",
    zakatNote: "اس مقصد کے لیے صرف زکوٰۃ کی منظور شدہ مدات دکھائی جاتی ہیں۔",
    accounts: "بینک منتقلی کی تفصیلات",
    transferNote:
      "رقم منتقل کرنے سے پہلے اپنی بینک ایپ میں اکاؤنٹ کا عنوان اور نمبر چیک کریں۔ عطیہ مطلوبہ مد میں دینے کے لیے ادارے کے دفتر سے رہنمائی حاصل کریں۔",
    noAccounts:
      "ادارے نے ابھی بینک تفصیلات شائع نہیں کیں۔ عطیے کا موجودہ طریقہ جاننے کے لیے دفتر تشریف لائیں۔",
    noMatchingAccounts:
      "ادارے نے اس مقصد کے لیے ابھی بینک تفصیلات شائع نہیں کیں۔ رہنمائی کے لیے دفتر تشریف لائیں۔",
    visit: "ادارے کے دفتر کا پتا دیکھیں",
    bank: "بینک",
    accountTitle: "اکاؤنٹ کا عنوان",
    accountNumber: "اکاؤنٹ نمبر",
    iban: "آئی بین",
    branch: "برانچ",
    copy: "کاپی کریں",
    copied: "کاپی ہو گیا",
    copyError: "قدر منتخب کر کے دستی طور پر کاپی کریں۔",
  },
} satisfies Record<Locale, GivingCopy>;
