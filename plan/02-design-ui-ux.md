# 02 Design, UI and UX

**Status:** planning · **Last updated:** 2026-11-07 · **Owner document for:** P0-E4, P3-E7

Read [00-MASTER-PLAN.md](00-MASTER-PLAN.md) first. It wins over this document if they disagree. Words such as *cause*, *trail*, *persona* and *scope* have the meanings in the [glossary (00 §8)](00-MASTER-PLAN.md#8-glossary).

## 1. Purpose

This document says how Tazkiyah looks, reads and behaves for every user of Markaz Al Azeem: donors in Sahiwal and abroad, students, teachers and the admin. It gives a developer or agent enough to build the design system (epic P0-E4), the onboarding walkthrough (epic P3-E7) and the screens that other documents specify, without asking design questions.

It covers:

- the visual direction and the theme tokens that each institute stores as data;
- Latin and Urdu typography, and how fonts load on slow 3G;
- layout, spacing and core components;
- right-to-left (RTL) and mixed-direction rules;
- mobile and low-bandwidth budgets;
- accessibility, tone of voice, the main UX flows, the walkthrough, and what to show while there are no photos or videos.

## 2. Scope and out of scope

**In scope**

- Theme tokens (colour, type, spacing, radius) stored per institute in `institute_settings`.
- The design system: tokens, type, core components, a component gallery page.
- Screen-level design guidance for public pages, donation, trail, content hub, sponsorship and admin forms.
- The onboarding walkthrough for students (required) and teachers (short version).
- Placeholder design for missing photos, videos and avatars.

**Out of scope (owned elsewhere)**

| Topic | Owner |
| --- | --- |
| Which pages exist and what each shows | [05 §4, §5](05-public-pages-roles-admin.md) |
| Who may do what | [05 §7](05-public-pages-roles-admin.md) |
| Donation rules, Zakat rules, FIFO, sponsorship rules | [06](06-donations-and-trail.md) |
| Post types, scopes, moderation and child-safety rules | [07](07-content-hub-student-teacher.md) |
| Translation file plumbing, `/ur` and `/en` routing, language memory | [03 §7](03-architecture.md) |
| Upload caps, image processing and storage | [03 §8](03-architecture.md) |
| Field names and tables | [04](04-database.md) |

**Not in this version:** dark mode (the tokens make it possible later), a theme editor screen for admins (themes are set by seed data or by Sami), custom illustrations, a Zakat calculator, offline mode, and any platform-level or multi-institute branding.

## 3. Decisions

Decisions already in the log that shape this document:

| Decision | What it means for design |
| --- | --- |
| [D-022](08-decision-log.md#d-022), [D-108](08-decision-log.md#d-108) | Use the selected [Markaz Al Azeem Emblem](<../assets/logo/Markaz Al Azeem Emblem.png>) as the institute logo. |
| [D-007](08-decision-log.md#d-007) | Every screen exists in Urdu and English from Phase 1. |
| [D-026](08-decision-log.md#d-026) | Public pages must be readable within 5 seconds on slow 3G (proposed target). Drives §6 and §9. |
| [D-020](08-decision-log.md#d-020) | Videos are YouTube links or embeds by default. Drives §9 and §14. |
| [D-009](08-decision-log.md#d-009) | Guest donors give with only an email. The donation flow never forces an account. |
| [D-010](08-decision-log.md#d-010) | The donor wall always shows amounts. The name is the donor's choice. |
| [D-011](08-decision-log.md#d-011) | Zakat eligibility is set per cause by the admin. The UI filters causes, it does not decide. |
| [D-014](08-decision-log.md#d-014), [D-015](08-decision-log.md#d-015) | Staff create student accounts. Students then personalise a persona in the walkthrough. |
| [D-017](08-decision-log.md#d-017) | Sponsor screens show only persona, age and updates until consent has two sign-offs. |
| [D-018](08-decision-log.md#d-018), [D-019](08-decision-log.md#d-019) | Threads first. Class and madrasa posts appear at once. Public needs approval. |

New design decisions made in this document. They need `D-` numbers in [08](08-decision-log.md); the main agent assigns them in the consistency check. Until then they are cited as **PD-02-nn**.

| ID | Decision | Options considered | Reason |
| --- | --- | --- | --- |
| PD-02-01 | Direction A, "Night and Paper", is the recommended visual direction (§4). | A: navy and paper; B: green and clay. | The navy palette complements the emblem's blue and silver. A circular frame keeps its darker background contained. |
| PD-02-02 | Urdu text uses **Naskh** (Noto Naskh Arabic) everywhere. **Nastaliq** (Noto Nastaliq Urdu) is used only for h1 and h2 headings on public Urdu pages, and only when it is already cached (`font-display: optional`). | Nastaliq everywhere; Naskh everywhere; split. | Nastaliq is what Urdu readers love, but the font is several times heavier, needs about twice the line height, clips in buttons and inputs, and is hard to read at small sizes on low-resolution screens. Naskh is compact, clear at 16 px, and is already installed on most Android phones as the system Arabic font, so it often costs zero bytes. |
| PD-02-03 | Latin body text uses the phone's system font. Latin headings use Source Serif 4 (one weight, 600). | Web font for everything; system font for everything. | System fonts cost nothing to download. One serif weight gives headings dignity for about 25 KB. |
| PD-02-04 | Numbers use Western digits (0 to 9) in both languages. Urdu month names are used on Urdu pages. Amounts group in thousands (`25,000`). | Urdu digits (۰ to ۹); Western digits. | Bank statements, receipts and phone keypads in Pakistan use Western digits, so donors can match amounts to their bank app. Urdu `Intl` formatting for `ur-PK` uses Western digits by default. |
| PD-02-05 | Theme values live only in `institute_settings`. Code knows token names, never colour values. A theme that fails the contrast pairs in §5 cannot be saved. | Hard-coded theme; settings without checks; settings with checks. | Meets REQ-MIR-005 and keeps future institutes from breaking REQ-ACC-001 with their own colours. |
| PD-02-06 | Students choose a persona avatar from preset pattern avatars. The design has no face photo slot for students. | Photo upload; presets only. | Faces are hidden by default (REQ-CHS-001). Presets cost 2 KB each and look consistent. If [07 §11](07-content-hub-student-teacher.md) later allows avatar uploads, they follow its face rules. |
| PD-02-07 | No stock photos, and no generated images of the madrasa or of children, are used as placeholders. Placeholders are geometric patterns and line icons drawn from theme tokens. | Stock photos; generated images; patterns and icons. | A donation site must not show pictures that are not real. Patterns are honest, tiny and match each institute's colours. |
| PD-02-08 | Lists use a "Show more" button with 20 items per page, not infinite scroll. | Infinite scroll; pages; "Show more". | Predictable data use on 3G, works with keyboard and screen readers, and the footer stays reachable. |

## 4. Visual directions

Both directions are dignified, calm and trustworthy. Both use plenty of white space, few colours, no gradients, no auto-moving carousels and no decorative animation. Both use the same tokens, type scale and components; only the token values change.

### Direction A: "Night and Paper" (recommended)

- **Idea:** the logo's night-sky navy for the header, footer and main buttons, on a warm paper-white page. Pale silver-blue from the logo's glass is used only on navy surfaces. A muted gold appears only for the *verified* mark.
- **Feel:** an old, well-kept library or a trusted bank. Quiet and serious, warm rather than cold because the page is off-white, not pure white.
- **Logo.** Display the emblem in a circular frame on both light and dark surfaces. Its source file keeps the original artwork and navy background.
- **Headings:** Source Serif 4 (Latin), Noto Nastaliq Urdu when cached, else Noto Naskh Arabic (Urdu).
- **Shapes:** 8 px radius on cards and inputs, thin `border` lines, one soft shadow level only on raised sheets.
- **Ornament:** one thin 8-point star pattern band (SVG, under 2 KB) under the header on public pages. Nowhere else.

### Direction B: "Garden and Clay"

- **Idea:** deep mosque-garden green for the header and buttons, a clay accent for highlights, on cream.
- **Feel:** warm, traditional and earthy.
- **Logo:** must sit in a navy disc inside the green header, because the logo's navy square clashes with green.
- **Headings:** system sans in both scripts (lighter download).
- **Weaknesses:** the logo needs a frame; green is common to many religious bodies and to political parties in Pakistan, so it is less distinctive and could read as political; the clay accent competes with danger red.

### Recommendation

Use **Direction A** (PD-02-01). It is built from the logo, blends with it without editing the image, and keeps colour for meaning (Zakat green, verified gold, status colours) instead of decoration. Direction B's tokens are kept in §5 as a tested alternative, which also proves the token system works for a second institute.

### Page anatomy (Direction A, 360 px phone)

```
┌──────────────────────────────────┐
│ [logo] Markaz Al Azeem   اردو  ☰ │  navy header, 56 px
├──────────────────────────────────┤
│ ✦✦✦✦✦ thin pattern band ✦✦✦✦✦✦ │  public pages only, 8 px
│                                  │
│  Feed 100 people every day       │  h1, paper background
│  One sentence of plain context.  │
│  [ Donate ]                      │  primary button, full width
│                                  │
│  ┌ cause card ────────────────┐  │  white surface, border
│  │ pattern + icon header      │  │
│  │ Wheat stock     Zakat ✓    │  │
│  │ ████████░░░░ 62% of target │  │
│  │ Rs 124,000 raised          │  │
│  └────────────────────────────┘  │
├──────────────────────────────────┤
│ navy footer: address, contact    │
└──────────────────────────────────┘
```

## 5. Colour

### Rules

1. Every colour is a **theme token**. Components use token names only (`color.primary`), never hex values (PD-02-05).
2. Token values are stored per institute in `institute_settings` under the key `theme`, as defined in [04 §5](04-database.md). The seed migration writes Markaz Al Azeem's values below.
3. On each request the server reads the institute's theme (chosen by domain, [03 §4](03-architecture.md)) and writes the tokens as CSS custom properties in a small inline `<style>` block on `<html>`. No extra request, no flash of the wrong colours.
4. Saving a theme runs the contrast check in this section. If any required pair fails, the save is refused with the failing pair named.
5. Colour never carries meaning alone. Every status also has a word and, where useful, an icon.

### Theme token example (stored data, not code)

```json
{
  "theme": {
    "version": 1,
    "direction": "night-and-paper",
    "color": {
      "bg": "#FAF8F3", "surface": "#FFFFFF", "sunken": "#F1EDE4",
      "text": "#1B2333", "text-muted": "#4F5868", "text-disabled": "#8A909B",
      "primary": "#0D254D", "primary-hover": "#1A3A6E", "on-primary": "#FFFFFF",
      "on-primary-muted": "#C9D6E8", "primary-soft": "#E6ECF5",
      "accent": "#A9CCE8", "link": "#1F5A96",
      "border": "#D9D4C7", "border-strong": "#7A808C", "focus": "#C8691C",
      "success": "#1E6B47", "success-soft": "#E4F1E9",
      "warning": "#8A5300", "warning-soft": "#FBF0DC",
      "danger": "#A8322D", "danger-soft": "#F9E5E3",
      "info": "#1F5A96", "info-soft": "#E6EEF7",
      "zakat": "#1E6B47", "zakat-soft": "#E4F1E9",
      "verified": "#7A5A12", "verified-soft": "#F6EED9", "verified-on-primary": "#D9B25C"
    },
    "font": { "latin-heading": "source-serif-4", "urdu-heading": "noto-nastaliq-urdu", "urdu-body": "noto-naskh-arabic" },
    "radius": { "sm": 4, "md": 8, "lg": 12 }
  }
}
```

Fonts are chosen from a fixed list the platform self-hosts (§6). A theme names a font; it never uploads one.

### Direction A tokens (recommended)

| Token | Hex | Use |
| --- | --- | --- |
| `bg` | `#FAF8F3` | Page background (warm paper) |
| `surface` | `#FFFFFF` | Cards, inputs, sheets |
| `sunken` | `#F1EDE4` | Wells, code of bank details, table stripes |
| `text` | `#1B2333` | Body text and headings |
| `text-muted` | `#4F5868` | Secondary text, captions, hints |
| `text-disabled` | `#8A909B` | Disabled labels only |
| `primary` | `#0D254D` | Header, footer, primary buttons, progress fill (logo navy) |
| `primary-hover` | `#1A3A6E` | Hover and pressed state of primary |
| `on-primary` | `#FFFFFF` | Text and icons on primary |
| `on-primary-muted` | `#C9D6E8` | Secondary text on primary (footer) |
| `primary-soft` | `#E6ECF5` | Selected rows, progress track, placeholder base |
| `accent` | `#A9CCE8` | Silver-blue from the logo. **Only on `primary`** (active nav underline, pattern band) |
| `link` | `#1F5A96` | Links in body text (always underlined) |
| `border` | `#D9D4C7` | Card and divider lines (decorative) |
| `border-strong` | `#7A808C` | Input borders, checkboxes, any border that shows a control's edge |
| `focus` | `#C8691C` | Keyboard focus ring, 2 px plus 2 px offset |
| `success` / `success-soft` | `#1E6B47` / `#E4F1E9` | Saved, published, *spent* event |
| `warning` / `warning-soft` | `#8A5300` / `#FBF0DC` | Submitted, waiting, missing translation notice |
| `danger` / `danger-soft` | `#A8322D` / `#F9E5E3` | Errors, taken down, reversal |
| `info` / `info-soft` | `#1F5A96` / `#E6EEF7` | Tips, *received* event |
| `zakat` / `zakat-soft` | `#1E6B47` / `#E4F1E9` | Zakat-eligible badge and Zakat donation chip |
| `verified` / `verified-soft` | `#7A5A12` / `#F6EED9` | Verified article mark on light surfaces |
| `verified-on-primary` | `#D9B25C` | Verified mark on navy surfaces only |

### Direction A computed contrast (WCAG 2.1)

Computed with the WCAG relative-luminance formula, not estimated. AA needs 4.5:1 for normal text, 3:1 for large text (24 px, or 18.7 px bold) and for control edges, focus rings and graphics (non-text, WCAG 1.4.11).

| Pair (foreground on background) | Ratio | Needed | Result |
| --- | --- | --- | --- |
| `text` on `bg` | 14.82:1 | 4.5 | Pass (AAA) |
| `text` on `surface` | 15.73:1 | 4.5 | Pass (AAA) |
| `text` on `sunken` | 13.47:1 | 4.5 | Pass (AAA) |
| `text` on `primary-soft` | 13.25:1 | 4.5 | Pass (AAA) |
| `text-muted` on `bg` | 6.76:1 | 4.5 | Pass |
| `text-muted` on `surface` | 7.17:1 | 4.5 | Pass (AAA) |
| `text-muted` on `sunken` | 6.14:1 | 4.5 | Pass |
| `text-muted` on `primary-soft` | 6.04:1 | 4.5 | Pass |
| `link` on `bg` | 6.68:1 | 4.5 | Pass |
| `link` on `surface` | 7.09:1 | 4.5 | Pass (AAA) |
| `link` on `sunken` | 6.07:1 | 4.5 | Pass |
| `on-primary` on `primary` | 15.12:1 | 4.5 | Pass (AAA) |
| `on-primary` on `primary-hover` | 11.20:1 | 4.5 | Pass (AAA) |
| `on-primary-muted` on `primary` | 10.27:1 | 4.5 | Pass (AAA) |
| `on-primary-muted` on `primary-hover` | 7.61:1 | 4.5 | Pass (AAA) |
| `accent` on `primary` | 8.99:1 | 4.5 | Pass (AAA) |
| `verified-on-primary` on `primary` | 7.54:1 | 4.5 | Pass (AAA) |
| `primary` on `bg` (headings, outline buttons) | 14.25:1 | 4.5 | Pass (AAA) |
| `primary` on `surface` | 15.12:1 | 4.5 | Pass (AAA) |
| `primary` on `primary-soft` (selected item, progress fill vs track) | 12.73:1 | 4.5 | Pass (AAA) |
| `success` on `success-soft` | 5.56:1 | 4.5 | Pass |
| `success` on `primary-soft` (spent fill on track) | 5.44:1 | 3 | Pass |
| `warning` on `warning-soft` | 5.61:1 | 4.5 | Pass |
| `danger` on `danger-soft` | 5.49:1 | 4.5 | Pass |
| `info` on `info-soft` | 6.06:1 | 4.5 | Pass |
| `zakat` on `zakat-soft` | 5.56:1 | 4.5 | Pass |
| `verified` on `verified-soft` | 5.50:1 | 4.5 | Pass |
| `on-primary` on `danger` (danger button) | 6.65:1 | 4.5 | Pass |
| `on-primary` on `success` | 6.46:1 | 4.5 | Pass |
| `border-strong` on `bg` (input edge) | 3.74:1 | 3 | Pass |
| `border-strong` on `surface` | 3.97:1 | 3 | Pass |
| `focus` on `bg` | 3.60:1 | 3 | Pass |
| `focus` on `surface` | 3.82:1 | 3 | Pass |
| `focus` on `primary` (focus inside header) | 3.96:1 | 3 | Pass |
| `text-disabled` on `surface` | 3.21:1 | exempt | Disabled controls are exempt; kept above 3:1 anyway |

**Forbidden pairs** (the theme check rejects any component that uses them):

| Pair | Ratio | Why forbidden |
| --- | --- | --- |
| `accent` on `bg` | 1.58:1 | Silver-blue disappears on paper. Use only on `primary`. |
| `verified-on-primary` on `bg` | 1.89:1 | Use `verified` on light surfaces. |
| `border` as a control edge on `surface` | 1.48:1 | Decorative only. Inputs use `border-strong`. |
| `primary-soft` track on `surface` without a fill | 1.19:1 | The track is decorative; the fill and the text label carry the value. |

### Direction B tokens (alternative, tested)

| Token | Hex | Token | Hex |
| --- | --- | --- | --- |
| `bg` | `#F7F5EE` | `primary` | `#1F4D3A` |
| `surface` | `#FFFFFF` | `primary-hover` | `#2B6650` |
| `sunken` | `#EEEADD` | `primary-soft` | `#E5EFEA` |
| `text` | `#1F2421` | `accent` (clay) | `#9C4A2F` |
| `text-muted` | `#545B55` | `link` | `#1F6B52` |
| `border-strong` | `#7C8279` | `focus` | `#0D254D` |
| `zakat` / `zakat-soft` | `#245A87` / `#E5EDF5` | `verified` / `verified-soft` | `#7A5A12` / `#F6EED9` |
| logo disc | `#0D254D` | status colours | same as Direction A |

| Pair | Ratio | Pair | Ratio |
| --- | --- | --- | --- |
| `text` on `bg` | 14.45:1 | `on-primary` on `primary` | 9.63:1 |
| `text` on `sunken` | 13.09:1 | `on-primary` on `primary-hover` | 6.73:1 |
| `text` on `primary-soft` | 13.41:1 | `primary` on `bg` | 8.83:1 |
| `text-muted` on `bg` | 6.41:1 | `primary` on `sunken` | 8.00:1 |
| `text-muted` on `sunken` | 5.81:1 | `link` on `bg` | 5.86:1 |
| `text-muted` on `primary-soft` | 5.95:1 | `accent` on `bg` | 5.61:1 |
| `on-primary-muted` (`#C9D6E8`) on `primary` | 6.54:1 | `on-primary` on `accent` | 6.12:1 |
| `zakat` on `zakat-soft` | 6.15:1 | `border-strong` on `bg` | 3.61:1 |
| `focus` on `bg` | 13.86:1 | `focus` on `surface` | 15.12:1 |

### Meaning colours used across screens

| Meaning | Token | Always paired with |
| --- | --- | --- |
| Trail: received | `info` | Word "Received", inbox icon |
| Trail: allocated | `primary` | Word "Allocated", arrow-split icon |
| Trail: spent | `success` | Word "Spent", receipt icon |
| Trail: reported | `verified` | Word "Reported", document icon |
| Trail: reversal | `danger` | Word "Corrected", undo icon, link to the event it corrects |
| Zakat | `zakat` | Word "Zakat" or "Zakat eligible" |
| Moderation: draft / submitted / approved / published / taken down | `text-muted` / `warning` / `info` / `success` / `danger` | The state word |
| Verified article | `verified` | Seal icon, "Verified by" and the teacher's name |

## 6. Typography

### Families

| Role | Latin (`/en`) | Urdu (`/ur`) |
| --- | --- | --- |
| Body, UI, forms, tables | System stack: `system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", sans-serif` (0 KB) | **Noto Naskh Arabic**, variable weight 400 to 700, self-hosted, subset (PD-02-02) |
| Headings h1 to h3 | **Source Serif 4**, weight 600, self-hosted, Latin subset (PD-02-03) | h1, h2 on public pages: **Noto Nastaliq Urdu** 400 if cached, else Noto Naskh Arabic 700. h3 and all hub and admin headings: Noto Naskh Arabic 700 |
| Numbers, IBAN, references | System stack with `font-variant-numeric: tabular-nums` | Same digits; Naskh's Western digits or the system fallback |
| Quranic verses (about page) | n/a | Noto Naskh Arabic with diacritics kept in the subset |

All fonts are free under the SIL Open Font License and are self-hosted from the site's own domain, not from a third-party font service. That saves a DNS lookup and connection on 3G and avoids sending visitor data elsewhere.

### Nastaliq or Naskh

Decision PD-02-02: **Naskh for reading and interface, Nastaliq as a cached enhancement for big public headings.**

| Factor | Nastaliq (Noto Nastaliq Urdu) | Naskh (Noto Naskh Arabic) |
| --- | --- | --- |
| Reader preference | Strongly preferred for Urdu; feels "proper" | Familiar from Arabic and the Quran; accepted for screens |
| File size | Several times heavier than Naskh, because of its many contextual forms | Light; one variable file for all weights |
| Already on the phone | No | Yes on most Android phones (system Arabic font), so `local()` often costs 0 KB |
| Line height needed | About 2.0 to 2.4 | About 1.7 to 1.8 |
| Small sizes on low-res screens | Dots and stacked letters blur under 18 px | Clear at 16 px |
| Buttons, inputs, tables | Clips and overflows in fixed-height controls | Works |

### Type scale

Sizes are in `rem` (1 rem = 16 px at default settings) so they grow with the user's text size. Urdu sizes are one step larger than Latin because Arabic-script letters look smaller at the same pixel size.

| Style | Latin size / line height | Urdu Naskh size / line height | Urdu Nastaliq (h1, h2 only) |
| --- | --- | --- | --- |
| h1 (phone → ≥960 px) | 34 → 40 px / 1.2 | 34 → 40 px / 1.5 | 32 → 38 px / 2.1 |
| h2 | 28 px / 1.25 | 28 px / 1.55 | 26 px / 2.1 |
| h3 | 22 px / 1.3 | 24 px / 1.6 | not used |
| h4, card title | 18 px / 1.35, 600 | 20 px / 1.6, 700 | not used |
| Body | 16 px / 1.55 | 18 px / 1.8 | not used |
| Lead paragraph | 18 px / 1.55 | 20 px / 1.8 | not used |
| Small, captions, hints | 14 px / 1.45 | 16 px / 1.7 | not used |
| Button label | 16 px, 600 | 18 px, 700 | not used |
| Big amount (cause card, receipt) | 24 px, 600, tabular | 24 px, 700, tabular | not used |

Rules:

- Minimum text size is 14 px Latin and 16 px Urdu. No exceptions, including legal text and admin tables.
- Reading width is at most 68 characters for Latin and about 60 for Urdu (`max-width: 38rem` for article bodies).
- Headings that may render in Nastaliq reserve Nastaliq's line height even when Naskh is used, so nothing jumps if the font appears on a later visit.
- Never fake bold or italic in Urdu. Urdu has no italics: emphasis is bold or a `primary-soft` highlight.
- Letter spacing is never added to Urdu (it breaks joining).

### Font loading and subsetting plan for slow 3G

Budget: fonts on the critical path are at most **90 KB on an Urdu page** and **30 KB on an English page** (see the full page budget in §9).

| Font | Subset | `font-display` | Preload | Target size (woff2) |
| --- | --- | --- | --- | --- |
| Noto Naskh Arabic, variable 400 to 700 | Urdu letters (U+0600 to U+06FF used by Urdu), Arabic diacritics U+064B to U+065F and U+0670, Arabic punctuation, ZWJ/ZWNJ, digits. Drop Persian-only, Sindhi-only and presentation forms not needed by shaping. | `swap`, with a size-adjusted fallback face | Yes, on `/ur` pages only | ≤ 90 KB, measured in P0-E4-T04 |
| Source Serif 4, 600 | Basic Latin, Latin-1, `₨`, en and em dash, curly quotes | `swap`, with a size-adjusted fallback face | Yes, on `/en` pages only | ≤ 30 KB |
| Noto Nastaliq Urdu, 400 | Same Urdu set as Naskh, no diacritics beyond those Urdu needs | `optional` | **No.** Fetched with low priority after the page loads, so it is cached for the next page | ≤ 250 KB; if larger after subsetting, drop Nastaliq headings (fallback is already the design) |

Steps:

1. `@font-face` for Naskh lists `local("Noto Naskh Arabic")` and `local("Noto Naskh Arabic UI")` before the self-hosted file, so Android phones that already have it download nothing.
2. Subset with a standard subsetting tool at build time, keeping OpenType shaping features (`init`, `medi`, `fina`, `isol`, `liga`, `mark`, `mkmk`, `rlig`, `calt`, `ccmp`) so joining and diacritics stay correct. Test with the shaping test strings in P0-E4-T04 (all Urdu letters in all joining positions, `لا`, `ے` and `ں` at word ends, `ؤ`, and the verse 62:2 with diacritics).
3. Fallback faces use `size-adjust`, `ascent-override` and `descent-override` so the swap does not shift the layout.
4. Fonts are served with a one-year immutable cache and a hashed file name.
5. With the `Save-Data` header on, Nastaliq is never fetched and Source Serif 4 is not preloaded.
6. **Fallback rule (R-07):** if the measured Naskh subset exceeds 90 KB, use the static 400 file plus the system font for bold (no faux bold), and log the decision in 08.

## 7. Layout, spacing and components

### Spacing scale (4 px base)

| Token | px | Typical use |
| --- | --- | --- |
| `space-0` | 0 | |
| `space-1` | 4 | Icon to label gap |
| `space-2` | 8 | Inside chips and badges |
| `space-3` | 12 | Between related form lines |
| `space-4` | 16 | Page side gutter on phones, card padding |
| `space-5` | 24 | Between cards, section inner spacing |
| `space-6` | 32 | Between sections on phones |
| `space-7` | 48 | Between sections on wide screens |
| `space-8` | 64 | Hero top and bottom on wide screens |

Radius: `radius-sm` 4 px (badges), `radius-md` 8 px (cards, inputs, buttons), `radius-lg` 12 px (sheets, dialogs), `radius-full` (avatars, pills). Shadow: one level only, `0 2px 8px rgb(13 37 77 / 0.12)`, for sheets and dialogs. Cards use a border, not a shadow (cheaper on low-end GPUs).

### Grid and breakpoints

Mobile first. Styles are written for 360 px and widened with `min-width` queries.

| Name | Min width | Columns | Side gutter | Notes |
| --- | --- | --- | --- | --- |
| base | 0 (designed at 360) | 1 | 16 px | Everything works at 320 px without horizontal scroll |
| `sm` | 600 px | 2 cards per row | 24 px | |
| `md` | 960 px | 12-column grid, 3 cards per row | 32 px | Side navigation in admin |
| `lg` | 1200 px | 12-column grid | auto | Content max width 1120 px, centred |

All layout uses **CSS logical properties** (`margin-inline-start`, `padding-inline-end`, `inset-inline-start`, `text-align: start`) so RTL mirroring needs no separate stylesheet (§8).

### Core components

Each component is built once, uses tokens only, works in both directions, and appears on the gallery page (P0-E4-T15). Interactive parts have a hit area of at least 48 by 48 px (above the 44 px minimum).

| Component | Variants and states | Notes |
| --- | --- | --- |
| Button | primary, secondary (outline `primary`), quiet (text), danger; default, hover, pressed, focus, disabled, loading | 48 px high; full width on phones for the main action; loading shows a spinner and keeps the label for screen readers |
| Link | inline, standalone | Always underlined in body text |
| Text field, textarea | default, focus, error, disabled, read-only | Label always visible above the field (no placeholder-only labels); hint below; error below in `danger` with icon |
| Amount field | rupee prefix, numeric keypad (`inputmode="numeric"`) | Shows formatted amount below as you type ("Rs 25,000" / "25,000 روپے"); prefix sits on the inline-start side |
| Amount chips | 4 preset amounts from cause settings plus "Other" | Radio group semantics |
| Choice card | radio card, checkbox card | Used for donation type (Zakat, Sadaqah, general) and post type; title plus one line of help |
| Select | native `<select>` | Native for speed and accessibility on low-end phones |
| Checkbox, switch | on, off, disabled | Switch only for instant settings such as "Make this trail public" |
| Language switch | in header | Shows the *other* language in its own script ("English" on Urdu pages, "اردو" on English pages), with `lang` set; keeps the same page path |
| Header | public, hub, admin | Logo and institute name from settings (REQ-PUB-007); menu button on phones |
| Bottom navigation | hub only, phones | 4 items: Class, Madrasa, New post, Me |
| Footer | public | Address and contact from settings, language switch repeated |
| Cause card | active, campaign ending, completed, closed | Pattern header (§14), title, Zakat badge, progress bar, raised and target, "Donate" |
| Progress bar | raised, spent | Fill from inline-start; text label always shown ("62% of Rs 200,000"); `role="progressbar"` with value text |
| Trail timeline | per donation | Vertical line on the inline-start side; one row per event with icon, word, date, amount; spent rows show the share and link to the spending entry |
| Donor wall row | named, anonymous | Amount, cause, date, name or "Anonymous" |
| Badge | Zakat eligible, verified, scope (class / madrasa / public), moderation state, role (teacher) | Word plus colour; never colour alone |
| Notice (inline alert) | info, success, warning, danger; translation missing | Translation-missing notice says which language is shown, with a link to the other |
| Toast | success, error | Announced with `aria-live="polite"`; stays 6 seconds; never the only place an error is shown |
| Dialog and bottom sheet | confirm, form | Bottom sheet on phones, centred dialog from `md`; focus trapped and returned |
| Tabs | 2 to 4 tabs | Scrolls sideways if needed, never wraps into two rows |
| Stepper | walkthrough, donation steps | "Step 2 of 5" in text, plus dots |
| Empty state | per list | Pattern tile, one sentence, one action |
| Skeleton | card, list row | Static blocks, no shimmer animation |
| Show more | lists | 20 items per load (PD-02-08) |
| Copy field | bank account, IBAN, reference | Value in `sunken` box, LTR isolated, "Copy" button with confirmation |
| Avatar | persona (preset pattern), teacher (initials or photo), donor (initials or photo) | Circle, 32, 40 or 64 px |
| Persona chip | name plus avatar | Name wrapped in `<bdi>` |
| Post card | message, question, answer, poll, article, video, vlog, audio, slides | Type icon and word, persona chip, scope badge, language tag if different from page |
| Poll | voting, voted, closed | Radio list; results as bars with numbers and percentages |
| Composer | reply, new post | Type picker, text, scope (fixed in replies), language picker defaulting to the page language |
| Report dialog | | Reason list, optional note, confirmation |
| Media frame | image, YouTube facade, audio, slides | §9 and §14 |
| Error summary | form | At top of form after submit, links to each field |

### Admin forms on phones (R-03)

The principal will record donations and spending on his phone. Admin forms are single-column, use the numeric keypad for amounts, default the date to today, remember the last cause and type used, keep the save button visible at the bottom of the screen, and confirm with a toast plus the new record at the top of the list. Tables become stacked cards under 960 px.

## 8. RTL and bilingual layout

### Direction

1. `/ur` pages render `<html lang="ur" dir="rtl">`; `/en` pages render `<html lang="en" dir="ltr">` (routing in [03 §7](03-architecture.md)).
2. All layout uses logical properties, so the whole page mirrors: navigation order, card layouts, form labels, the timeline line, progress fill and indentation of replies.
3. No component may use `left`, `right`, `margin-left`, `padding-right`, `text-align: left` and so on. A lint rule (P0-E4-T06) fails the build if it finds them outside an allow-list.

### What mirrors and what does not

| Mirrors in RTL | Stays the same |
| --- | --- |
| Back and forward arrows, chevrons in lists, breadcrumbs | Media controls (play, pause, seek bar direction) |
| "Send" icon in the composer | Checkmark, cross, clock, search, lock icons |
| Progress bars (fill from the right) | The logo and any image or photo |
| Timeline line side, reply indentation | Digits and amounts (always left to right inside) |
| Stepper order | Phone numbers, IBAN, emails, URLs, bank references |
| Bottom navigation order | Brand names written in Latin script |

Icons that mirror are marked in the icon set and flipped with `transform: scaleX(-1)` under `[dir=rtl]`.

### Mixed-direction text

The Unicode bidirectional algorithm handles most cases. These rules handle the rest:

| Content | Rule | Example on an Urdu page |
| --- | --- | --- |
| Amount | Component outputs the whole amount as one isolated unit | `5,000 روپے` |
| Date | Formatted by `Intl.DateTimeFormat("ur-PK")`, isolated | `12 نومبر 2026` |
| Persona names, donor names, teacher names | Always in `<bdi>` (direction from content) | `<bdi>Star Reader</bdi> نے سوال پوچھا` |
| Emails, URLs, IBAN, phone numbers, account numbers, receipt numbers | `<bdi dir="ltr">` and inputs with `dir="ltr"` | `+92 300 1234567` |
| Addresses with Latin parts | Isolated per line | `92/6-R Road, Sahiwal` |
| Reversal amounts | Minus sign inside the isolated amount | `−5,000 روپے` |
| User posts and replies | `dir="auto"` on the post body and textarea, and the post's recorded language (REQ-LNG-010, [07 §6](07-content-hub-student-teacher.md)) sets `lang` | An English post in the Urdu hub shows left aligned |
| Translation strings with placeholders | Placeholders are inserted as isolated spans, never by string joining | "{amount} of your donation bought {item}" |

Urdu strings use Urdu punctuation: full stop `۔`, comma `،`, question mark `؟`.

### Numbers, amounts and dates (REQ-LNG-012)

| | English | Urdu |
| --- | --- | --- |
| Amount | `Rs 25,000` | `25,000 روپے` |
| Large amount on a card | `Rs 6.6 million` is not used; always the full number `Rs 6,600,000` | `66,00,000` is not used; `6,600,000 روپے` |
| Date | `12 Nov 2026` | `12 نومبر 2026` |
| Date and time (admin, trail) | `12 Nov 2026, 3:40 pm` | `12 نومبر 2026، 3:40 بعد دوپہر` |
| Relative time in the hub | `2 hours ago` | `2 گھنٹے پہلے` |

All formatting goes through one formatting helper (P0-E4-T07), with snapshot tests for both languages. Overseas currency display comes later ([06 §16](06-donations-and-trail.md), REQ-PAY-005); the amount component already reserves a second line for it.

### Bilingual content rules

- Every interface string comes from the translation files (REQ-LNG-001, REQ-LNG-002, [03 §7](03-architecture.md)). Designers hand over strings as keys with both languages (§11 has the shared terms).
- Admin-written content shows the fallback notice when one language is missing (REQ-LNG-009): a `warning-soft` notice above the content, "This page is not yet available in Urdu. Showing English." The fallback content gets the correct `lang` and `dir`.
- Layouts must allow for Urdu text being about 20% taller and English about 30% wider. No fixed heights on text containers.
- The language switch is in the header on every page (REQ-LNG-003), including the walkthrough, the trail link page and the admin area.

## 9. Mobile and low-bandwidth

### Reference device and network

- **Device:** a low-end Android phone, 360 by 640 px viewport, 2 GB RAM, recent Chrome.
- **Network:** Chrome DevTools "Slow 3G" profile (about 400 kbps down, 400 ms round trip).
- **Target:** readable content within 5 seconds on that profile (REQ-PRF-001, D-026, proposed).

At about 50 KB per second with four round trips spent on connections, roughly 170 KB can arrive in 5 seconds. The budget below keeps the critical path under 150 KB.

### Page budgets (compressed bytes)

| Item | Public page | Hub page | Admin page |
| --- | --- | --- | --- |
| HTML | ≤ 30 KB | ≤ 30 KB | ≤ 40 KB |
| CSS (all, inlined critical part ≤ 14 KB) | ≤ 20 KB | ≤ 25 KB | ≤ 25 KB |
| Fonts on critical path | ≤ 90 KB (`/ur`), ≤ 30 KB (`/en`) | same | same |
| Logo | ≤ 8 KB | ≤ 8 KB | ≤ 8 KB |
| JavaScript (not render-blocking) | ≤ 100 KB | ≤ 180 KB | ≤ 220 KB |
| Images on first screen | ≤ 60 KB | ≤ 40 KB | 0 |
| **Total first load** | **≤ 300 KB** | **≤ 350 KB** | **≤ 400 KB** |

Public pages must show readable text and the donate button before JavaScript runs. Forms submit without JavaScript where the stack allows ([03 §4](03-architecture.md)).

### Images

The [source emblem](<../assets/logo/Markaz Al Azeem Emblem.png>) is about 3.1 MB. Serve resized variants. The local starter uses WebP exports at 96 px for the header and 192, 384 and 512 px for the hero. The smallest hero file is under 15 KB.

| Use | Display width | Widths generated | Budget per image | Loading |
| --- | --- | --- | --- | --- |
| Hero (when photos exist) | full width | 360, 720, 1080 | ≤ 60 KB at 720 | Eager, `fetchpriority="high"`, only one per page |
| Cause card header | 360 px | 360, 720 | ≤ 20 KB at 360 | Lazy |
| Image in a post or article | up to 720 px | 360, 720, 1080 | ≤ 80 KB at 720 | Lazy |
| Receipt or spending photo | thumbnail 96 px, full on tap | 96, 720, 1080 | thumbnail ≤ 5 KB, full ≤ 200 KB | Thumbnail lazy, full on tap only |
| Avatar | 32 to 64 px | 64, 128 | ≤ 4 KB | Lazy |
| YouTube poster (facade) | full width | 360, 720 | ≤ 25 KB | Lazy |

Rules: AVIF first, WebP second, JPEG fallback; `srcset` and `sizes` on every image; width and height attributes always set so nothing jumps; no images in CSS backgrounds except the tiny pattern SVGs. Processing and caps are in [03 §8](03-architecture.md) (REQ-PRF-002, REQ-PRF-003).

### Video and audio

- **YouTube first (REQ-PRF-004, D-020).** Videos show as a facade: the poster image, a play button and the duration. The YouTube player (several hundred KB) loads only when tapped.
- **Uploaded video** (only if [03 §8](03-architecture.md) and [07 §11](07-content-hub-student-teacher.md) allow it): encode to 480p at about 800 kbps H.264 with AAC audio, plus a 360p version; `preload="none"`; never autoplay; poster as above.
- **Audio:** mono, 48 to 64 kbps (AAC or Opus), `preload="none"`, size shown before play ("Audio, 4 min, 1.8 MB").
- **Slides:** shown as images one at a time with "Next" and "Previous", not as an embedded PDF viewer.

### Data saver

When the browser sends `Save-Data: on` or the user turns on "Use less data" in their settings:

- images below the first screen show as a placeholder with "Tap to load image (45 KB)";
- YouTube posters are replaced by a plain card with title and duration;
- Nastaliq headings are never fetched.

### Other low-end rules

- No carousels that move by themselves, no parallax, no animation longer than 200 ms, and none at all with `prefers-reduced-motion`.
- Icons are an inline SVG sprite, not an icon font.
- Lists show 20 items, then "Show more" (PD-02-08).
- Pages work at 320 px wide with no horizontal scroll.
- No third-party scripts on public or trail pages (no analytics tags, chat widgets or social embeds) except the YouTube player after a tap.

## 10. Accessibility

Target: WCAG 2.1 AA on every page in both languages.

| Requirement | How |
| --- | --- |
| REQ-ACC-001 contrast | Token pairs in §5, checked in code on every theme save (PD-02-05) and by an automated test on the gallery page (P0-E4-T03). |
| REQ-ACC-002 keyboard and screen reader | Native elements first (`button`, `a`, `select`, `input`); visible `focus` ring on every focusable element; logical tab order that follows the mirrored layout; skip link "Skip to content"; dialogs trap and return focus; every icon-only button has a label from the translation files; live regions for toasts and poll results. Tested with TalkBack on Android (both languages) and a desktop screen reader. |
| REQ-ACC-003 alt text in the page language | Every image stores alt text in Urdu and English (fields in `media_assets`, [04 §11](04-database.md)). Upload forms ask for alt text in the uploader's language and mark the other as "needs translation". Decorative patterns use `alt=""`. Persona avatars use the persona name as alt. |
| REQ-ACC-004 touch targets | 48 by 48 px minimum hit area for every control, 8 px apart. Inline links in text are exempt but get extra line height. |
| REQ-ACC-005 200% text | All sizes in `rem`; no fixed heights on text; layouts tested at 200% browser zoom and at Android's largest font setting, at 360 px width, in both languages. |
| Language of parts | `lang` and `dir` set on the page and on any block in the other language (fallback content, posts, names). |
| Errors | Error summary at the top of the form, error text next to each field, `aria-invalid` and `aria-describedby`; never colour alone. |
| Motion | Respect `prefers-reduced-motion`. No flashing. |
| Time limits | No time limits on forms. The walkthrough can be paused and resumed. |

## 11. Tone of voice

### Principles

1. **Dignified and warm.** Speak as a respected teacher would to a guest. Use آپ for everyone, including students.
2. **Plain and short.** One idea per sentence. Name the actual thing ("40 kg of wheat"), not abstractions ("resources").
3. **Honest, never pushy.** No guilt, no pressure, no false urgency, no countdown timers, no pictures of children used to raise money. A campaign shows its end date plainly.
4. **Grateful, not flattering.** Thank once, sincerely.
5. **Faith used with care.** Use religious phrases where they are natural (جزاک اللہ خیر after a donation) and spell them correctly. Do not quote verses for marketing.
6. **Safe for children.** In the hub, short sentences, friendly but not childish, and safety rules stated simply.
7. **Same meaning in both languages.** Urdu is not a word-for-word translation of English; it should read as if written in Urdu.

### Shared terms

These terms are used the same way in every string. The Urdu terms are proposals to be checked by a native Urdu-speaking staff member in P0-E4-T17.

| English (glossary term) | Urdu | Notes |
| --- | --- | --- |
| Donate / donation | عطیہ دیں / عطیہ | |
| Donor | عطیہ دہندہ | |
| Guest donor | مہمان عطیہ دہندہ | |
| Cause | مد | As in a budget head: "گندم کے ذخیرے کی مد" |
| All needs | تمام ضروریات | |
| Zakat / Sadaqah / General | زکوٰۃ / صدقہ / عام عطیہ | |
| Trail | عطیے کا سفر | Heading: "آپ کے عطیے کا سفر" |
| Received / Allocated / Spent / Reported | موصول / مختص / خرچ / رپورٹ شدہ | |
| Spending entry | خرچ کا اندراج | |
| Donor wall | عطیہ دہندگان کی فہرست | |
| Sponsor | کفیل | Traditional word for an orphan's sponsor |
| Persona | قلمی نام | "Pen name"; natural and friendly for students |
| Thread / Post | گفتگو / پوسٹ | |
| Question / Answer / Poll | سوال / جواب / رائے شماری | |
| Scope: class / madrasa / public | جماعت / پورا مدرسہ / سب کے لیے | Shown as "Who can see this" / "کون دیکھ سکتا ہے" |
| Verified article | مصدقہ مضمون | |
| Report (a post) | شکایت کریں | |

### Examples

| Situation | English | Urdu |
| --- | --- | --- |
| Main button | Donate | عطیہ دیں |
| Thank you after a recorded donation | JazakAllah khair. We have recorded your donation of Rs 5,000 for Wheat stock. | جزاک اللہ خیر۔ گندم کے ذخیرے کی مد میں آپ کا 5,000 روپے کا عطیہ درج ہو گیا ہے۔ |
| Trail, spent event | Rs 3,000 of your donation bought 40 kg of wheat on 12 Nov 2026. | آپ کے عطیے میں سے 3,000 روپے سے 12 نومبر 2026 کو 40 کلو گندم خریدی گئی۔ |
| Trail, not yet spent | Rs 2,000 is waiting to be spent. You will see it here when it is used. | 2,000 روپے ابھی خرچ ہونا باقی ہیں۔ جب یہ استعمال ہوں گے تو یہاں نظر آئیں گے۔ |
| Empty spending list | No spending recorded yet. When the madrasa spends from this cause, it will show here. | ابھی کوئی خرچ درج نہیں ہوا۔ جب مدرسہ اس مد سے خرچ کرے گا تو یہاں نظر آئے گا۔ |
| Zakat notice | This cause does not accept Zakat. Choose a Zakat-eligible cause, or give this as Sadaqah. | یہ مد زکوٰۃ قبول نہیں کرتی۔ زکوٰۃ کے لیے اہل کوئی مد منتخب کریں، یا یہ رقم صدقہ کے طور پر دیں۔ |
| Amount error | Please enter the amount in rupees, using numbers only. | براہ کرم رقم روپوں میں، صرف ہندسوں میں لکھیں۔ |
| Missing translation | This page is not yet available in Urdu. Showing English. | یہ صفحہ ابھی اردو میں دستیاب نہیں، اس لیے انگریزی میں دکھایا جا رہا ہے۔ |
| Persona intro (student) | This is your pen name. Other students see this name, not your real name. | یہ آپ کا قلمی نام ہے۔ دوسرے طلبہ آپ کا اصل نام نہیں، یہی نام دیکھتے ہیں۔ |
| Safety rule | Never write a phone number, email or home address. | کبھی بھی فون نمبر، ای میل یا گھر کا پتہ نہ لکھیں۔ |
| Contact detail blocked | This post seems to contain a phone number. Please remove it to post. | لگتا ہے اس پوسٹ میں فون نمبر ہے۔ پوسٹ کرنے کے لیے اسے ہٹا دیں۔ |
| Posted | Posted to your class. | آپ کی جماعت میں پوسٹ ہو گئی۔ |
| Waiting for approval | Sent for approval. Your teacher or the principal will review it. | منظوری کے لیے بھیج دیا گیا۔ آپ کے استاد یا مہتمم صاحب اس کا جائزہ لیں گے۔ |
| Verified mark | Verified by {teacher name} | تصدیق: {teacher name} |
| Sponsor, consent withdrawn | Some details about this child are no longer shown. You can still see updates. | اس بچے کی کچھ تفصیلات اب نہیں دکھائی جا رہیں۔ آپ اپ ڈیٹس اب بھی دیکھ سکتے ہیں۔ |

**Avoid:** "Only 2 days left!", "Children are starving", "Don't miss out", exclamation marks in Urdu, slang, emoji in interface text, English words in Urdu strings where an everyday Urdu word exists.

## 12. UX flows

Flows show screens and choices. The rules behind each step are owned by the linked documents. Every screen in every flow has the language switch, and every flow works at 360 px.

### 12.1 Donating by local bank transfer (Phase 1, now)

Online payment does not exist until P5 (D-008, D-025). A donor transfers money from their own bank and the admin records it (REQ-PAY-001, REQ-DON-008).

1. Donor taps **Donate** on the home page, a cause page or the header. Arriving from a cause page pre-selects that cause.
2. **Step 1 of 4, type.** Choice cards: *Zakat*, *Sadaqah*, *General*, each with one line of help. Default: none selected. If Zakat is chosen, go to flow 12.3 for the cause list (REQ-DON-004).
3. **Step 2 of 4, cause.** A list of open causes with progress, plus *All needs* at the top (REQ-DON-001, REQ-DON-002). Closed campaigns are not listed (REQ-DON-006).
4. **Step 3 of 4, amount.** Amount chips plus *Other*. The formatted amount shows below the field. Frequency: only *One-off* is offered while bank transfer is the only method; a checkbox offers "Email me a monthly reminder" (REQ-PAY-007, [06 §13](06-donations-and-trail.md)).
5. **Step 4 of 4, how to pay.** The institute's bank details from settings (REQ-PUB-008): account title, bank, account number, IBAN, and SWIFT code for overseas transfers, each in a copy field. A short **reference code** is shown to write in the transfer description.
6. Donor enters their **email** (the only required personal field, REQ-DPR-001) and chooses how the donation shows on the donor wall: *my name* (with a display name field) or *Anonymous* (default) (REQ-DPR-006).
7. Donor taps **I have made the transfer**. This sends a transfer notice to the admin (proposed REQ-DON-015, below). Without that requirement, step 7 is replaced by "Send the reference code and your email to the madrasa", with the contact details from settings.
8. Confirmation screen: "We will confirm your donation when it reaches our account, usually within {n} days. You will get an email with a private link to follow it." Link to read about the trail.
9. Admin matches the transfer on the bank statement and records the donation ([06 §4](06-donations-and-trail.md)). The donor gets the receipt email with the private trail link (REQ-DON-011, REQ-DPR-002) and continues in flow 12.2.

### 12.2 Donating from abroad (Phase 1 now, Phase 5 later)

- **Now:** same as 12.1. Step 5 highlights the IBAN and SWIFT code for international transfers and notes that the bank may charge fees.
- **Later (P5, open, [06 §16](06-donations-and-trail.md)):** step 4 adds a payment method choice (card; JazzCash and Easypaisa for local donors). Card enables *Monthly* and *Yearly* (REQ-DON-003, REQ-PAY-003). Amounts show in rupees with the donor's currency on a second line (REQ-PAY-005). Steps 5, 7 and 9 are replaced by the gateway's payment page and an automatic *received* event (REQ-PAY-006). Design of the P5 screens is planned when P5 is reached.

### 12.3 Choosing Zakat

1. In step 1 of 12.1, donor selects **Zakat**. Help text: "Zakat goes only to causes the madrasa has marked as Zakat-eligible."
2. Step 2 shows only causes with Zakat eligibility on, each with the *Zakat eligible* badge and, if set, "Approved by {scholar name}" (REQ-ROL-005, D-011, Q-04). *All needs* is replaced by *All Zakat-eligible needs* if [06 §6, §7](06-donations-and-trail.md) allow it.
3. If the donor arrived from a cause that does not accept Zakat, step 2 shows the Zakat notice (§11) with two buttons: *Choose another cause* and *Give as Sadaqah instead*.
4. Steps 3 to 9 continue as in 12.1. The confirmation, receipt and trail show a *Zakat* chip on the donation.
5. The trail later shows only Zakat-eligible spending for this donation (REQ-TRL-006). If an admin tries to allocate it elsewhere, the admin screen blocks it ([06 §6](06-donations-and-trail.md)).

### 12.4 Viewing your own trail

**As a guest (P1):**

1. Donor opens the private link from the receipt email (`/{lang}/trail/{token}`; the token is unguessable and contains no personal data, REQ-SEC-004, REQ-SEC-005).
2. The page shows a header "Your donation's trail", then one card per donation linked to that email: amount, date, type chip, cause.
3. Each card opens a **trail timeline**: *Received* (date, amount, bank reference ending), *Allocated* (to which cause, with amount, for all-needs splits), *Spent* rows (each with the share of this donation, the spending entry's description, date and receipt thumbnail), *Reported* (link to the report). The remaining unspent amount is shown at the bottom (REQ-TRL-001, REQ-TRL-007).
4. A switch "Make this trail public" is off by default (REQ-TRL-008, REQ-TRL-009). Turning it on asks for confirmation and shows the public link.
5. A panel offers "Create an account to keep all your donations in one place" (REQ-DPR-003). Dismissible.
6. The page has no third-party scripts and is marked `noindex`.

**With an account (P2):**

1. Donor logs in and opens **My donations** (REQ-DPR-010).
2. A list of donations, newest first, with totals per type, and receipt download links.
3. Tapping a donation opens the same timeline as above, with the same public switch.
4. Profile settings link: display name, photo, links (REQ-DPR-005) and the default name or anonymous choice for new donations.

### 12.5 Sponsoring an orphan (Phase 4)

1. Visitor opens the **Sponsor a child** page. It explains in plain words: one sponsor per child; you see the child's pen name, age and progress updates; more details only with the guardian's consent; no direct contact, messages go through the madrasa (D-017). No photos of children.
2. Visitor taps **Ask to sponsor**, logs in or creates a donor account (sponsorship needs an account; confirm in [06 §12](06-donations-and-trail.md)), and fills a short form: monthly amount intended, preferred language, optional note.
3. Confirmation: "The principal will match you with a child and email you."
4. Admin matches the sponsor to one orphan (REQ-ORP-001, admin screen in [05 §8](05-public-pages-roles-admin.md)).
5. Sponsor gets an email and sees a **sponsor card** in their account: persona avatar (preset pattern), pen name, age, and the updates list (REQ-ORP-002, REQ-ORP-008).
6. Sponsorship donations appear in **My donations** with the normal trail (REQ-ORP-009).
7. **Message the madrasa** opens a form addressed to the madrasa, not the child (REQ-ORP-007). Replies arrive by email and in the account.
8. When consent has both sign-offs (REQ-ORP-003, REQ-ORP-004), the sponsor card gains a "Full profile" section visible only to this sponsor (REQ-ORP-005).
9. If consent is withdrawn, the section disappears on the next page load and the neutral notice from §11 is shown (REQ-ORP-006).

### 12.6 Posting in a thread (student, Phase 3)

1. Student opens the hub; **Class** tab is the default and shows threads newest first.
2. Student opens a thread. The first post, then replies in order, each with persona chip, time and type.
3. Student taps the reply box at the bottom. The scope is shown, fixed to the thread's scope ("Your class can see this").
4. Student writes the reply. The language picker defaults to the page language (REQ-LNG-010). Text direction follows the content (`dir="auto"`).
5. Student taps **Post**. The contact-detail check runs (REQ-CHS-002, [07 §12](07-content-hub-student-teacher.md)). If it finds something, the reply is not posted and the message from §11 highlights the problem.
6. The reply appears at once at the bottom of the thread (REQ-MOD-001), with a toast "Posted to your class".
7. Every post has a **⋯** menu with **Report** (REQ-STU-011).

### 12.7 Creating a poll

1. Student or teacher taps **New post** and picks **Poll** (REQ-STU-007).
2. Fields: question (required), 2 to 6 options (start with 2, "Add option" up to 6), optional closing date, scope (*class* or *madrasa*, REQ-STU-008).
3. **Preview** shows the poll as others will see it.
4. **Post**. The contact-detail check runs on the question and options.
5. The poll appears in the feed. Voters pick one option and tap **Vote**. Results show as bars with counts and percentages after voting or after closing ([07 §6](07-content-hub-student-teacher.md) decides when results show).

### 12.8 Asking a question

1. Student taps **New post** and picks **Question**.
2. Fields: the question in one line (required), details (optional), scope (*class* default, or *madrasa*).
3. **Post**. The question appears at once with a *Question* badge.
4. Answers appear under it as *Answer* posts. Answers from teachers carry the *Teacher* badge and the teacher's real name ([07 §6, §10](07-content-hub-student-teacher.md)).
5. The asker gets a notification in the hub when an answer arrives.

### 12.9 A teacher turns a thread into a verified article (Phase 3)

1. Teacher opens a thread in their class and chooses **⋯ → Turn into verified article** (REQ-TCH-002).
2. **Step 1, choose posts.** All posts of the thread are listed with checkboxes. The teacher ticks the ones to use. Contributors are listed by persona.
3. **Step 2, edit.** An editor opens prefilled with the ticked posts in order. The teacher writes a title, a short summary, edits the body and sets the language. Contributors' personas are credited automatically.
4. **Step 3, verify.** The teacher confirms "I have checked this and it is authentic knowledge." The article gets the verified mark and "Verified by {teacher name}" (REQ-TCH-003).
5. **Step 4, who can see it.** *Class* or *madrasa* publishes at once. *Public* sends it to **submitted** (REQ-MOD-003, REQ-MOD-004).
6. For public: the approval screen (class teacher or principal) shows the article, the credited personas and a consent check. If any credited student has no consent record, approval is blocked with the student's persona named (REQ-CHS-005, [07 §5](07-content-hub-student-teacher.md)). Teacher-authored public work also goes through editor or admin review (REQ-TCH-004).
7. On approval the state moves to *approved*, then *published*, and the article appears on the student work page under personas (REQ-PUB-004) or the teacher work page (REQ-PUB-005), as [07 §9](07-content-hub-student-teacher.md) decides.
8. Each state change is shown to the teacher as a moderation badge on the article.

## 13. Onboarding walkthrough

### Student walkthrough (REQ-STU-010, epic P3-E7)

Shown on the student's first login, after any password step required by [03 §6](03-architecture.md). It is a full-screen stepper, one idea per screen, with **Next**, **Back** and **Skip for now**. Progress is saved after each step, so a student who closes the app resumes where they stopped. The student's onboarding progress is stored on the user record ([04 §7](04-database.md) defines the field). It can be replayed from **Me → Help → Show the walkthrough again**.

| Step | Screen | What the student does | Requirement |
| --- | --- | --- | --- |
| 1 | **Welcome.** Logo, "Welcome to {institute name}'s student hub." | Choose Urdu or English (two large buttons, each in its own script). | REQ-LNG-003 |
| 2 | **Your pen name.** "This is your pen name. Other students see this name, not your real name. Your teachers can see who you are, to keep everyone safe." Shows the persona created with the account. | Keep it, or type a new one (checked for contact details and full names; see proposed REQ-CHS-010), or tap "Suggest a name" for three suggestions. | REQ-STU-002, REQ-STU-003 |
| 3 | **Your picture.** A grid of 24 preset pattern avatars in theme colours. | Pick one. No photo upload (PD-02-06). | REQ-STU-002, REQ-CHS-001 |
| 4 | **About you.** Optional bio, 140 characters, with hint "Write about what you like learning. Do not write your real name, phone number or address." | Write or skip. Same check as step 2. | REQ-STU-002, REQ-CHS-002 |
| 5 | **Staying safe.** Four short rules with icons: be kind; never share phone, email or address; your teachers can see posts; use **Report** if something is wrong. | Tap "I understand". No consent step (D-016). | REQ-STU-011, REQ-CHS-003 |
| 6 | **Where your posts go.** A small diagram: *Class* (your class and teachers), *Madrasa* (everyone at the madrasa). "Posts become public only if a teacher or the principal approves." | Next. | REQ-STU-008, REQ-MOD-003 |
| 7 | **Try it.** "Say salaam to your class." A prefilled message the student can edit. | Post it, or skip. Posting uses flow 12.6. | REQ-STU-005 |
| 8 | **Done.** "You are ready." Shows the bottom navigation with a one-line label for each item. | Go to the class feed. | |

Design rules for the walkthrough:

- Each screen fits 360 by 640 px without scrolling at default text size, and scrolls cleanly at 200%.
- Illustrations are pattern tiles and line icons only (§14), under 3 KB per screen.
- The whole walkthrough, including its JavaScript, is under 40 KB extra.
- Text per screen is at most 30 words.
- If the student skipped step 2, 3 or 4, a small card on the class feed says "Finish your profile" until they do.

### Teacher walkthrough (short)

Shown on a teacher's first login. Four screens, each skippable: (1) welcome and language; (2) your classes and how to create student accounts (REQ-TCH-005, REQ-STU-001); (3) you can see the real student behind each pen name, and how to hide a post or handle a report (REQ-TCH-006, REQ-MOD-002, REQ-MOD-005); (4) turning a good thread into a verified article (REQ-TCH-002).

### Admin first-login checklist

Not a walkthrough but a checklist card on the admin home until done: check institute name and logo, add bank details, add contact details, create the first cause, create teacher accounts. Each item links to its admin screen ([05 §8](05-public-pages-roles-admin.md)).

Donors get no walkthrough. Inline help on the donate and trail pages is enough.

## 14. Media placeholders

The homepage gives approved campus photography and film a prominent place in both languages. A wide photograph leads the page, additional views form a gallery, and a captioned campus film plays on demand from a still poster. Use clear images with descriptive captions, responsive sizes and localized alt text. See [D-111](08-decision-log.md#d-111).

The local design preview uses clearly labelled and credited sample media from Wazir Khan Mosque in Lahore while Markaz Al Azeem's own material is prepared (Q-05). For an empty media configuration, the homepage pairs the institute introduction with a framed emblem.

### Placeholder kit

| Placeholder | Where | Design | Size |
| --- | --- | --- | --- |
| **Pattern tile** | Cause card header, hero, empty states, walkthrough | An 8-point star or girih pattern drawn as SVG, coloured from `primary-soft` and `primary` (or `primary` and `accent` on dark), generated from theme tokens, so another institute gets its own colours | ≤ 2 KB |
| **Cause icon** | On top of the pattern tile on cause cards and cause pages | Line icons at 2 px stroke: wheat, gas flame, cooking pot (lunch), clinic cross, book (education), building (construction), laptop (tech costs), heart-hand (all needs), star (orphan sponsorship). Admin picks the icon per cause | ≤ 1 KB each, in the sprite |
| **Hero without photo** | Home page | A navy frame with the selected emblem beside the institute introduction on paper | Responsive emblem WebP |
| **Persona avatar** | Hub | One of 24 presets: 12 patterns by 2 colourways from theme tokens | ≤ 2 KB each |
| **Initials avatar** | Teachers and donors without a photo | Initials (Latin) or first letter (Urdu) on `primary-soft`, text `primary` | 0 KB (CSS) |
| **Receipt placeholder** | Spending entry without a photo | Document icon and "No receipt photo" in `text-muted` | 0 KB |
| **Video** | Pages that will later have video | **No placeholder.** The video section is hidden until a video exists. Never an empty player | |
| **Gallery** | Home, facilities, daily life | Text-led sections with icons and facts. The gallery appears as soon as additional approved photos exist | |

### Replacing placeholders

- Each place that can hold a photo has a slot in the page spec ([05 §5](05-public-pages-roles-admin.md)) that stores a `media_assets` reference or nothing. Nothing means the placeholder.
- When the admin adds a photo, it replaces the pattern in the same frame size, so layouts do not change.
- Photos of the madrasa must follow the child-safety rules: no recognisable student faces without consent ([07 §11, §12](07-content-hub-student-teacher.md)).
- Placeholders are never captioned as if they were photos.

## Requirements covered

**Pointed to this document (02 §..) in the checklist:**

| Requirement | Section |
| --- | --- |
| REQ-STU-010 | §13 |
| REQ-PRF-001 | §6, §9 |
| REQ-ACC-001 | §5, §10 |
| REQ-ACC-002 | §7, §10 |
| REQ-ACC-003 | §10 |
| REQ-ACC-004 | §7, §10 |
| REQ-ACC-005 | §6, §10 |
| REQ-LNG-001 | §8, §11 |
| REQ-LNG-003 | §7, §8 |
| REQ-LNG-006 | §8 |
| REQ-LNG-007 | §8 |
| REQ-LNG-012 | §8 |
| REQ-MIR-005 | §5 |

**Supported here, owned elsewhere:** REQ-DON-001, REQ-DON-002, REQ-DON-003, REQ-DON-004, REQ-DON-006, REQ-DON-008, REQ-DON-011, REQ-TRL-001, REQ-TRL-006, REQ-TRL-007, REQ-TRL-008, REQ-TRL-009, REQ-TRL-010, REQ-DPR-001, REQ-DPR-002, REQ-DPR-003, REQ-DPR-005, REQ-DPR-006, REQ-DPR-007, REQ-DPR-008, REQ-DPR-010, REQ-ORP-001, REQ-ORP-002, REQ-ORP-003, REQ-ORP-005, REQ-ORP-006, REQ-ORP-007, REQ-ORP-008, REQ-ORP-009, REQ-STU-002, REQ-STU-003, REQ-STU-005, REQ-STU-006, REQ-STU-007, REQ-STU-008, REQ-STU-011, REQ-TCH-002, REQ-TCH-003, REQ-TCH-004, REQ-TCH-005, REQ-TCH-006, REQ-PUB-002, REQ-PUB-003, REQ-PUB-004, REQ-PUB-005, REQ-PUB-007, REQ-PUB-008, REQ-ROL-005, REQ-PAY-001, REQ-PAY-003, REQ-PAY-005, REQ-PAY-006, REQ-PAY-007, REQ-SEC-004, REQ-SEC-005, REQ-CHS-001, REQ-CHS-002, REQ-CHS-003, REQ-CHS-005, REQ-PRF-002, REQ-PRF-004, REQ-LNG-002, REQ-LNG-009, REQ-LNG-010, REQ-MOD-001, REQ-MOD-002, REQ-MOD-003, REQ-MOD-004, REQ-MOD-005, REQ-MIR-001.

## Tasks

### P0-E4 Design system: tokens, type, core components (owner: 02)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P0-E4-T01 | Define the `theme` settings shape (colour, font, radius tokens) and seed Markaz Al Azeem's Direction A values in `institute_settings` | done | P0-E2-T04 | REQ-MIR-005, REQ-MIR-001 |
| P0-E4-T02 | Load the theme by request domain and write tokens as inline CSS custom properties on `<html>` | todo | P0-E4-T01, P0-E1 | REQ-MIR-005, REQ-MIR-002 |
| P0-E4-T03 | Theme contrast check: refuse saving a theme that fails a §5 pair; automated test over Direction A and B values | todo | P0-E4-T01 | REQ-ACC-001, REQ-MIR-005 |
| P0-E4-T04 | Font pipeline: subset and self-host Noto Naskh Arabic, Source Serif 4 and Noto Nastaliq Urdu; `local()`, preload and `font-display` rules; measure sizes; run shaping test strings | todo | P0-E1 | REQ-PRF-001, REQ-LNG-006 |
| P0-E4-T05 | Type scale and base text styles for `/ur` and `/en`, in `rem`, with size-adjusted fallback faces | todo | P0-E4-T02, P0-E4-T04 | REQ-LNG-006, REQ-ACC-005 |
| P0-E4-T06 | Spacing tokens, breakpoints, grid, logical-property base CSS, icon mirroring, and a lint rule against physical left/right properties | todo | P0-E4-T02, P0-E3-T04 | REQ-LNG-006 |
| P0-E4-T07 | Formatting and bidi helpers: amount, date, date-time, relative time, isolated names and LTR values, with snapshot tests in both languages | todo | P0-E4-T06, P0-E3-T04 | REQ-LNG-007, REQ-LNG-012 |
| P0-E4-T08 | Buttons, links, text fields, amount field, choice cards, select, checkbox, switch, error summary | todo | P0-E4-T05, P0-E4-T06 | REQ-ACC-002, REQ-ACC-004 |
| P0-E4-T09 | Header, footer, language switch and logo slot from institute settings; optimised logo exports (48 to 512 px) | todo | P0-E4-T08, P0-E3-T04 | REQ-LNG-003, REQ-PUB-007 |
| P0-E4-T10 | Feedback components: notice (incl. translation-missing), toast, empty state, skeleton, "Show more" | todo | P0-E4-T08 | REQ-LNG-009, REQ-ACC-002 |
| P0-E4-T11 | Badges, progress bar, cause card, avatar and persona chip, copy field | todo | P0-E4-T08, P0-E4-T07 | REQ-PUB-002, REQ-ACC-001 |
| P0-E4-T12 | Placeholder kit: SVG pattern generator from tokens, cause icon sprite, 24 persona avatar presets, initials avatar | todo | P0-E4-T02 | REQ-CHS-001, REQ-MIR-005 |
| P0-E4-T13 | Dialog, bottom sheet, tabs and stepper with focus management | todo | P0-E4-T08 | REQ-ACC-002 |
| P0-E4-T14 | Media frame: responsive image with `srcset`, YouTube facade, audio player, data-saver "tap to load" | todo | P0-E4-T12, P0-E1 | REQ-PRF-002, REQ-PRF-004 |
| P0-E4-T15 | Component gallery pages at `/ur/_design` and `/en/_design` (admin only), with keyboard, screen reader, 200% zoom and 320 px checks | todo | P0-E4-T08, P0-E4-T09, P0-E4-T10, P0-E4-T11, P0-E4-T12, P0-E4-T13, P0-E4-T14 | REQ-ACC-002, REQ-ACC-003, REQ-ACC-004, REQ-ACC-005 |
| P0-E4-T16 | Page-weight budget check in CI (HTML, CSS, JS, fonts) and a manual slow-3G test script for the 5-second target | todo | P0-E4-T04, P0-E4-T15 | REQ-PRF-001 |
| P0-E4-T17 | Shared terms and tone: seed the §11 glossary and example strings into the translation files; native Urdu review by a staff member | todo | P0-E3-T03 | REQ-LNG-001 |

2026-11-09 · P0-E4-T01: [`packages/core/src/theme.ts`](../packages/core/src/theme.ts) defines the theme shape (`version`, `direction`, `color`, `font` from the hosted list, `radius`) with Direction A and B values. A test confirms that the Markaz Al Azeem seed stores Direction A. [`0018_theme_shape.sql`](../db/drizzle/0018_theme_shape.sql) adds `app.valid_theme()`, which lets the database accept only listed names and `#RRGGBB` colours. An empty theme means the platform default ([D-117](08-decision-log.md#d-117)). P0-E4-T03: `checkTheme()` returns every shape problem and every failing §5 pair by name, using each direction's own pairs. The test recomputes every ratio in §5 for both directions, and all match to within 0.01. No screen saves a theme yet. When P1-E5-T03 adds theme editing, it must refuse a save that `checkTheme()` rejects.

### P3-E7 Onboarding walkthrough (owner: 02)

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P3-E7-T01 | Final Urdu and English copy for the student walkthrough (8 steps) and the teacher walkthrough (4 steps), reviewed by a teacher | todo | P0-E4-T17 | REQ-STU-010, REQ-LNG-001 |
| P3-E7-T02 | Onboarding progress on the user record: save after each step, resume, skip, and replay from Help | todo | P3-E1 | REQ-STU-010 |
| P3-E7-T03 | Student walkthrough steps 1 to 4: welcome and language, pen name with suggestions, avatar picker, bio | todo | P3-E7-T01, P3-E7-T02, P0-E4-T13, P0-E4-T12 | REQ-STU-010, REQ-STU-002, REQ-STU-003 |
| P3-E7-T04 | Pen name and bio check: block contact details and flag full real names, with the messages from §11 | todo | P3-E1 | REQ-CHS-001, REQ-CHS-002 |
| P3-E7-T05 | Student walkthrough steps 5 to 8: safety rules, scopes diagram, first post, done; "Finish your profile" card | todo | P3-E7-T03, P3-E3 | REQ-STU-010, REQ-STU-008, REQ-STU-011 |
| P3-E7-T06 | Teacher walkthrough (4 screens) and admin first-login checklist card | todo | P3-E7-T01, P3-E7-T02, P1-E5 | REQ-STU-010, REQ-TCH-005, REQ-TCH-006 |
| P3-E7-T07 | Test the walkthroughs on the reference phone in both languages: 360 px, 200% text, TalkBack, slow 3G, under 40 KB extra | todo | P3-E7-T05, P3-E7-T06 | REQ-STU-010, REQ-ACC-002, REQ-ACC-005 |

### Design tasks inside epics owned by other documents

| Task | Title | Status | Depends on | Requirements |
| --- | --- | --- | --- | --- |
| P1-E1-T20 | Home page and cause page layouts with placeholder hero and cause cards | todo | P0-E4-T11, P0-E4-T12 | REQ-PUB-002, REQ-PUB-003 |
| P1-E1-T21 | Donate flow screens (type, cause, amount, bank details with copy fields and reference code, email and name choice, confirmation) | todo | P0-E4-T08, P0-E4-T11 | REQ-DON-001, REQ-DON-002, REQ-PUB-008, REQ-DPR-001, REQ-DPR-006 |
| P1-E4-T20 | Trail timeline component and the guest trail page layout, with the public switch | todo | P0-E4-T11, P0-E4-T07 | REQ-TRL-007, REQ-TRL-008, REQ-TRL-009, REQ-DPR-002 |
| P2-E3-T20 | Zakat choice screens: filtered cause list, scholar line, not-eligible notice | todo | P1-E1-T21 | REQ-DON-004, REQ-TRL-006, REQ-ROL-005 |
| P2-E5-T20 | Donor wall rows and "My donations" list designs, named and anonymous | todo | P0-E4-T11 | REQ-DPR-007, REQ-DPR-008, REQ-DPR-010 |
| P3-E3-T20 | Post card for each post type, thread view, composer and report dialog | todo | P0-E4-T08, P0-E4-T11 | REQ-STU-005, REQ-STU-006, REQ-STU-011, REQ-LNG-010 |
| P3-E3-T21 | Poll creation and voting screens, and question and answer layouts | todo | P3-E3-T20 | REQ-STU-007 |
| P3-E6-T20 | "Turn into verified article" screens (choose posts, edit, verify, scope) and the verified article page | todo | P3-E3-T20 | REQ-TCH-002, REQ-TCH-003, REQ-MOD-004 |
| P4-E1-T20 | Sponsor page, sponsor card, updates list, message form and consent-gated full profile section | todo | P0-E4-T11, P0-E4-T12 | REQ-ORP-002, REQ-ORP-003, REQ-ORP-006, REQ-ORP-007 |

## Acceptance criteria

1. Changing a colour in Markaz Al Azeem's `theme` setting changes it on every page without a code change or deploy; searching the code finds no colour hex values outside seed data and tests.
2. Trying to save a theme whose `text-muted` on `bg` is below 4.5:1 is refused, with the failing pair named.
3. Every pair in the §5 Direction A table passes in the automated contrast test.
4. `/ur` pages render right to left with mirrored navigation, timeline and progress bars; `/en` pages left to right; the lint rule finds no physical left/right properties.
5. On an Urdu page, `5,000 روپے`, `12 نومبر 2026`, an English persona name, an IBAN and a phone number all display in the correct order (snapshot tests pass).
6. On the reference phone and slow-3G profile, the home page in both languages shows readable text and the donate button within 5 seconds, and the CI budget check passes.
7. On an Android phone with Noto Naskh Arabic installed, an Urdu page downloads no Naskh font file; on a desktop without it, the subset file is under 90 KB.
8. Nastaliq is never requested when `Save-Data: on` is sent, and its absence causes no layout shift.
9. Every component on the gallery page can be reached and used with a keyboard, is announced correctly by TalkBack in both languages, has touch targets of at least 48 px, and works at 200% text and 320 px width.
10. A new student completes the 8-step walkthrough in Urdu on the reference phone, closes the app at step 3 and resumes at step 3, sets a pen name and avatar, and posts a first message to the class.
11. A pen name or bio containing a phone number is refused with the §11 message.
12. Every flow in §12 can be walked through on the gallery or staging site in both languages using the copy from §11.
13. With no photos uploaded, the home, cause, facilities and daily-life pages show pattern and icon placeholders, no empty video frames, and no stock or generated photos.
14. The served logo in the header is under 15 KB.

### Proposed requirements

These are not approved. Do not build on them until they are added to [01](01-requirements-checklist.md) with an open question in [00 §6](00-MASTER-PLAN.md#open-questions).

- [ ] REQ-DON-015 (proposed) Donor can send a bank-transfer notice with amount, transfer date, reference code, email, cause or all needs, type and name display choice, which the admin confirms against the bank statement before the donation is recorded. SHOULD → 06 §4
- [ ] REQ-CHS-010 (proposed) A persona's display name and bio are checked for phone numbers, email addresses, street addresses and full real names before they are saved. MUST → 07 §12
- [ ] REQ-ACC-006 (proposed) Theme colours that fail the WCAG AA contrast pairs cannot be saved in institute settings. MUST → 02 §5
- [ ] REQ-PRF-006 (proposed) Images and video posters below the first screen load only when scrolled into view, and only on tap when the browser asks to save data. SHOULD → 02 §9
