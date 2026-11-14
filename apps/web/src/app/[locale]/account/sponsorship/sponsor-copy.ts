import type { Locale } from "@tazkiyah/i18n/routing";

export const sponsorCopy = {
  en: {
    title: "Children you sponsor",
    intro:
      "You see a child’s pen name, age and progress updates. Further details appear only with the guardian’s consent. Messages go to the madrasa, not to the child.",
    back: "Back to your account",
    loading: "Loading sponsorships…",
    empty:
      "You are not matched with a child yet. The principal matches one sponsor to one child.",
    unavailable: "Sponsorship details are temporarily unavailable.",
    retry: "Try again",
    age: "Age {years}",
    ageUnknown: "Age is not shown",
    updates: "Progress updates",
    noUpdates:
      "No updates yet. They will appear here when the madrasa publishes them.",
    fullProfile: "Full profile",
    classes: "Classes",
    noClasses: "No current class is recorded.",
    photoHeld:
      "A photograph, if one is held, stays with the madrasa and is not shown on this page.",
    limited:
      "You see the pen name, age and updates. More details appear only after the guardian’s consent, with two sign-offs.",
    messages: "Messages with the madrasa",
    noMessages: "No messages yet.",
    fromYou: "You",
    fromMadrasa: "The madrasa",
    write: "Message the madrasa",
    placeholder: "Write to the madrasa about this child.",
    send: "Send to the madrasa",
    sending: "Sending…",
    sent: "Your message has been sent to the madrasa.",
    contactBlocked:
      "This message seems to contain a phone number or email. Please remove it to send.",
    sendUnavailable:
      "This message could not be sent. Sponsorship messages are open only while the match is active.",
    language: "Message language",
    urdu: "Urdu",
    english: "English",
  },
  ur: {
    title: "جن بچوں کے آپ کفیل ہیں",
    intro:
      "آپ بچے کا قلمی نام، عمر اور پیش رفت دیکھتے ہیں۔ مزید تفصیل صرف سرپرست کی رضامندی سے دکھائی جاتی ہے۔ پیغام مدرسے کو جاتا ہے، بچے کو نہیں۔",
    back: "اپنے اکاؤنٹ پر واپس جائیں",
    loading: "کفالت کی تفصیل دکھائی جا رہی ہے…",
    empty:
      "ابھی آپ کسی بچے سے منسلک نہیں۔ مہتمم ایک کفیل کو ایک بچے سے ملاتے ہیں۔",
    unavailable: "کفالت کی تفصیل عارضی طور پر دستیاب نہیں۔",
    retry: "دوبارہ کوشش کریں",
    age: "عمر {years}",
    ageUnknown: "عمر نہیں دکھائی گئی",
    updates: "پیش رفت",
    noUpdates: "ابھی کوئی تازہ خبر نہیں۔ مدرسہ شائع کرے گا تو یہاں نظر آئے گی۔",
    fullProfile: "مکمل تعارف",
    classes: "جماعتیں",
    noClasses: "موجودہ جماعت درج نہیں۔",
    photoHeld:
      "اگر تصویر محفوظ ہے تو وہ مدرسے کے پاس رہتی ہے اور اس صفحے پر نہیں دکھائی جاتی۔",
    limited:
      "آپ قلمی نام، عمر اور پیش رفت دیکھتے ہیں۔ مزید تفصیل سرپرست کی رضامندی اور دو تصدیقوں کے بعد دکھائی جاتی ہے۔",
    messages: "مدرسے کے ساتھ پیغامات",
    noMessages: "ابھی کوئی پیغام نہیں۔",
    fromYou: "آپ",
    fromMadrasa: "مدرسہ",
    write: "مدرسے کو پیغام بھیجیں",
    placeholder: "اس بچے کے بارے میں مدرسے کو لکھیں۔",
    send: "مدرسے کو بھیجیں",
    sending: "بھیجا جا رہا ہے…",
    sent: "آپ کا پیغام مدرسے کو مل گیا۔",
    contactBlocked:
      "لگتا ہے اس پیغام میں فون نمبر یا ای میل ہے۔ بھیجنے کے لیے اسے ہٹا دیں۔",
    sendUnavailable:
      "پیغام نہیں بھیجا جا سکا۔ پیغام صرف اس وقت کھلے ہیں جب کفالت جاری ہو۔",
    language: "پیغام کی زبان",
    urdu: "اردو",
    english: "انگریزی",
  },
} satisfies Record<Locale, Record<string, string>>;
