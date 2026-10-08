import { Switch } from "@babymenu/ui";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  cardNotes,
  creditsLine,
  headlineLabel,
  headlineMarker,
  health,
  pickHeadline,
  resetCountdown,
  runwayVerdict,
  shortWindowLabel,
  type Verdict,
} from "./pace";
import { quotaProvidersForDisplay, quotaWarningLines } from "./quota-health";
import { subscribeToOperationsRefresh } from "./refresh";
import type {
  OperationsDashboard,
  QuotaColors,
  QuotaProvider,
  QuotaWindow,
  RunScheduleResult,
  ScheduleJob,
  ToggleScheduleResult,
  TokenRow,
} from "./types";

const statusColor: Record<string, string> = {
  scheduled: "bg-signal-live",
  running: "bg-signal-live",
  failed: "bg-signal-danger",
  unloaded: "bg-signal-warn",
  disabled: "bg-ink-faint",
  complete: "bg-ink-faint",
};

// Match the tab strip's signal green, not the palette green.
const SIGNAL_GREEN = "var(--color-signal-live)";

const PROVIDER_ACCENTS: Record<string, (colors: QuotaColors) => string> = {
  claude: (colors) => colors.groups[0] ?? SIGNAL_GREEN,
  codex: () => SIGNAL_GREEN,
  copilot: (colors) => colors.groups[1] ?? SIGNAL_GREEN,
  cursor: (colors) => colors.groups[4] ?? SIGNAL_GREEN,
};

function healthColor(percentRemaining: number, colors: QuotaColors): string {
  const level = health(percentRemaining);
  return level === "ok"
    ? SIGNAL_GREEN
    : level === "warn"
      ? colors.warning
      : colors.danger;
}

function accountLabel(provider: QuotaProvider): string | undefined {
  return provider.accountKey && provider.accountKey !== "default"
    ? provider.accountKey
    : undefined;
}

function hasWhollyUnknownWindowRelationships(provider: QuotaProvider): boolean {
  const semantics = provider.quotaSemantics;
  if (
    provider.windows.length === 0 ||
    semantics?.status !== "unknown" ||
    !semantics.unresolvedWindowIds
  ) {
    return false;
  }
  const unresolved = new Set(semantics.unresolvedWindowIds);
  return provider.windows.every(({ id }) => unresolved.has(id));
}

function ThinBar({
  percent,
  marker,
  color,
  markerColor,
}: {
  percent: number | undefined;
  marker: number | undefined;
  color: string;
  markerColor: string;
}) {
  return (
    <div className="relative h-3 min-w-0 flex-1">
      <div className="absolute inset-x-0 top-1/2 h-px -translate-y-1/2 bg-line" />
      {percent !== undefined ? (
        <div
          className="absolute left-0 top-1/2 h-0.5 -translate-y-1/2"
          style={{
            width: `${Math.min(100, Math.max(0, percent))}%`,
            backgroundColor: color,
          }}
        />
      ) : null}
      {marker !== undefined && Number.isFinite(marker) ? (
        <div
          className="absolute inset-y-0 w-0.5 -translate-x-1/2"
          style={{
            left: `${Math.min(100, Math.max(0, marker))}%`,
            backgroundColor: markerColor,
          }}
        />
      ) : null}
    </div>
  );
}

function CardFrame({
  dot,
  name,
  nameColor,
  right,
  dim,
  children,
}: {
  dot: string;
  name: string;
  nameColor: string;
  right: string;
  dim: boolean;
  children: ReactNode;
}) {
  return (
    <div
      className={`rounded-md border px-3 pb-3 pt-2 font-mono text-xs ${dim ? "border-line-faint" : "border-line"}`}
    >
      <div className="flex items-center gap-2">
        <span style={{ color: nameColor }}>{dot}</span>
        <span className="font-semibold" style={{ color: nameColor }}>
          {name}
        </span>
        <span className="h-px min-w-4 flex-1 bg-line" />
        {right ? <span className="truncate text-ink-soft">{right}</span> : null}
      </div>
      {children}
    </div>
  );
}

