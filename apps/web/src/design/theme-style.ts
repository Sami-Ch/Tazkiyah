import { nightAndPaper, type Theme } from "@tazkiyah/core/theme";
import type { CSSProperties } from "react";

type ThemeVars = CSSProperties & Record<`--${string}`, string>;

/**
 * Writes an institute theme as CSS custom properties (02 §5, P0-E4-T02).
 * Components use the `--color-*` names. The older public-page names stay as
 * aliases so existing screens keep the same colours.
 */
export function themeStyle(theme: Theme = nightAndPaper): ThemeVars {
  const color = theme.color;
  const style: ThemeVars = {
    "--color-bg": color.bg,
    "--color-surface": color.surface,
    "--color-sunken": color.sunken,
    "--color-text": color.text,
    "--color-text-muted": color["text-muted"],
    "--color-text-disabled": color["text-disabled"],
    "--color-primary": color.primary,
    "--color-primary-hover": color["primary-hover"],
    "--color-on-primary": color["on-primary"],
    "--color-on-primary-muted": color["on-primary-muted"],
    "--color-primary-soft": color["primary-soft"],
    "--color-accent": color.accent,
    "--color-link": color.link,
    "--color-border": color.border,
    "--color-border-strong": color["border-strong"],
    "--color-focus": color.focus,
    "--color-success": color.success,
    "--color-success-soft": color["success-soft"],
    "--color-warning": color.warning,
    "--color-warning-soft": color["warning-soft"],
    "--color-danger": color.danger,
    "--color-danger-soft": color["danger-soft"],
    "--color-info": color.info,
    "--color-info-soft": color["info-soft"],
    "--color-zakat": color.zakat,
    "--color-zakat-soft": color["zakat-soft"],
    "--color-verified": color.verified,
    "--color-verified-soft": color["verified-soft"],
    "--color-verified-on-primary": color["verified-on-primary"],
    "--radius-sm": `${theme.radius.sm}px`,
    "--radius-md": `${theme.radius.md}px`,
    "--radius-lg": `${theme.radius.lg}px`,
    "--paper": color.bg,
    "--surface": color.surface,
    "--text": color.text,
    "--muted": color["text-muted"],
    "--navy": color.primary,
    "--navy-hover": color["primary-hover"],
    "--on-navy": color["on-primary"],
    "--on-navy-muted": color["on-primary-muted"],
    "--navy-soft": color["primary-soft"],
    "--silver-blue": color.accent,
    "--border": color.border,
    "--focus": color.focus,
  };
  return style;
}
