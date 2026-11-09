import type { CSSProperties } from "react";

const theme: CSSProperties & Record<`--${string}`, string> = {
  "--paper": "#FAF8F3",
  "--surface": "#FFFFFF",
  "--text": "#1B2333",
  "--muted": "#4F5868",
  "--navy": "#0D254D",
  "--navy-hover": "#1A3A6E",
  "--on-navy": "#FFFFFF",
  "--on-navy-muted": "#C9D6E8",
  "--navy-soft": "#E6ECF5",
  "--silver-blue": "#A9CCE8",
  "--border": "#D9D4C7",
  "--focus": "#C8691C",
};

// Public fixture for the local foundation. The institute service will read these settings from Postgres.
export const institute = {
  name: { en: "Markaz Al Azeem", ur: "مرکز العظیم" },
  mosque: { en: "Jama Masjid Al-Azeem", ur: "جامع مسجد العظیم" },
  address: {
    roadNumber: "92/6-R",
    roadLabel: { en: "Road", ur: "روڈ" },
    region: {
      en: "Sahiwal, Punjab, Pakistan",
      ur: "ساہیوال، پنجاب، پاکستان",
    },
  },
  mapUrl:
    "https://www.google.com/maps/search/?api=1&query=Jama%20Masjid%20Al-Azeem%2C%2092%2F6-R%20Road%2C%20Sahiwal",
  logo: {
    small: "/branding/markaz-al-azeem-emblem-96.webp",
    standard: "/branding/markaz-al-azeem-emblem-192.webp",
    medium: "/branding/markaz-al-azeem-emblem-384.webp",
    large: "/branding/markaz-al-azeem-emblem-512.webp",
  },
  figures: { education: 50, meals: 100, clinic: 25 },
  theme,
};
