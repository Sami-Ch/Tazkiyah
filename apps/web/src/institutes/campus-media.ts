import type { Locale } from "@tazkiyah/i18n/routing";

type CampusPath = `/campus/${string}`;
type LocalizedText = Record<Locale, string>;

export type PhotoCredit = {
  creator: string;
  source: string;
  license: "3.0" | "4.0";
};

export type CampusPhoto = {
  src: CampusPath;
  width: number;
  height: number;
  alt: LocalizedText;
  caption: LocalizedText;
  credit?: PhotoCredit;
  variants?: { src: CampusPath; width: number }[];
};

export type CampusFilm = {
  title: LocalizedText;
  poster: CampusPath;
} & (
  | {
      kind: "file";
      src: CampusPath;
      captions: Partial<Record<Locale, CampusPath>>;
    }
  | { kind: "youtube"; videoId: string }
);

type CampusMedia = {
  sample?: boolean;
  photos: CampusPhoto[];
  film?: CampusFilm;
};

// The first approved photo is the homepage lead. Subsequent photos appear in the gallery.
export const campusMedia: CampusMedia = {
  sample: true,
  photos: [
    {
      src: "/campus/sample-wazir-khan-courtyard.webp",
      width: 1280,
      height: 1041,
      variants: [
        { src: "/campus/sample-wazir-khan-courtyard-640.webp", width: 640 },
        { src: "/campus/sample-wazir-khan-courtyard.webp", width: 1280 },
      ],
      alt: {
        en: "Blue tilework around the arched entrances of Wazir Khan Mosque in Lahore",
        ur: "لاہور کی مسجد وزیر خان کے محرابی دروازوں کے گرد نیلی کاشی کاری",
      },
      caption: {
        en: "Wazir Khan Mosque courtyard, Lahore",
        ur: "مسجد وزیر خان کا صحن، لاہور",
      },
      credit: {
        creator: "Muhammad Umair Mirza",
        source:
          "https://commons.wikimedia.org/wiki/File:Courtyard_of_Wazir_Khan_Mosque,_Lahore.jpg",
        license: "4.0",
      },
    },
    {
      src: "/campus/sample-wazir-khan-prayer-hall.webp",
      width: 1280,
      height: 721,
      alt: {
        en: "Painted arches and frescoes in the prayer hall at Wazir Khan Mosque in Lahore",
        ur: "لاہور کی مسجد وزیر خان کے ہال میں نقش دار محرابیں اور دیواری مصوری",
      },
      caption: {
        en: "Wazir Khan Mosque prayer hall, Lahore",
        ur: "مسجد وزیر خان کا ہال، لاہور",
      },
      credit: {
        creator: "Rabeya Mazhar",
        source:
          "https://commons.wikimedia.org/wiki/File:Fresco_work_inside_Wazir_Khan_Mosque_-_Prayer_hall_view.jpg",
        license: "3.0",
      },
    },
  ],
  film: {
    kind: "youtube",
    videoId: "co6Cn0qNKDw",
    poster: "/campus/sample-wazir-khan-prayer-hall.webp",
    title: {
      en: "Wazir Khan Mosque, Lahore · UrduPoint documentary",
      ur: "مسجد وزیر خان، لاہور · اردو پوائنٹ کی دستاویزی فلم",
    },
  },
};

export function hasCampusSection(media: CampusMedia) {
  return media.photos.length > 1 || Boolean(media.film);
}
