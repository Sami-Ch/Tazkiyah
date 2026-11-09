// The institute theme stored in institute_settings.theme (02 §5, REQ-MIR-005).
// Components use token names only; the values are data per institute.

export const colorTokens = [
  "bg",
  "surface",
  "sunken",
  "text",
  "text-muted",
  "text-disabled",
  "primary",
  "primary-hover",
  "on-primary",
  "on-primary-muted",
  "primary-soft",
  "accent",
  "link",
  "border",
  "border-strong",
  "focus",
  "success",
  "success-soft",
  "warning",
  "warning-soft",
  "danger",
  "danger-soft",
  "info",
  "info-soft",
  "zakat",
  "zakat-soft",
  "verified",
  "verified-soft",
  "verified-on-primary",
] as const;
export type ColorToken = (typeof colorTokens)[number];

export const directions = ["night-and-paper", "garden-and-clay"] as const;
export const fontSlots = [
  "latin-heading",
  "urdu-heading",
  "urdu-body",
] as const;
/** Fonts the platform self-hosts (02 §6). A theme names one; it never uploads one. */
export const hostedFonts = [
  "source-serif-4",
  "noto-nastaliq-urdu",
  "noto-naskh-arabic",
] as const;
export const radiusSizes = ["sm", "md", "lg"] as const;

export type Theme = {
  version: 1;
  direction: (typeof directions)[number];
  color: Record<ColorToken, string>;
  font: Record<(typeof fontSlots)[number], (typeof hostedFonts)[number]>;
  radius: Record<(typeof radiusSizes)[number], number>;
};

/** Markaz Al Azeem's recommended Direction A, "Night and Paper" (02 §5). */
export const nightAndPaper: Theme = {
  version: 1,
  direction: "night-and-paper",
  color: {
    bg: "#FAF8F3",
    surface: "#FFFFFF",
    sunken: "#F1EDE4",
    text: "#1B2333",
    "text-muted": "#4F5868",
    "text-disabled": "#8A909B",
    primary: "#0D254D",
    "primary-hover": "#1A3A6E",
    "on-primary": "#FFFFFF",
    "on-primary-muted": "#C9D6E8",
    "primary-soft": "#E6ECF5",
    accent: "#A9CCE8",
    link: "#1F5A96",
    border: "#D9D4C7",
    "border-strong": "#7A808C",
    focus: "#C8691C",
    success: "#1E6B47",
    "success-soft": "#E4F1E9",
    warning: "#8A5300",
    "warning-soft": "#FBF0DC",
    danger: "#A8322D",
    "danger-soft": "#F9E5E3",
    info: "#1F5A96",
    "info-soft": "#E6EEF7",
    zakat: "#1E6B47",
    "zakat-soft": "#E4F1E9",
    verified: "#7A5A12",
    "verified-soft": "#F6EED9",
    "verified-on-primary": "#D9B25C",
  },
  font: {
    "latin-heading": "source-serif-4",
    "urdu-heading": "noto-nastaliq-urdu",
    "urdu-body": "noto-naskh-arabic",
  },
  radius: { sm: 4, md: 8, lg: 12 },
};

/** The tested alternative, Direction B, "Garden and Clay". Unlisted tokens follow A. */
export const gardenAndClay: Theme = {
  ...nightAndPaper,
  direction: "garden-and-clay",
  color: {
    ...nightAndPaper.color,
    bg: "#F7F5EE",
    sunken: "#EEEADD",
    text: "#1F2421",
    "text-muted": "#545B55",
    "border-strong": "#7C8279",
    primary: "#1F4D3A",
    "primary-hover": "#2B6650",
    "primary-soft": "#E5EFEA",
    accent: "#9C4A2F",
    link: "#1F6B52",
    focus: "#0D254D",
    zakat: "#245A87",
    "zakat-soft": "#E5EDF5",
  },
};

type Pair = readonly [fg: ColorToken, bg: ColorToken, needed: 3 | 4.5];

const statusPairs: Pair[] = [
  ["success", "success-soft", 4.5],
  ["warning", "warning-soft", 4.5],
  ["danger", "danger-soft", 4.5],
  ["info", "info-soft", 4.5],
  ["zakat", "zakat-soft", 4.5],
  ["verified", "verified-soft", 4.5],
  ["on-primary", "danger", 4.5],
  ["on-primary", "success", 4.5],
];

