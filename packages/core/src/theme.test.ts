import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  checkTheme,
  contrastRatio,
  gardenAndClay,
  nightAndPaper,
  type ColorToken,
  type Theme,
} from "./theme";

const read = (path: string) =>
  readFileSync(new URL(`../../../${path}`, import.meta.url), "utf8");
const design = read("plan/02-design-ui-ux.md");

/** Every "`fg` on `bg` … | 1.23:1" pair in one 02 §5 subsection. */
function documentedRatios(heading: string) {
  const start = design.indexOf(heading);
  const section = design.slice(start, design.indexOf("\n### ", start + 1));
  return [
    ...section.matchAll(
      /`([a-z-]+)`(?: as a control edge| track)? on `([a-z-]+)`[^|]*\| ([\d.]+):1/g,
    ),
  ].map(([, fg, bg, ratio]) => ({ fg, bg, ratio: Number(ratio) }));
}

describe("02 §5 contrast", () => {
  it.each([
    ["### Direction A computed contrast", nightAndPaper],
    ["### Direction B tokens", gardenAndClay],
  ] as const)("matches every ratio documented under %s", (heading, theme) => {
    const pairs = documentedRatios(heading);
    expect(pairs.length).toBeGreaterThan(15);
    for (const { fg, bg, ratio } of pairs) {
      const computed = contrastRatio(
        theme.color[fg as ColorToken],
        theme.color[bg as ColorToken],
      );
      expect(Math.abs(computed - ratio), `${fg} on ${bg}`).toBeLessThanOrEqual(
        0.011,
      );
    }
  });

  it("accepts both tested directions", () => {
    expect(checkTheme(nightAndPaper)).toEqual([]);
    expect(checkTheme(gardenAndClay)).toEqual([]);
  });

  it("refuses a theme that fails a pair and names the pair", () => {
    const faded = structuredClone(nightAndPaper);
    faded.color["text-muted"] = "#8A909B";
    expect(checkTheme(faded)).toContainEqual(
      expect.objectContaining({
        kind: "contrast",
        fg: "text-muted",
        bg: "bg",
        needed: 4.5,
      }),
    );
    const invisibleFocus = structuredClone(gardenAndClay);
    invisibleFocus.color.focus = "#E5EFEA";
    expect(checkTheme(invisibleFocus)).toContainEqual(
      expect.objectContaining({
        kind: "contrast",
        fg: "focus",
        bg: "bg",
        needed: 3,
      }),
    );
  });
});

describe("theme shape", () => {
  it("is what the Markaz Al Azeem seed stores", () => {
    const seed = read("db/seed/markaz_al_azeem.sql");
    const json = seed.slice(
      seed.indexOf('\'{\n      "version"') + 1,
      seed.indexOf("}',", seed.indexOf('"radius"')) + 1,
    );
    expect(JSON.parse(json)).toEqual(nightAndPaper);
  });

  it.each<[string, (t: Theme & Record<string, unknown>) => void, string]>([
    [
      "an unknown token",
      (t) => Object.assign(t.color, { brand: "#000000" }),
      "color.brand",
    ],
    [
      "a colour that is not #RRGGBB",
      (t) => (t.color.primary = "navy"),
      "color.primary",
    ],
    [
      "a missing token",
      (t) => delete (t.color as Partial<Theme["color"]>).link,
      "color.link",
    ],
    [
      "a font the platform does not host",
      (t) => (t.font["urdu-body"] = "comic-sans" as never),
      "font.urdu-body",
    ],
    [
      "an unknown direction",
      (t) => (t.direction = "neon" as never),
      "direction",
    ],
    ["a fractional radius", (t) => (t.radius.md = 2.5), "radius.md"],
    ["an extra top-level key", (t) => (t.logo = "x"), "logo"],
  ])("refuses %s", (_, change, path) => {
    const theme = structuredClone(nightAndPaper) as Theme &
      Record<string, unknown>;
    change(theme);
    expect(checkTheme(theme)).toContainEqual({ kind: "shape", path });
  });

  it("refuses values that are not themes", () => {
    expect(checkTheme(null)).toEqual([{ kind: "shape", path: "theme" }]);
    expect(checkTheme([])).toEqual([{ kind: "shape", path: "theme" }]);
  });
});
