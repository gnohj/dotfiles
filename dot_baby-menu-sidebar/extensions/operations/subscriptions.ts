import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { SubscriptionRow } from "./types";

const home = homedir();
const claudeBillingDayFile = join(
  home,
  ".local/state/claude/billing-day-personal",
);
const codexAuthFile = join(
  process.env.CODEX_HOME ?? join(home, ".codex"),
  "auth.json",
);

type CodexAuthClaims = {
  chatgpt_plan_type?: string;
  chatgpt_subscription_active_start?: string;
  chatgpt_subscription_active_until?: string;
  chatgpt_subscription_last_checked?: string;
};

const claudePersonalMonthlyUsd = 100;
const chatgptMonthlyUsdByPlan: Record<string, number> = {
  plus: 20,
  prolite: 100,
  pro: 200,
};

function addMonths(anchor: Date, months: number): Date {
  const shifted = new Date(anchor);
  shifted.setUTCDate(1);
  shifted.setUTCMonth(shifted.getUTCMonth() + months);
  const lastDay = new Date(
    Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth() + 1, 0),
  ).getUTCDate();
  shifted.setUTCDate(Math.min(anchor.getUTCDate(), lastDay));
  return shifted;
}

export function nextMonthlyRenewal(anchorMs: number, nowMs: number): number {
  const anchor = new Date(anchorMs);
  let months = 0;
  let next = anchorMs;
  while (next <= nowMs) next = addMonths(anchor, ++months).getTime();
  return next;
}

export function nextBillingDay(day: number, now: Date): Date {
  const thisMonth = new Date(now.getFullYear(), now.getMonth(), day);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return thisMonth >= today
    ? thisMonth
    : new Date(now.getFullYear(), now.getMonth() + 1, day);
}

export function claudeSubscription(
  recordedDay: string,
  now: Date,
): SubscriptionRow {
  const day = Number(recordedDay.trim());
  const valid = Number.isInteger(day) && day >= 1 && day <= 28;
  return {
    service: "Claude personal",
    monthlyUsd: claudePersonalMonthlyUsd,
    renewsAt: valid ? nextBillingDay(day, now).toISOString() : null,
    basis: valid ? "recorded" : "missing",
    remedyCommand: valid
      ? undefined
      : "claude-account set-billing-day personal <1-28>",
  };
}

function decodeJwtClaims(token: string): Record<string, unknown> {
  const payload = token.split(".")[1] ?? "";
  return JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
}

export function codexSubscription(
  idToken: string,
  nowMs: number,
): SubscriptionRow | undefined {
  const claims = decodeJwtClaims(idToken)["https://api.openai.com/auth"] as
    CodexAuthClaims | undefined;
  const startMs = Date.parse(claims?.chatgpt_subscription_active_start ?? "");
  if (!claims || Number.isNaN(startMs)) return undefined;
  const untilMs = Date.parse(claims.chatgpt_subscription_active_until ?? "");
  const confirmed = !Number.isNaN(untilMs) && untilMs > nowMs;
  return {
    service: "ChatGPT",
    plan: claims.chatgpt_plan_type,
    monthlyUsd: chatgptMonthlyUsdByPlan[claims.chatgpt_plan_type ?? ""],
    renewsAt: new Date(
      confirmed ? untilMs : nextMonthlyRenewal(startMs, nowMs),
    ).toISOString(),
    basis: confirmed ? "confirmed" : "projected",
    confirmedAt: claims.chatgpt_subscription_last_checked,
  };
}

// Work subscriptions (Claude work, Copilot business) are deliberately left out.
export async function personalSubscriptions(
  errors: string[],
): Promise<SubscriptionRow[]> {
  const now = new Date();
  const [recordedDay, codexAuth] = await Promise.all([
    readFile(claudeBillingDayFile, "utf8").catch(() => ""),
    readFile(codexAuthFile, "utf8").catch(() => ""),
  ]);
  const rows = [claudeSubscription(recordedDay, now)];
  if (codexAuth) {
    try {
      const auth = JSON.parse(codexAuth) as { tokens?: { id_token?: string } };
      const codex = auth.tokens?.id_token
        ? codexSubscription(auth.tokens.id_token, now.getTime())
        : undefined;
      if (codex) rows.push(codex);
    } catch (error) {
      errors.push(
        `codex auth: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }
  return rows;
}
