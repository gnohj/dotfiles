import { palette, type ThemePalette } from "./theme";

const styleId = "gnohj-theme";

const ink = (percent: number) =>
  `color-mix(in srgb, var(--gnohj-text) ${percent}%, transparent)`;
const tint = (signal: string, percent: number) =>
  `color-mix(in srgb, var(${signal}) ${percent}%, transparent)`;
const shade = (percent: number) =>
  `color-mix(in oklab, var(--gnohj-background), var(--gnohj-text) ${percent}%)`;

function themeCss(colors: ThemePalette): string {
  const variables: Record<string, string> = {
    "--gnohj-background": colors.background,
    "--gnohj-text": colors.text,
    "--bg-void": "color-mix(in oklab, var(--gnohj-background) 70%, black)",
    "--bg-stage": "var(--gnohj-background)",
    "--bg-surface": shade(3),
    "--bg-elevated": shade(6),
    "--bg-pressed": shade(9),
    "--ink-100": ink(96),
    "--ink-200": ink(86),
    "--ink-300": ink(65),
    "--ink-400": ink(48),
    "--ink-500": ink(34),
    "--ink-600": ink(22),
    "--ink-700": ink(12),
    "--ink-800": ink(7),
    "--ink-900": ink(4),
    "--signal-live": colors.live,
    "--signal-pending": colors.warn,
    "--signal-error": colors.danger,
    "--signal-live-glow": `0 0 6px ${tint("--signal-live", 65)}`,
    "--signal-pending-glow": `0 0 6px ${tint("--signal-pending", 55)}`,
    "--signal-error-glow": `0 0 6px ${tint("--signal-error", 55)}`,
    "--signal-live-tint": tint("--signal-live", 10),
    "--signal-pending-tint": tint("--signal-pending", 10),
    "--signal-error-tint": tint("--signal-error", 10),
    "--focus-ring": `0 0 0 1px ${tint("--signal-live", 50)}, 0 0 0 4px ${tint("--signal-live", 18)}`,
    "--shadow-inset": `inset 0 0.5px 0 ${ink(6)}`,
    "--color-void": "var(--bg-void)",
    "--color-stage": "var(--bg-stage)",
    "--color-surface": "var(--bg-surface)",
    "--color-elevated": "var(--bg-elevated)",
    "--color-pressed": "var(--bg-pressed)",
    "--color-ink-strong": "var(--ink-100)",
    "--color-ink": "var(--ink-200)",
    "--color-ink-muted": "var(--ink-300)",
    "--color-ink-soft": "var(--ink-400)",
    "--color-ink-label": "var(--ink-500)",
    "--color-ink-faint": "var(--ink-600)",
    "--color-line": "var(--ink-700)",
    "--color-line-faint": "var(--ink-800)",
    "--color-signal-live": "var(--signal-live)",
    "--color-signal-warn": "var(--signal-pending)",
    "--color-signal-danger": "var(--signal-error)",
  };
  const declarations = Object.entries(variables)
    .map(([name, value]) => `${name}: ${value};`)
    .join("\n");
  return `:root:root {\n${declarations}\n}\n::selection { background: ${tint("--signal-live", 25)}; }`;
}

export function applyHostTheme(): void {
  if (typeof document === "undefined") return;
  const existing = document.getElementById(styleId);
  if (!palette) {
    existing?.remove();
    return;
  }
  const css = themeCss(palette);
  if (existing?.textContent === css && !existing.nextElementSibling) return;
  const style = existing ?? document.createElement("style");
  style.id = styleId;
  style.textContent = css;
  document.head.append(style);
}