function WindowRow({
  window,
  generatedAtMs,
  colors,
  markerColor,
}: {
  window: QuotaWindow;
  generatedAtMs: number;
  colors: QuotaColors;
  markerColor: string;
}) {
  const pct = window.percentRemaining;
  const color =
    pct === undefined ? "var(--color-ink-faint)" : healthColor(pct, colors);
  return (
    <div className="flex items-center gap-3">
      <span className="w-16 shrink-0 truncate text-ink-muted">
        {shortWindowLabel(window)}
      </span>
      <ThinBar
        percent={pct}
        marker={window.pace?.timeRemainingPercent}
        color={color}
        markerColor={markerColor}
      />
      <span className="w-9 shrink-0 text-right" style={{ color }}>
        {pct === undefined ? "?" : `${Math.round(pct)}%`}
      </span>
      <span className="w-14 shrink-0 text-ink-soft">
        {resetCountdown(window, generatedAtMs)}
      </span>
    </div>
  );
}

const verdictTone: Record<Verdict["tone"], string> = {
  dim: "text-ink-soft",
  ok: "text-ink-soft",
  warn: "font-semibold text-signal-warn",
  crit: "font-semibold text-signal-danger",
};

function LiveCard({
  provider,
  generatedAtMs,
  colors,
}: {
  provider: QuotaProvider;
  generatedAtMs: number;
  colors: QuotaColors;
}) {
  const stale = provider.state.status === "stale";
  const accent =
    PROVIDER_ACCENTS[provider.provider]?.(colors) ??
    colors.groups[0] ??
    SIGNAL_GREEN;
  const right = [provider.plan, provider.source, stale ? "stale" : undefined]
    .filter(Boolean)
    .join(" · ");
  const account = accountLabel(provider);
  const headline = pickHeadline(provider);
  const credits = creditsLine(provider);
  const effective = headline?.effectivePercentRemaining;
  const verdict = runwayVerdict(headline);
  return (
    <CardFrame
      dot={stale ? "◐" : "●"}
      name={provider.provider}
      nameColor={stale ? colors.warning : accent}
      right={right}
      dim={stale}
    >
      {account ? (
        <div className="mt-1 truncate text-ink-soft">account {account}</div>
      ) : null}
      <div className="mt-2.5">
        {credits ? (
          <div className="font-semibold text-ink-muted">
            {stale ? `stale · ${credits}` : credits}
          </div>
        ) : hasWhollyUnknownWindowRelationships(provider) ? (
          <div className="flex justify-between gap-3 text-ink-soft">
            <span>
              {stale ? "stale · per-window usage" : "per-window usage"}
            </span>
            <span>no combined bound</span>
          </div>
        ) : (
          <>
            <div className="flex items-baseline justify-between gap-3">
              {effective !== undefined ? (
                <span className="truncate">
                  <span
                    className="font-semibold"
                    style={{ color: healthColor(effective, colors) }}
                  >
                    {Math.round(effective)}%
                  </span>{" "}
                  <span className="text-ink-soft">
                    {headlineLabel(provider, headline)}
                  </span>
                </span>
              ) : (
                <span className="text-ink-soft">
                  {stale ? "stale · effective unknown" : "effective unknown"}
                </span>
              )}
              <span className={`shrink-0 ${verdictTone[verdict.tone]}`}>
                {verdict.text}
                {verdict.mark ? (
                  <span className="font-semibold text-signal-live">
                    {" "}
                    {verdict.mark}
                  </span>
                ) : null}
              </span>
            </div>
            <div className="mt-1.5 flex">
              <ThinBar
                percent={effective}
                marker={headlineMarker(provider, headline)}
                color={
                  effective === undefined
                    ? "var(--color-ink-faint)"
                    : healthColor(effective, colors)
                }
                markerColor={accent}
              />
            </div>
          </>
        )}
      </div>
      {provider.windows.length > 0 ? (
        <div className="mt-3 flex flex-col gap-1.5">
          {provider.windows.map((window) => (
            <WindowRow
              key={window.id}
              window={window}
              generatedAtMs={generatedAtMs}
              colors={colors}
              markerColor={accent}
            />
          ))}
        </div>
      ) : null}
      {cardNotes(provider).map((note) => (
        <div key={note} className="mt-2 truncate text-ink-faint">
          {note}
        </div>
      ))}
    </CardFrame>
  );
}