/** The pairs each direction's components use, with the WCAG ratio they need. */
export const requiredPairs: Record<Theme["direction"], readonly Pair[]> = {
  "night-and-paper": [
    ...(["bg", "surface", "sunken", "primary-soft"] as const).flatMap(
      (bg): Pair[] => [
        ["text", bg, 4.5],
        ["text-muted", bg, 4.5],
      ],
    ),
    ["link", "bg", 4.5],
    ["link", "surface", 4.5],
    ["link", "sunken", 4.5],
    ["on-primary", "primary", 4.5],
    ["on-primary", "primary-hover", 4.5],
    ["on-primary-muted", "primary", 4.5],
    ["on-primary-muted", "primary-hover", 4.5],
    ["accent", "primary", 4.5],
    ["verified-on-primary", "primary", 4.5],
    ["primary", "bg", 4.5],
    ["primary", "surface", 4.5],
    ["primary", "primary-soft", 4.5],
    ["success", "primary-soft", 3],
    ...statusPairs,
    ["border-strong", "bg", 3],
    ["border-strong", "surface", 3],
    ["focus", "bg", 3],
    ["focus", "surface", 3],
    ["focus", "primary", 3],
  ],
  "garden-and-clay": [
    ["text", "bg", 4.5],
    ["text", "sunken", 4.5],
    ["text", "primary-soft", 4.5],
    ["text-muted", "bg", 4.5],
    ["text-muted", "sunken", 4.5],
    ["text-muted", "primary-soft", 4.5],
    ["on-primary-muted", "primary", 4.5],
    ["on-primary", "primary", 4.5],
    ["on-primary", "primary-hover", 4.5],
    ["primary", "bg", 4.5],
    ["primary", "sunken", 4.5],
    ["link", "bg", 4.5],
    ["accent", "bg", 4.5],
    ["on-primary", "accent", 4.5],
    ...statusPairs,
    ["border-strong", "bg", 3],
    ["focus", "bg", 3],
    ["focus", "surface", 3],
  ],
};

function luminance(hex: string) {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG 2.1 contrast ratio between two `#RRGGBB` colours. */
export function contrastRatio(a: string, b: string) {
  const [light, dark] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (light + 0.05) / (dark + 0.05);
}

export type ThemeProblem =
  | { kind: "shape"; path: string }
  | {
      kind: "contrast";
      fg: ColorToken;
      bg: ColorToken;
      ratio: number;
      needed: number;
    };

const hex = /^#[0-9a-fA-F]{6}$/;
const isRecord = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

/**
 * Checks a theme before it is saved (02 §5 rules 2 and 4). Returns every
 * problem, each naming its token or pair, or an empty list when it may be saved.
 */
export function checkTheme(value: unknown): ThemeProblem[] {
  if (!isRecord(value)) return [{ kind: "shape", path: "theme" }];
  const problems: ThemeProblem[] = [];
  const shape = (path: string) => problems.push({ kind: "shape", path });
  const section = (
    key: string,
    names: readonly string[],
    valid: (v: unknown) => boolean,
  ) => {
    const part = value[key];
    if (!isRecord(part)) return shape(key);
    for (const name of names) if (!valid(part[name])) shape(`${key}.${name}`);
    for (const name of Object.keys(part))
      if (!names.includes(name)) shape(`${key}.${name}`);
  };

  for (const key of Object.keys(value))
    if (!["version", "direction", "color", "font", "radius"].includes(key))
      shape(key);
  if (value.version !== 1) shape("version");
  if (!directions.includes(value.direction as Theme["direction"]))
    shape("direction");
  section("color", colorTokens, (v) => typeof v === "string" && hex.test(v));
  section("font", fontSlots, (v) =>
    hostedFonts.includes(v as Theme["font"]["urdu-body"]),
  );
  section(
    "radius",
    radiusSizes,
    (v) => Number.isInteger(v) && (v as number) >= 0,
  );
  if (problems.length) return problems;

  const theme = value as Theme;
  for (const [fg, bg, needed] of requiredPairs[theme.direction]) {
    const ratio = contrastRatio(theme.color[fg], theme.color[bg]);
    if (ratio < needed)
      problems.push({ kind: "contrast", fg, bg, ratio, needed });
  }
  return problems;
}
