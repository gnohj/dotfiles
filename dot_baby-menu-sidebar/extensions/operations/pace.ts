import type {
  QuotaAvailability,
  QuotaPace,
  QuotaProvider,
  QuotaRunway,
  QuotaWindow,
} from "./types";

// Display rules ported from quota-axi's --tui (dist/src/tui.js) so these cards read the same as that report.

export type Health = "ok" | "warn" | "crit";

export function health(percentRemaining: number): Health {
  if (percentRemaining >= 50) return "ok";
  if (percentRemaining >= 20) return "warn";
  return "crit";
}

export function formatCountdown(seconds: number): string {
  if (!Number.isFinite(seconds)) return "";
  if (seconds <= 0) return "now";
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return minutes > 0 ? `${minutes}m` : "<1m";
}

export function resetCountdown(
  window: QuotaWindow,
  generatedAtMs: number,
): string {
  if (window.resetsAt !== undefined) {
    const resetMs = Date.parse(window.resetsAt);
    if (Number.isFinite(resetMs) && Number.isFinite(generatedAtMs)) {
      return formatCountdown((resetMs - generatedAtMs) / 1000);
    }
  }
  return window.resetText ?? "";
}

export function shortWindowLabel(window: QuotaWindow): string {
  const tokens = window.label.split(/[\s_]+/).filter(Boolean);
  if (
    tokens.length > 1 &&
    /^(week|window|day|month|session|usage|quota)$/i.test(tokens.at(-1) ?? "")
  ) {
    tokens.pop();
  }
  let label = tokens.join(" ").toLowerCase();
  if (label.length > 7 && label.includes("-")) {
    label = label.slice(label.lastIndexOf("-") + 1);
  }
  return label || window.id;
}

export function pickHeadline(
  provider: QuotaProvider,
): QuotaAvailability | undefined {
  const availability = provider.quotaSemantics?.effectiveAvailability ?? [];
  return (
    availability.find(
      (entry) => entry.scope.startsWith("all_") && entry.status === "known",
    ) ??
    availability.find((entry) => entry.status === "known") ??
    availability[0]
  );
}

export function headlineLabel(
  provider: QuotaProvider,
  headline: QuotaAvailability | undefined,
): string {
  const ids = headline?.limitingWindowIds ?? [];
  const names = ids
    .map((id) => provider.windows.find((window) => window.id === id)?.label)
    .filter((label): label is string => Boolean(label))
    .map((label) => label.toLowerCase());
  const scope = headline?.scope;
  if (names.length === 0 || names.length !== ids.length) {
    return scope === undefined
      ? "unknown scope"
      : scope.replace(/^all_/, "all ").replace(/_/g, " ");
  }
  const suffix =
    scope !== undefined && !scope.startsWith("all_")
      ? ` · ${scope
          .replace(/^(?:model|product):/, "")
          .replace(/_/g, " ")
          .toLowerCase()}`
      : "";
  return `${names.join(" + ")}${suffix}`;
}

export function headlineMarker(
  provider: QuotaProvider,
  headline: QuotaAvailability | undefined,
): number | undefined {
  const limitingId = headline?.limitingWindowIds?.[0];
  if (limitingId === undefined) return undefined;
  return provider.windows.find((window) => window.id === limitingId)?.pace
    ?.timeRemainingPercent;
}

export type Verdict = {
  text: string;
  tone: "dim" | "ok" | "warn" | "crit";
  mark?: string;
};

export function runwayVerdict(
  headline: QuotaAvailability | undefined,
): Verdict {
  const runway = headline?.runway;
  if (!runway || runway.status === "unknown")
    return { text: "runway unknown", tone: "dim" };
  if (runway.status === "through_reset")
    return { text: "on pace", tone: "ok", mark: "✓" };
  if (runway.status === "exhausted_now")
    return { text: "✗ exhausted now", tone: "crit" };
  const seconds = runway.usableRunwaySeconds;
  return {
    text:
      seconds === undefined
        ? "exhaustion projected"
        : `empty in ${formatCountdown(seconds)}`,
    tone: "warn",
  };
}

