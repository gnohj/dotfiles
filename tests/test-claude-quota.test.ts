import { describe, expect, test } from "bun:test";
import {
  claudeFromDesktop,
  claudeFromStatusline,
  claudeFromUsage,
  selectClaudeCard,
  type Captures,
  type ClaudeAccount,
} from "../dot_baby-menu-sidebar/extensions/operations/claude-quota";
import {
  pickHeadline,
  runwayVerdict,
} from "../dot_baby-menu-sidebar/extensions/operations/pace";
import type { QuotaProvider } from "../dot_baby-menu-sidebar/extensions/operations/types";

const now = Date.parse("2026-10-08T01:12:00Z");

function captures(
  observedAt = now - 60_000,
  sessionUsed = 1,
  weekUsed = 18,
  sessionReset = now + 3600_000,
  account: ClaudeAccount = "personal",
): Captures {
  return new Map([
    [
      `claude_pct_${account}_five_hour`,
      { value: String(sessionUsed), mtimeMs: observedAt },
    ],
    [
      `claude_pct_${account}_seven_day`,
      { value: String(weekUsed), mtimeMs: observedAt },
    ],
    [
      `claude_reset_${account}_five_hour`,
      { value: String(sessionReset / 1000), mtimeMs: observedAt },
    ],
    [
      `claude_reset_${account}_seven_day`,
      { value: String((now + 86400_000) / 1000), mtimeMs: observedAt },
    ],
  ]);
}

function usage(
  observedAt = now - 60_000,
  sessionUsed = 0.01,
  weekUsed = 0.18,
): string {
  return `${observedAt / 1000}\t${sessionUsed}\t${(now + 3600_000) / 1000}\t${weekUsed}\t${(now + 86400_000) / 1000}\n`;
}

function required(card: QuotaProvider | undefined): QuotaProvider {
  expect(card).toBeDefined();
  if (!card) throw new Error("missing card");
  return card;
}

function headline(card: QuotaProvider) {
  return pickHeadline(card);
}

