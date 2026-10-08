import { selectClaudeCard } from "./claude-quota";
import { formatCountdown } from "./pace";
import type { QuotaProvider } from "./types";

export function quotaProvidersForDisplay(
  providers: QuotaProvider[],
  nowMs: number,
  refreshFailed = false,
): QuotaProvider[] {
  return providers.map((original) => {
    const provider =
      original.provider === "claude" &&
      (original.accountKey === "personal" || original.accountKey === "work")
        ? (selectClaudeCard(original.accountKey, nowMs, [original]) ?? original)
        : original;
    if (!refreshFailed && provider.state.status !== "stale") return provider;
    return {
      ...provider,
      windows: provider.windows.map((window) => ({
        ...window,
        percentRemaining: undefined,
        percentUsed: undefined,
        pace: undefined,
      })),
      state: {
        ...provider.state,
        status: ["fresh", "stale"].includes(provider.state.status)
          ? "stale"
          : provider.state.status,
      },
      quotaSemantics: {
        status: "unknown",
        effectiveAvailability: [{ scope: "all_models", status: "unknown" }],
      },
    };
  });
}

export function quotaWarningLines(
  providers: QuotaProvider[],
  nowMs: number,
): string[] {
  if (!providers.length)
    return ["No usage readings are available. Remaining usage is unknown."];
  return providers
    .filter(
      (provider) => !provider.notSetUp && provider.state.status !== "fresh",
    )
    .map((provider) => {
      const name = [
        provider.provider === "claude" ? "Claude" : provider.provider,
        provider.accountKey,
      ]
        .filter((part) => part && part !== "default")
        .join(" ");
      const updatedMs = Date.parse(provider.state.refreshedAt ?? "");
      const ageSeconds = (nowMs - updatedMs) / 1000;
      const age =
        Number.isFinite(updatedMs) && updatedMs <= nowMs
          ? `Last update ${ageSeconds < 60 ? "<1m" : formatCountdown(ageSeconds)} ago.`
          : "No recent update.";
      return `${name}: ${provider.state.status === "stale" ? "readings are out of date" : "fresh readings unavailable"}. ${age} Remaining usage is unknown.`;
    });
}