export function creditsLine(provider: QuotaProvider): string | undefined {
  if (provider.windows.length > 0 || !provider.credits) return undefined;
  const { unlimited, remaining, unit } = provider.credits;
  if (unlimited === true) return "unlimited";
  return remaining === undefined
    ? undefined
    : `${remaining} ${unit ?? "credits"} remaining`;
}

export function cardNotes(provider: QuotaProvider): string[] {
  const notes: string[] = [];
  const { state } = provider;
  if (state.status === "stale") {
    if (state.refreshedAt) notes.push(`last refreshed ${state.refreshedAt}`);
    if (state.error) notes.push(state.error.replace(/_/g, " "));
    if (state.reason) notes.push(`reason ${state.reason.replace(/_/g, " ")}`);
  }
  if (state.retryAfter) notes.push(`retry after ${state.retryAfter}`);
  if (state.remedyCommand) notes.push(`run: ${state.remedyCommand}`);
  return notes;
}

// Pace and runway rules ported from quota-axi's dist/src/pace.js, for the Claude cards it cannot read.

const EARLY_ELAPSED_PERCENT = 10;

export function windowPace(
  window: QuotaWindow,
  generatedAtMs: number,
): QuotaPace | undefined {
  const remaining = window.percentRemaining;
  const resetMs = window.resetsAt ? Date.parse(window.resetsAt) : NaN;
  const cycleMs = (window.windowSeconds ?? 0) * 1000;
  if (remaining === undefined || !Number.isFinite(resetMs) || cycleMs <= 0)
    return undefined;
  const remainingMs = resetMs - generatedAtMs;
  const elapsedMs = cycleMs - remainingMs;
  const used = 100 - remaining;
  const pace: QuotaPace = {
    timeRemainingPercent: (100 * remainingMs) / cycleMs,
    elapsedPercent: (100 * elapsedMs) / cycleMs,
  };
  if (used > 0 && elapsedMs > 0) {
    pace.projectedExhaustedAt = new Date(
      generatedAtMs + remaining / (used / elapsedMs),
    ).toISOString();
    pace.projectionConfidence =
      (pace.elapsedPercent ?? 0) < EARLY_ELAPSED_PERCENT
        ? "early"
        : "established";
  }
  return pace;
}

export function effectiveRunway(
  windows: QuotaWindow[],
  generatedAtMs: number,
): QuotaRunway {
  if (windows.some((window) => window.percentRemaining === 0)) {
    return { status: "exhausted_now", usableRunwaySeconds: 0 };
  }
  let earliest: number | undefined;
  for (const window of windows) {
    const remaining = window.percentRemaining;
    const resetMs = window.resetsAt ? Date.parse(window.resetsAt) : NaN;
    if (remaining === 100) continue;
    if (
      remaining === undefined ||
      !Number.isFinite(resetMs) ||
      resetMs <= generatedAtMs
    ) {
      return { status: "unknown" };
    }
    const exhaustedMs = window.pace?.projectedExhaustedAt
      ? Date.parse(window.pace.projectedExhaustedAt)
      : NaN;
    if (!Number.isFinite(exhaustedMs) || exhaustedMs <= generatedAtMs)
      return { status: "unknown" };
    if (
      exhaustedMs < resetMs &&
      (earliest === undefined || exhaustedMs < earliest)
    )
      earliest = exhaustedMs;
  }
  if (earliest === undefined) return { status: "through_reset" };
  return {
    status: "projected_exhaustion",
    usableRunwaySeconds: Math.max(
      0,
      Math.round((earliest - generatedAtMs) / 1000),
    ),
  };
}

export function effectiveAvailability(
  windows: QuotaWindow[],
  generatedAtMs: number,
): QuotaAvailability {
  const measured = windows.filter(
    (window) => window.percentRemaining !== undefined,
  );
  if (measured.length === 0) return { scope: "all_models", status: "unknown" };
  const lowest = Math.min(
    ...measured.map((window) => window.percentRemaining ?? 100),
  );
  return {
    scope: "all_models",
    status: "known",
    effectivePercentRemaining: lowest,
    limitingWindowIds: measured
      .filter((window) => window.percentRemaining === lowest)
      .map((window) => window.id),
    runway: effectiveRunway(measured, generatedAtMs),
  };
}