function FailedCard({ provider }: { provider: QuotaProvider }) {
  const status = provider.state.status;
  const account = accountLabel(provider);
  const message =
    (provider.state.error ?? "").replace(/_/g, " ") ||
    (status === "auth_required"
      ? "sign-in required"
      : status.replace(/_/g, " "));
  return (
    <CardFrame
      dot="○"
      name={provider.provider}
      nameColor="var(--color-ink-muted)"
      right={
        status === "auth_required" ? "signed out" : status.replace(/_/g, " ")
      }
      dim
    >
      {account ? (
        <div className="mt-1 truncate text-ink-soft">account {account}</div>
      ) : null}
      <div className="mt-2.5 flex flex-col gap-0.5 text-ink-soft">
        <span>{message}</span>
        {provider.state.retryAfter ? (
          <span>retry after {provider.state.retryAfter}</span>
        ) : null}
        {provider.state.remedyCommand ? (
          <span className="truncate">run: {provider.state.remedyCommand}</span>
        ) : null}
        <span className="text-ink-faint">excluded from fleet totals</span>
      </div>
    </CardFrame>
  );
}

function quotaTiers(providers: QuotaProvider[]) {
  const live = providers.filter(
    (provider) => provider.state.status === "fresh",
  );
  const stale = providers.filter(
    (provider) => provider.state.status === "stale",
  );
  const attention = providers.filter(
    (provider) => !["fresh", "stale"].includes(provider.state.status),
  );
  return { live, stale, attention };
}

function quotaSummary(dashboard: OperationsDashboard): string {
  const { live, stale, attention } = quotaTiers(dashboard.quotaProviders);
  return [
    `${live.length} live`,
    `${stale.length} stale`,
    `${attention.length} ${attention.length === 1 ? "needs" : "need"} attention`,
  ].join(" · ");
}

function QuotaCards({ dashboard }: { dashboard: OperationsDashboard }) {
  const generatedAtMs = Date.parse(dashboard.quotaGeneratedAt);
  const { live, stale, attention } = quotaTiers(dashboard.quotaProviders);
  return (
    <div className="flex flex-col gap-3">
      {[...live, ...stale].map((provider) => (
        <LiveCard
          key={`${provider.provider}/${provider.accountKey ?? ""}`}
          provider={provider}
          generatedAtMs={generatedAtMs}
          colors={dashboard.quotaColors}
        />
      ))}
      {attention.map((provider) => (
        <FailedCard
          key={`${provider.provider}/${provider.accountKey ?? ""}`}
          provider={provider}
        />
      ))}
    </div>
  );
}

const tokenTextTone: Record<string, string> = {
  ok: "text-signal-live",
  warn: "text-signal-warn",
  critical: "text-signal-danger",
  expired: "text-signal-danger",
  missing: "text-ink-soft",
};

const tokenBarTone: Record<string, string> = {
  ok: "bg-signal-live",
  warn: "bg-signal-warn",
  critical: "bg-signal-danger",
  expired: "bg-signal-danger",
  missing: "bg-ink-faint",
};

// Matches the provider labels agent-quota.sh emits, so both sections read the same.
function tokenLabel(account: string): string {
  return account === "personal" || account === "work"
    ? `Claude ${account}`
    : account;
}

function TokenLine({ row }: { row: TokenRow }) {
  const lifetime =
    row.daysLeft !== null && row.storedDaysAgo !== null
      ? row.daysLeft + row.storedDaysAgo
      : null;
  const percent =
    lifetime !== null && lifetime > 0 && row.daysLeft !== null
      ? Math.max(0, Math.min(100, Math.round((row.daysLeft / lifetime) * 100)))
      : null;
  return (
    <div className="grid grid-cols-[1fr_auto] gap-x-4 gap-y-1.5 border-b border-line-faint py-2.5 last:border-0">
      <div className="min-w-0">
        <div className="truncate text-sm text-ink-strong">
          {tokenLabel(row.account)}
        </div>
        <div className="text-xs text-ink-soft">
          {row.expires ? `expires ${row.expires}` : "no token stored"}
        </div>
      </div>
      <div className="text-right">
        <div
          className={`font-mono text-md ${tokenTextTone[row.status] ?? "text-ink-soft"}`}
        >
          {row.daysLeft === null
            ? "none"
            : row.daysLeft <= 0
              ? "expired"
              : `${row.daysLeft}d left`}
        </div>
        <div className="text-xxs uppercase tracking-caps text-ink-label">
          {row.status}
        </div>
      </div>
      {percent !== null ? (
        <div className="col-span-2 h-1 overflow-hidden rounded-pill bg-line-faint">
          <div
            className={`h-full rounded-pill ${tokenBarTone[row.status] ?? "bg-ink-faint"}`}
            style={{ width: `${percent}%` }}
          />
        </div>
      ) : null}
    </div>
  );
}

