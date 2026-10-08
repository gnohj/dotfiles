import { describe, expect, test } from "bun:test";
import {
  claudeFromUsage,
  selectClaudeCard,
} from "../dot_baby-menu-sidebar/extensions/operations/claude-quota";
import {
  pickHeadline,
  runwayVerdict,
} from "../dot_baby-menu-sidebar/extensions/operations/pace";
import {
  quotaProvidersForDisplay,
  quotaWarningLines,
} from "../dot_baby-menu-sidebar/extensions/operations/quota-health";
import type { QuotaProvider } from "../dot_baby-menu-sidebar/extensions/operations/types";

const now = Date.parse("2026-10-08T01:12:00Z");

function fresh(
  account: "personal" | "work" = "personal",
  sessionReset = now + 3600_000,
): QuotaProvider {
  const card = claudeFromUsage(
    `${now / 1000}\t0.01\t${sessionReset / 1000}\t0.18\t${(now + 86400_000) / 1000}`,
    account,
    now,
  );
  if (!card) throw new Error("missing fixture");
  return card;
}

function display(
  provider: QuotaProvider,
  at = now,
  failed = false,
): QuotaProvider {
  const card = quotaProvidersForDisplay([provider], at, failed)[0];
  if (!card) throw new Error("missing displayed card");
  return card;
}

describe("Usage stale-data warnings", () => {
  test("fresh readings show no warning", () => {
    const card = display(fresh());
    expect(quotaWarningLines([card], now)).toEqual([]);
    expect(card.windows.map((window) => window.percentRemaining)).toEqual([
      99, 82,
    ]);
  });

  test("the browser notices five-minute-old data even if polling stops", () => {
    const card = display(fresh(), now + 300_000);
    expect(card.state.status).toBe("stale");
    expect(quotaWarningLines([card], now + 300_000)).toEqual([
      "Claude personal: readings are out of date. Last update 5m ago. Remaining usage is unknown.",
    ]);
    expect(
      card.windows.every((window) => window.percentRemaining === undefined),
    ).toBe(true);
    expect(pickHeadline(card)?.effectivePercentRemaining).toBeUndefined();
  });

  test("a passed reset warns immediately, before the freshness timeout", () => {
    const card = display(fresh("personal", now + 30_000), now + 30_000);
    expect(card.state.status).toBe("stale");
    expect(card.windows[0]?.resetText).toBe("expired");
    expect(quotaWarningLines([card], now + 30_000)[0]).toContain("out of date");
    expect(runwayVerdict(pickHeadline(card)).text).toBe("runway unknown");
  });

  test("failed dashboard refresh hides previously fresh readings immediately", () => {
    const original = fresh();
    const card = display(original, now, true);
    expect(card.state.status).toBe("stale");
    expect(
      card.windows.every((window) => window.percentRemaining === undefined),
    ).toBe(true);
    expect(quotaWarningLines([card], now)[0]).toContain(
      "Remaining usage is unknown",
    );
    expect(original.state.status).toBe("fresh");
    expect(original.windows[0]?.percentRemaining).toBe(99);
  });

  test("fresh recovery clears the warning and restores the percentages", () => {
    expect(quotaWarningLines([display(fresh(), now, true)], now)).toHaveLength(
      1,
    );
    const recovered = display(fresh());
    expect(quotaWarningLines([recovered], now)).toEqual([]);
    expect(recovered.windows[0]?.percentRemaining).toBe(99);
  });

  test("missing readings cannot silently remove either Claude account", () => {
    for (const account of ["personal", "work"] as const) {
      const card = selectClaudeCard(account, now, [undefined]);
      if (!card) throw new Error("missing unavailable card");
      expect(card.accountKey).toBe(account);
      expect(quotaWarningLines([card], now)[0]).toContain(
        `Claude ${account}: fresh readings unavailable`,
      );
    }
  });

  test("malformed timestamps warn rather than preserving a live claim", () => {
    const original = fresh();
    original.state.refreshedAt = "bad timestamp";
    const card = display(original);
    expect(card.state.status).toBe("unavailable");
    expect(quotaWarningLines([card], now)[0]).toContain("No recent update");
  });

  test("stale historical zeroes are hidden, not colored as current exhaustion", () => {
    const original = fresh();
    original.state.status = "stale";
    original.windows[0]!.percentRemaining = 0;
    const card = display(original);
    expect(card.windows[0]?.percentRemaining).toBeUndefined();
    expect(runwayVerdict(pickHeadline(card)).text).toBe("runway unknown");
  });

  test("other stale providers also warn and hide historical numbers", () => {
    const card = display({
      ...fresh(),
      provider: "codex",
      accountKey: "default",
      state: { status: "stale" },
    });
    expect(card.windows[0]?.percentRemaining).toBeUndefined();
    expect(quotaWarningLines([card], now)).toEqual([
      "codex: readings are out of date. No recent update. Remaining usage is unknown.",
    ]);
  });

  test("an empty report warns instead of looking like no problem", () => {
    expect(quotaWarningLines([], now)).toEqual([
      "No usage readings are available. Remaining usage is unknown.",
    ]);
  });
});
