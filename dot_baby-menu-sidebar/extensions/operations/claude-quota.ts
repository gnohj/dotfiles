import { effectiveAvailability, windowPace } from "./pace";
import type { QuotaProvider, QuotaWindow } from "./types";

export type ClaudeAccount = "personal" | "work";
export type Captures = Map<string, { value: string; mtimeMs: number }>;
export type DesktopSample = { t: number; u?: { fh?: number; sd?: number } };

const CLAUDE_WINDOWS = [
  { id: "five_hour", label: "session", windowSeconds: 5 * 3600 },
  { id: "seven_day", label: "week", windowSeconds: 7 * 86400 },
] as const;
const MAX_FRESH_AGE_MS = 5 * 60 * 1000;

type Reading = { window: QuotaWindow; refreshedAtMs: number };

function claudeCard(
  account: ClaudeAccount,
  source: string,
  readings: Reading[],
  generatedAtMs: number,
  forceStale = false,
): QuotaProvider | undefined {
  if (!readings.length) return undefined;
  const refreshedAtMs = Math.min(...readings.map((r) => r.refreshedAtMs));
  if (!Number.isFinite(refreshedAtMs) || refreshedAtMs <= 0) return undefined;
  const windows: QuotaWindow[] = readings.map(
    ({ window, refreshedAtMs: observedAtMs }) => {
      const age = generatedAtMs - observedAtMs;
      const resetMs = window.resetsAt ? Date.parse(window.resetsAt) : NaN;
      const expired = Number.isFinite(resetMs) && resetMs <= generatedAtMs;
      const unknown =
        expired ||
        age < 0 ||
        (!Number.isFinite(resetMs) &&
          age >= (window.windowSeconds ?? 0) * 1000);
      return {
        ...window,
        percentUsed: unknown ? undefined : window.percentUsed,
        percentRemaining: unknown ? undefined : window.percentRemaining,
        resetsAt: expired ? undefined : window.resetsAt,
        resetText: expired ? "expired" : window.resetText,
        pace: undefined,
      };
    },
  );
  const stale =
    forceStale ||
    generatedAtMs - refreshedAtMs >= MAX_FRESH_AGE_MS ||
    generatedAtMs < refreshedAtMs ||
    windows.length < CLAUDE_WINDOWS.length ||
    windows.some((window) => window.percentRemaining === undefined);
  for (const window of windows)
    window.pace = stale ? undefined : windowPace(window, generatedAtMs);
  const availability = stale
    ? { scope: "all_models", status: "unknown" }
    : effectiveAvailability(windows, generatedAtMs);
  return {
    provider: "claude",
    accountKey: account,
    source,
    windows,
    state: {
      status: stale ? "stale" : "fresh",
      refreshedAt: new Date(refreshedAtMs).toISOString(),
    },
    quotaSemantics: {
      status: availability.status,
      effectiveAvailability: [availability],
    },
  };
}

function capturedReset(
  captures: Captures,
  account: ClaudeAccount,
  window: string,
): string | undefined {
  const epoch = Number(
    captures.get(`claude_reset_${account}_${window}`)?.value,
  );
  return Number.isFinite(epoch) && epoch > 0 && epoch < 8.64e12
    ? new Date(epoch * 1000).toISOString()
    : undefined;
}

// claude-usage-pct and claude-usage-reset persist the statusline's rate_limits per account, the one live source quota-axi lacks for either login.
export function claudeFromStatusline(
  captures: Captures,
  account: ClaudeAccount,
  generatedAtMs: number,
): QuotaProvider | undefined {
  const readings: Reading[] = [];
  for (const spec of CLAUDE_WINDOWS) {
    const capture = captures.get(`claude_pct_${account}_${spec.id}`);
    if (!capture) continue;
    const used = Number(capture.value);
    if (!Number.isFinite(used) || used < 0 || used > 100) continue;
    readings.push({
      refreshedAtMs: capture.mtimeMs,
      window: {
        ...spec,
        percentUsed: used,
        percentRemaining: Math.round((100 - used) * 10) / 10,
        resetsAt: capturedReset(captures, account, spec.id),
      },
    });
  }
  return claudeCard(account, "statusline · oauth", readings, generatedAtMs);
}