function ScheduleLine({
  job,
  busy,
  running,
  toggling,
  onRun,
  onToggle,
}: {
  job: ScheduleJob;
  busy: boolean;
  running: boolean;
  toggling: boolean;
  onRun: () => void;
  onToggle: (enabled: boolean) => void;
}) {
  return (
    <div className="flex items-center gap-2 border-b border-line-faint py-2 last:border-0">
      <span
        className={`h-1.5 w-1.5 shrink-0 rounded-pill ${statusColor[job.status] ?? "bg-ink-faint"}`}
      />
      <span className="min-w-0 flex-1 truncate text-sm text-ink">
        {job.name}
      </span>
      {job.ai ? (
        <span
          title="Spends model tokens every time it fires"
          className="shrink-0 rounded-sm border border-signal-warn/50 px-1.5 py-px text-xxs uppercase tracking-caps text-signal-warn"
        >
          AI
        </span>
      ) : null}
      <span className="shrink-0 font-mono text-xs text-ink-soft">
        {job.remaining}
      </span>
      {job.runTarget ? (
        <button
          type="button"
          onClick={onRun}
          disabled={busy || job.status === "running"}
          className="rounded-sm border border-line px-2 py-1 text-xxs uppercase tracking-caps text-ink-muted transition-colors hover:border-signal-live/40 hover:text-ink-strong disabled:opacity-40"
        >
          {running ? "Running" : "Run"}
        </button>
      ) : null}
      {job.toggleTarget ? (
        <Switch
          checked={job.enabled}
          onCheckedChange={onToggle}
          disabled={busy}
          aria-label={`${job.enabled ? "Disable" : "Enable"} ${job.name}`}
          title={toggling ? "Updating schedule" : "Toggle schedule"}
        />
      ) : null}
    </div>
  );
}

function EmptyState({ children }: { children: string }) {
  return (
    <div className="rounded-md border border-line-faint bg-surface px-3 py-4 text-center text-sm text-ink-soft">
      {children}
    </div>
  );
}

function isEditableTarget(target: EventTarget | null): boolean {
  return (
    target instanceof HTMLElement &&
    (target.isContentEditable ||
      target instanceof HTMLInputElement ||
      target instanceof HTMLTextAreaElement ||
      target instanceof HTMLSelectElement)
  );
}

