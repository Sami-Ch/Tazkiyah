import type { Locale } from "@tazkiyah/i18n/routing";
import type { LocalizedPageText } from "./site-pages";

export type ContactLink = { label: string; href: string };

export type PublishedInstituteContact = {
  address: LocalizedPageText;
  mapUrl?: string;
  phone?: ContactLink;
  whatsapp?: ContactLink;
  email?: ContactLink;
};

const contactMethods = ["phone", "whatsapp", "email"] as const;
export { contactMethods };

export const contactCopy = {
  en: {
    title: "Visit & contact",
    intro:
      "Find Markaz Al Azeem in Sahiwal and get in touch with the institute.",
    back: "Back to the institute",
    location: "Our location",
    address: "Institute address",
    directions: "Open in maps",
    reachUs: "Get in touch",
    phone: "Call the institute",
    whatsapp: "Message on WhatsApp",
    email: "Email the institute",
  },
  ur: {
    title: "ملاقات اور رابطہ",
    intro:
      "ساہیوال میں مرکز العظیم کا پتا اور ادارے سے رابطے کے ذرائع یہاں دیکھیں۔",
    back: "ادارے کے صفحے پر واپس",
    location: "ہمارا مقام",
    address: "ادارے کا پتا",
    directions: "نقشے میں دیکھیں",
    reachUs: "رابطہ کریں",
    phone: "ادارے کو فون کریں",
    whatsapp: "واٹس ایپ پر پیغام بھیجیں",
    email: "ادارے کو ای میل کریں",
  },
} satisfies Record<Locale, object>;

export function parseInstituteContact(
  address: LocalizedPageText,
  fields: Record<string, unknown>,
): PublishedInstituteContact {
  const clean = (value: unknown) =>
    typeof value === "string" ? value.trim() : "";

  const number = (value: unknown) => {
    const label = clean(value);
    return /^\+?[0-9](?:[0-9 ()-]*[0-9])?$/.test(label)
      ? { label, digits: label.replace(/[ ()-]/g, "") }
      : undefined;
  };

  const phoneNumber = number(fields.phone);
  const phone =
    phoneNumber && /^\+?\d{7,15}$/.test(phoneNumber.digits)
      ? { label: phoneNumber.label, href: `tel:${phoneNumber.digits}` }
      : undefined;
  const whatsAppNumber = number(fields.whatsapp);
  const whatsAppDigits = whatsAppNumber?.digits.replace(/^\+/, "");
  const whatsapp =
    whatsAppNumber && whatsAppDigits && /^[1-9]\d{7,14}$/.test(whatsAppDigits)
      ? { label: whatsAppNumber.label, href: `https://wa.me/${whatsAppDigits}` }
      : undefined;
  const emailAddress = clean(fields.email);
  const emailMatch = /^([a-z0-9._+%-]+)@([a-z0-9-]+(?:\.[a-z0-9-]+)+)$/i.exec(
    emailAddress,
  );
  const email =
    emailMatch && emailAddress.length <= 254
      ? {
          label: emailAddress,
          href: `mailto:${encodeURIComponent(emailMatch[1])}@${emailMatch[2]}`,
        }
      : undefined;
  const parsedMap = URL.parse(clean(fields.map_url));
  const mapUrl =
    parsedMap?.protocol === "https:" &&
    !parsedMap.username &&
    !parsedMap.password
      ? parsedMap.href
      : undefined;

  return { address, mapUrl, phone, whatsapp, email };
}