export function claudeFromUsage(
  output: string,
  account: ClaudeAccount,
  generatedAtMs: number,
): QuotaProvider | undefined {
  const fields = output.trim().split(/\s+/).map(Number);
  if (fields.length !== 5 || fields.some((value) => !Number.isFinite(value)))
    return undefined;
  const [stamp = 0, five = 0, fiveReset = 0, seven = 0, sevenReset = 0] =
    fields;
  if (
    stamp <= 0 ||
    stamp > generatedAtMs / 1000 ||
    five < 0 ||
    five > 1 ||
    seven < 0 ||
    seven > 1 ||
    fiveReset <= 0 ||
    sevenReset <= 0 ||
    fiveReset >= 8.64e12 ||
    sevenReset >= 8.64e12
  )
    return undefined;
  return claudeCard(
    account,
    "usage headers · oauth",
    CLAUDE_WINDOWS.map((spec, index) => {
      const used = (index === 0 ? five : seven) * 100;
      return {
        refreshedAtMs: stamp * 1000,
        window: {
          ...spec,
          percentUsed: used,
          percentRemaining: Math.round((100 - used) * 10) / 10,
          resetsAt: new Date(
            (index === 0 ? fiveReset : sevenReset) * 1000,
          ).toISOString(),
        },
      };
    }),
    generatedAtMs,
  );
}

export function claudeFromDesktop(
  sample: DesktopSample | undefined,
  generatedAtMs: number,
): QuotaProvider | undefined {
  if (!sample || !Number.isFinite(sample.t) || sample.t > generatedAtMs)
    return undefined;
  const readings: Reading[] = [];
  for (const spec of CLAUDE_WINDOWS) {
    const used = spec.id === "five_hour" ? sample.u?.fh : sample.u?.sd;
    if (used === undefined || !Number.isFinite(used) || used < 0 || used > 100)
      continue;
    readings.push({
      refreshedAtMs: sample.t,
      window: { ...spec, percentUsed: used, percentRemaining: 100 - used },
    });
  }
  return claudeCard("personal", "desktop", readings, generatedAtMs);
}

export function selectClaudeCard(
  account: ClaudeAccount,
  generatedAtMs: number,
  candidates: (QuotaProvider | undefined)[],
): QuotaProvider | undefined {
  const measured = candidates
    .filter((candidate): candidate is QuotaProvider =>
      Boolean(candidate?.windows.length),
    )
    .map((candidate) => {
      const normalized = claudeCard(
        account,
        candidate.source ?? "oauth",
        candidate.windows.map((window) => ({
          window,
          refreshedAtMs: Date.parse(candidate.state.refreshedAt ?? ""),
        })),
        generatedAtMs,
        candidate.state.status !== "fresh",
      );
      return normalized
        ? {
            ...candidate,
            ...normalized,
            state: { ...candidate.state, ...normalized.state },
          }
        : undefined;
    })
    .filter((candidate): candidate is QuotaProvider => Boolean(candidate));
  measured.sort(
    (a, b) =>
      Number(b.state.status === "fresh") - Number(a.state.status === "fresh") ||
      Date.parse(b.state.refreshedAt ?? "") -
        Date.parse(a.state.refreshedAt ?? ""),
  );
  const unavailable = candidates.find(
    (candidate) =>
      candidate && !candidate.notSetUp && !candidate.windows.length,
  );
  return (
    measured[0] ??
    (unavailable
      ? { ...unavailable, accountKey: account }
      : {
          provider: "claude",
          accountKey: account,
          windows: [],
          state: {
            status: "unavailable",
            error: "No usage reading available. Refresh to retry.",
          },
        })
  );
}
