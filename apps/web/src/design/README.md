# Public design system

Shared by the public site. Staff and donor screens can import the same pieces from `@/design/ui` and `@/design/format`.

Direction A, **Night and Paper**, is the Markaz Al Azeem theme (`packages/core/src/theme.ts`). `themeStyle()` writes it onto `<html>` as `--color-*` custom properties. Do not put hex colours in components. Gradients, glows and shadows are mixed from those tokens with `color-mix()`; see plan 02 §4.1 for the premium rules (photography, depth, motion, type) that replaced the earlier bans.

## Use

| Piece | Import | Notes |
| --- | --- | --- |
| Buttons, fields, badges, alerts, empty states, skeletons, tables, progress | `@/design/ui` | Labels come from the translation files. Touch targets are at least 48px. |
| Modal | `@/design/modal` | Native `<dialog>`. |
| Amounts and dates | `@/design/format` | `Rs 25,000` / `25,000 روپے`, Western digits, `12 Nov 2026` / `12 نومبر 2026`. |
| Lists | `@/design/paging` | 20 rows, then a Show more link. |
| Theme | `@/design/theme-style` | Pass an institute `Theme`. Invalid themes fall back before they are applied. |

Layout uses logical CSS (`margin-inline`, `text-align: start`). A test fails the build if a stylesheet uses physical `left` or `right`. Urdu pages set `dir="rtl"` on `<html>`.

## Type

- English body: the system sans. English headings: Source Serif 4.
- Urdu body and interface: self-hosted Noto Naskh Arabic.
- Urdu `h1` and `h2`: Noto Nastaliq Urdu only when the phone already has it (`local()`, `font-display: optional`). The full Nastaliq file is too large for a 3G first load, so it is not downloaded. Naskh is the fallback and keeps the Nastaliq line height so the page does not jump.

## Gallery

`/{locale}/design` renders the components. It is `noindex`. It is a reference for builders, not a public page.

## Not in this folder

Donate, account, and staff forms keep their own screens. They should adopt these components when those areas are next edited, instead of growing a second button style.