export function OperationsView({
  variant = "all",
}: {
  variant?: "all" | "usage" | "accounts" | "cron";
}) {
  const scrollContainer = useRef<HTMLDivElement>(null);
  const [dashboard, setDashboard] = useState<OperationsDashboard | null>(null);
  const [loading, setLoading] = useState(true);
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [quotaRefreshFailed, setQuotaRefreshFailed] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [runningTarget, setRunningTarget] = useState<string | null>(null);
  const [togglingTarget, setTogglingTarget] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const api = window.babyMenu;
    if (!api) {
      setError("Baby Menu bridge unavailable");
      setQuotaRefreshFailed(true);
      setNowMs(Date.now());
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const value = await api.capabilities.invoke<OperationsDashboard>(
        "operations",
        "getDashboard",
      );
      setDashboard(value);
      setQuotaRefreshFailed(false);
      setError("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
      setQuotaRefreshFailed(true);
    } finally {
      setNowMs(Date.now());
      setLoading(false);
    }
  }, []);

  const runSchedule = useCallback(
    async (job: ScheduleJob) => {
      const api = window.babyMenu;
      if (!api || !job.runTarget || runningTarget || togglingTarget) return;

      setRunningTarget(job.runTarget);
      setNotice("");
      try {
        const result = await api.capabilities.invoke<RunScheduleResult>(
          "operations",
          "runSchedule",
          { target: job.runTarget },
        );
        setNotice(
          `${job.name} started${result.pid === null ? "" : ` · PID ${result.pid}`} · ${result.logPath}`,
        );
        await new Promise((resolve) => window.setTimeout(resolve, 250));
        await refresh();
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : String(cause));
      } finally {
        setRunningTarget(null);
      }
    },
    [refresh, runningTarget, togglingTarget],
  );

  const toggleSchedule = useCallback(
    async (job: ScheduleJob, enabled: boolean) => {
      const api = window.babyMenu;
      if (!api || !job.toggleTarget || runningTarget || togglingTarget) return;

      setTogglingTarget(job.toggleTarget);
      setNotice("");
      try {
        const result = await api.capabilities.invoke<ToggleScheduleResult>(
          "operations",
          "toggleSchedule",
          { target: job.toggleTarget, enabled },
        );
        setError("");
        setNotice(
          `${job.name} ${result.enabled ? "enabled" : "disabled"} · ${result.logPath}`,
        );
        await new Promise((resolve) => window.setTimeout(resolve, 250));
        await refresh();
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : String(cause));
      } finally {
        setTogglingTarget(null);
      }
    },
    [refresh, runningTarget, togglingTarget],
  );

  useEffect(() => {
    const unsubscribe = subscribeToOperationsRefresh(() => void refresh());
    void refresh();
    return unsubscribe;
  }, [refresh]);

  useEffect(() => {
    const tick = () => setNowMs(Date.now());
    const timer = window.setInterval(tick, 30_000);
    window.addEventListener("focus", tick);
    document.addEventListener("visibilitychange", tick);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener("focus", tick);
      document.removeEventListener("visibilitychange", tick);
    };
  }, []);

  useEffect(() => {
    if (document.documentElement.dataset.windowMode === "sidebar") return;
    const navigate = (event: KeyboardEvent) => {
      const editable = isEditableTarget(event.target);

      if (event.key === "Escape" && editable) {
        event.preventDefault();
        event.stopPropagation();
        (event.target as HTMLElement).blur();
        scrollContainer.current?.focus({ preventScroll: true });
        return;
      }

      if (
        event.defaultPrevented ||
        event.metaKey ||
        event.ctrlKey ||
        event.altKey ||
        editable
      ) {
        return;
      }

      if (event.key === "i") {
        const composer = document.querySelector<HTMLTextAreaElement>(
          'textarea[placeholder="talk to the baby"]',
        );
        if (!composer) return;
        event.preventDefault();
        composer.focus();
        return;
      }

      const direction = event.key === "j" ? 1 : event.key === "k" ? -1 : 0;
      if (!direction) return;

      event.preventDefault();
      const scrollRegion =
        scrollContainer.current?.closest<HTMLElement>(".pop-body") ??
        scrollContainer.current;
      scrollRegion?.scrollBy({
        top: direction * (event.repeat ? 48 : 96),
        behavior: event.repeat ? "auto" : "smooth",
      });
    };

    window.addEventListener("keydown", navigate, { capture: true });
    return () =>
      window.removeEventListener("keydown", navigate, {
        capture: true,
      });
  }, []);

  const displayDashboard = dashboard
    ? {
        ...dashboard,
        quotaGeneratedAt: new Date(nowMs).toISOString(),
        quotaProviders: quotaProvidersForDisplay(
          dashboard.quotaProviders,
          nowMs,
          quotaRefreshFailed,
        ),
      }
    : null;
  const quotaWarnings = displayDashboard
    ? quotaWarningLines(displayDashboard.quotaProviders, nowMs)
    : [];
  const tokenAlerts =
    dashboard?.tokens.filter((row) => row.status !== "ok").length ?? 0;
  const tokenDays =
    dashboard?.tokens
      .map((row) => row.daysLeft)
      .filter((days): days is number => days !== null) ?? [];
  const soonestToken = tokenDays.length ? Math.min(...tokenDays) : null;

  return (
    <div
      ref={scrollContainer}
      tabIndex={-1}
      className="flex flex-col gap-5 pb-1 pt-1 focus:outline-none"
    >
      <header className="flex items-start justify-between gap-4">
        <div>
          <div className="text-xxs uppercase tracking-caps text-ink-label">
            {variant === "all" ? "operations" : variant}
          </div>
          <div className="mt-1 text-xl font-light tracking-value text-ink-strong">
            {variant === "cron"
              ? "Scheduled services"
              : variant === "usage"
                ? "AI capacity"
                : variant === "accounts"
                  ? "OAuth tokens"
                  : "AI and schedules"}
          </div>
          <div className="mt-1 text-xs text-ink-soft">
            {dashboard
              ? variant === "usage" && displayDashboard
                ? quotaSummary(displayDashboard)
                : variant === "accounts"
                  ? tokenAlerts
                    ? `${tokenAlerts} need refreshing`
                    : soonestToken !== null
                      ? `${soonestToken}d until the first renewal`
                      : "no tokens stored"
                  : `${dashboard.activeSchedules}/${dashboard.totalSchedules} schedules active`
              : "Loading live state"}
          </div>
        </div>
        <button
          type="button"
          onClick={() => void refresh()}
          disabled={loading}
          className="rounded-sm border border-line px-3 py-1.5 text-xs text-ink-muted transition-colors hover:border-signal-live/40 hover:text-ink-strong disabled:opacity-40"
        >
          {loading ? "Refreshing" : "Refresh"}
        </button>
      </header>

      {error ? (
        <div
          role="alert"
          className="rounded-md border border-signal-danger/40 bg-surface px-3 py-2 text-sm text-signal-danger"
        >
          {quotaRefreshFailed
            ? `Refresh failed. Previous readings are not current. ${error}`
            : error}
        </div>
      ) : null}

      {(variant === "usage" || variant === "all") && quotaWarnings.length ? (
        <div
          role="alert"
          className="rounded-md border border-signal-warn/60 bg-surface px-3 py-2 text-sm text-signal-warn"
        >
          <div className="font-semibold">Usage readings need attention</div>
          {quotaWarnings.map((warning) => (
            <p key={warning} className="mt-1">
              {warning}
            </p>
          ))}
          <div className="mt-1">
            Use Refresh to retry. This warning clears when fresh readings
            return.
          </div>
        </div>
      ) : null}

      {notice ? (
        <div className="rounded-md border border-signal-live/40 bg-surface px-3 py-2 text-sm text-signal-live">
          {notice}
        </div>
      ) : null}

      {variant === "usage" || variant === "all" ? (
        <section>
          <div className="mb-2 flex items-center justify-between">
            <span className="text-xxs uppercase tracking-caps text-ink-label">
              AI capacity
            </span>
            <span className="text-xs text-ink-soft">
              {displayDashboard ? quotaSummary(displayDashboard) : ""}
            </span>
          </div>
          {displayDashboard?.quotaProviders.length ? (
            <QuotaCards dashboard={displayDashboard} />
          ) : (
            <div className="rounded-md border border-line bg-surface px-3">
              <EmptyState>No quota data</EmptyState>
            </div>
          )}
        </section>
      ) : null}

      {variant === "accounts" || variant === "all" ? (
        <section>
          {variant === "all" ? (
            <div className="mb-2 flex items-center justify-between">
              <span className="text-xxs uppercase tracking-caps text-ink-label">
                OAuth tokens
              </span>
              <span
                className={
                  tokenAlerts
                    ? "text-xs text-signal-warn"
                    : "text-xs text-ink-soft"
                }
              >
                {tokenAlerts
                  ? `${tokenAlerts} need refreshing`
                  : soonestToken !== null
                    ? `${soonestToken}d until the first renewal`
                    : "no tokens stored"}
              </span>
            </div>
          ) : null}
          <div className="rounded-md border border-line bg-surface px-3">
            {dashboard?.tokens.length ? (
              dashboard.tokens.map((row) => (
                <TokenLine key={row.account} row={row} />
              ))
            ) : (
              <EmptyState>No token data</EmptyState>
            )}
          </div>
        </section>
      ) : null}

      {variant === "cron" || variant === "all" ? (
        <section>
          <div className="mb-2 flex items-center justify-between">
            <span className="text-xxs uppercase tracking-caps text-ink-label">
              Scheduled services
            </span>
            <span
              className={
                dashboard?.problemSchedules
                  ? "text-xs text-signal-danger"
                  : "text-xs text-ink-soft"
              }
            >
              {dashboard?.problemSchedules
                ? `${dashboard.problemSchedules} need attention`
                : `${dashboard?.totalSchedules ?? 0} tracked · ${dashboard?.aiSchedules ?? 0} AI`}
            </span>
          </div>
          <div className="flex flex-col gap-3">
            {dashboard?.schedules.length ? (
              dashboard.schedules.map((section) => (
                <div
                  key={section.name}
                  className="rounded-md border border-line bg-surface px-3 py-2"
                >
                  <div className="pb-1 text-xxs uppercase tracking-caps text-ink-label">
                    {section.name}
                  </div>
                  {section.jobs.map((job) => (
                    <ScheduleLine
                      key={`${section.name}:${job.name}`}
                      job={job}
                      busy={runningTarget !== null || togglingTarget !== null}
                      running={runningTarget === job.runTarget}
                      toggling={togglingTarget === job.toggleTarget}
                      onRun={() => void runSchedule(job)}
                      onToggle={(enabled) => void toggleSchedule(job, enabled)}
                    />
                  ))}
                </div>
              ))
            ) : (
              <EmptyState>No scheduled services</EmptyState>
            )}
          </div>
        </section>
      ) : null}

      {dashboard?.errors.length ? (
        <div className="text-xs text-signal-warn">
          {dashboard.errors.join(" · ")}
        </div>
      ) : null}
    </div>
  );
}
