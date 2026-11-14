/**
 * Public lines that are not yet confirmed by the institute.
 * The words themselves live in packages/i18n/messages (en and ur) so both
 * languages stay in one place. Each entry below is rendered with the
 * "Sample" badge. Replace the matching strings, then remove the entry.
 */
export const samplePublicCopy = [
  {
    id: "education-curriculum",
    keys: ["story.educationTitle", "story.educationBody"],
    replaceBecause:
      "Hifz and Dars-e-Nizami are not named in the institute records. The student count beside this section is the published home figure.",
  },
  {
    id: "quotes",
    keys: [
      "story.quote1",
      "story.quote1Role",
      "story.quote2",
      "story.quote2Role",
      "story.quote3",
      "story.quote3Role",
    ],
    replaceBecause:
      "These are placeholder voices, not quotes from real people. Publish a quote only with the speaker’s consent, and do not attach a real name until you have one.",
  },
  {
    id: "visiting-hours",
    keys: ["story.hoursBody"],
    replaceBecause:
      "Visiting hours are a sample. The address and map use the published institute address.",
  },
] as const;