describe("Claude sidebar quota freshness", () => {
  test("the screenshot's expired session no longer claims exhaustion", () => {
    const card = required(
      claudeFromStatusline(
        captures(
          Date.parse("2026-10-06T00:14:08.453Z"),
          100,
          17,
          Date.parse("2026-10-06T01:00:00Z"),
        ),
        "personal",
        now,
      ),
    );
    expect(card.state.status).toBe("stale");
    expect(card.windows[0]?.percentRemaining).toBeUndefined();
    expect(card.windows[0]?.resetsAt).toBeUndefined();
    expect(card.windows[0]?.resetText).toBe("expired");
    expect(card.windows[1]?.percentRemaining).toBe(83);
    expect(headline(card)?.effectivePercentRemaining).toBeUndefined();
    expect(runwayVerdict(headline(card)).text).toBe("runway unknown");
  });

  test("newer usage headers replace the old statusline capture", () => {
    const old = claudeFromStatusline(
      captures(now - 2 * 86400_000, 100, 17, now - 86400_000),
      "personal",
      now,
    );
    const fresh = claudeFromUsage(usage(), "personal", now);
    const card = required(selectClaudeCard("personal", now, [old, fresh]));
    expect(card.source).toBe("usage headers · oauth");
    expect(card.state.status).toBe("fresh");
    expect(card.windows.map((window) => window.percentRemaining)).toEqual([
      99, 82,
    ]);
  });

  test("newer statusline data still wins over older usage headers", () => {
    const card = required(
      selectClaudeCard("personal", now, [
        claudeFromUsage(usage(now - 120_000), "personal", now),
        claudeFromStatusline(captures(now - 10_000, 5, 20), "personal", now),
      ]),
    );
    expect(card.source).toBe("statusline · oauth");
    expect(card.windows.map((window) => window.percentRemaining)).toEqual([
      95, 80,
    ]);
  });

  test("newer desktop data is considered even when statusline files exist", () => {
    const card = required(
      selectClaudeCard("personal", now, [
        claudeFromStatusline(captures(now - 86400_000, 100), "personal", now),
        claudeFromDesktop({ t: now - 1000, u: { fh: 2, sd: 19 } }, now),
      ]),
    );
    expect(card.source).toBe("desktop");
    expect(card.windows.map((window) => window.percentRemaining)).toEqual([
      98, 81,
    ]);
    expect(card.windows.every((window) => window.resetsAt === undefined)).toBe(
      true,
    );
  });

  test("genuine current exhaustion still reports zero", () => {
    const card = required(
      claudeFromUsage(usage(now - 1000, 1), "personal", now),
    );
    expect(headline(card)?.effectivePercentRemaining).toBe(0);
    expect(runwayVerdict(headline(card)).text).toBe("✗ exhausted now");
  });

  test("stale unexpired zeroes have no current exhaustion verdict", () => {
    const card = required(
      claudeFromUsage(usage(now - 300_000, 1), "personal", now),
    );
    expect(card.state.status).toBe("stale");
    expect(card.windows[0]?.percentRemaining).toBe(0);
    expect(headline(card)?.effectivePercentRemaining).toBeUndefined();
    expect(runwayVerdict(headline(card)).text).toBe("runway unknown");
  });

  test("a reset expires exactly at its timestamp", () => {
    const card = required(
      claudeFromStatusline(captures(now - 1000, 100, 18, now), "personal", now),
    );
    expect(card.windows[0]?.percentRemaining).toBeUndefined();
    expect(card.state.status).toBe("stale");
  });

  test("a new weekly capture cannot make an old session look fresh", () => {
    const values = captures();
    values.set("claude_pct_personal_five_hour", {
      value: "100",
      mtimeMs: now - 600_000,
    });
    const card = required(claudeFromStatusline(values, "personal", now));
    expect(card.state.status).toBe("stale");
    expect(card.state.refreshedAt).toBe(new Date(now - 600_000).toISOString());
    expect(headline(card)?.effectivePercentRemaining).toBeUndefined();
  });

  test("resetless desktop readings expire by window duration", () => {
    const card = required(
      claudeFromDesktop({ t: now - 6 * 3600_000, u: { fh: 100, sd: 18 } }, now),
    );
    expect(card.windows[0]?.percentRemaining).toBeUndefined();
    expect(card.windows[1]?.percentRemaining).toBe(82);
    expect(headline(card)?.effectivePercentRemaining).toBeUndefined();
  });

  test("missing desktop usage is unknown, not zero used", () => {
    const card = required(
      claudeFromDesktop({ t: now - 1000, u: { sd: 18 } }, now),
    );
    expect(card.windows.map((window) => window.id)).toEqual(["seven_day"]);
    expect(card.state.status).toBe("stale");
  });

  test("malformed and future usage caches are rejected", () => {
    for (const output of [
      "",
      "bad",
      usage(now + 1000),
      usage(now, 1.1),
      usage(now, -0.1),
      usage().replace("0.18", "NaN"),
    ])
      expect(claudeFromUsage(output, "personal", now)).toBeUndefined();
  });

  test("work and personal readings remain separate", () => {
    expect(
      claudeFromStatusline(
        captures(undefined, undefined, undefined, undefined, "work"),
        "personal",
        now,
      ),
    ).toBeUndefined();
    const work = required(
      claudeFromUsage(usage(now - 1000, 0.02, 0.59), "work", now),
    );
    expect(work.accountKey).toBe("work");
    expect(work.windows.map((window) => window.percentRemaining)).toEqual([
      98, 41,
    ]);
  });

  test("an upstream stale report is never relabeled fresh", () => {
    const upstream = required(claudeFromUsage(usage(), "work", now));
    upstream.state.status = "stale";
    upstream.state.error = "rate_limited";
    upstream.plan = "max";
    const card = required(selectClaudeCard("work", now, [upstream]));
    expect(card.state.status).toBe("stale");
    expect(card.state.error).toBe("rate_limited");
    expect(card.plan).toBe("max");
    expect(headline(card)?.effectivePercentRemaining).toBeUndefined();
  });

  test("failed providers stay visible with their account identity", () => {
    const card = required(
      selectClaudeCard("work", now, [
        {
          provider: "claude",
          windows: [],
          state: { status: "rate_limited", error: "quota unavailable" },
        },
      ]),
    );
    expect(card.accountKey).toBe("work");
    expect(card.state.status).toBe("rate_limited");
  });
});
