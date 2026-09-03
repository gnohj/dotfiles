import { Switch } from "@babymenu/ui";
import { useCallback, useEffect, useRef, useState } from "react";
import { subscribeToOperationsRefresh } from "./refresh";
import type {
  OperationsDashboard,
  QuotaRow,
  RunScheduleResult,
  ScheduleJob,
  ToggleScheduleResult,
} from "./types";

const statusColor: Record<string, string> = {
  scheduled: "bg-signal-live",
  running: "bg-signal-live",
  failed: "bg-signal-danger",
  unloaded: "bg-signal-warn",
  disabled: "bg-ink-faint",
  complete: "bg-ink-faint",
};

function quotaValue(row: QuotaRow): { label: string; percent: number | null } {
  const remaining = Number(row.remaining);
  if (!Number.isFinite(remaining))
    return { label: row.remaining, percent: null };
  return {
    label: `${remaining}% left`,
    percent: Math.max(0, Math.min(100, remaining)),
  };
}

function QuotaLine({ row }: { row: QuotaRow }) {
  const value = quotaValue(row);
  const barColor =
    value.percent !== null && value.percent <= 15
      ? "bg-signal-danger"
      : value.percent !== null && value.percent <= 35
        ? "bg-signal-warn"
        : "bg-signal-live";
  return (
    <div className="grid grid-cols-[1fr_auto] gap-x-4 gap-y-1.5 border-b border-line-faint py-2.5 last:border-0">
      <div className="min-w-0">
        <div className="truncate text-sm text-ink-strong">{row.provider}</div>
        <div className="text-xs text-ink-soft">{row.window}</div>
      </div>
      <div className="text-right font-mono text-xs text-ink-muted">
        <div>{value.label || "unknown"}</div>
        <div>{row.reset || "no reset"}</div>
      </div>
      {value.percent !== null ? (
        <div className="col-span-2 h-1 overflow-hidden rounded-pill bg-line-faint">
          <div
            className={`h-full rounded-pill ${barColor}`}
            style={{ width: `${value.percent}%` }}
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

export function OperationsView() {
  const scrollContainer = useRef<HTMLDivElement>(null);
  const [dashboard, setDashboard] = useState<OperationsDashboard | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [runningTarget, setRunningTarget] = useState<string | null>(null);
  const [togglingTarget, setTogglingTarget] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const api = window.babyMenu;
    if (!api) {
      setError("Baby Menu bridge unavailable");
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
      setError("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
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

  return (
    <div
      ref={scrollContainer}
      tabIndex={-1}
      className="flex flex-col gap-5 pb-1 pt-1 focus:outline-none"
    >
      <header className="flex items-start justify-between gap-4">
        <div>
          <div className="text-xxs uppercase tracking-caps text-ink-label">
            operations
          </div>
          <div className="mt-1 text-xl font-light tracking-value text-ink-strong">
            AI and schedules
          </div>
          <div className="mt-1 text-xs text-ink-soft">
            {dashboard
              ? `${dashboard.activeSchedules}/${dashboard.totalSchedules} schedules active`
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
        <div className="rounded-md border border-signal-danger/40 bg-surface px-3 py-2 text-sm text-signal-danger">
          {error}
        </div>
      ) : null}

      {notice ? (
        <div className="rounded-md border border-signal-live/40 bg-surface px-3 py-2 text-sm text-signal-live">
          {notice}
        </div>
      ) : null}

      <section>
        <div className="mb-2 flex items-center justify-between">
          <span className="text-xxs uppercase tracking-caps text-ink-label">
            AI capacity
          </span>
          <span className="text-xs text-ink-soft">
            {dashboard?.quotas.length ?? 0} windows
          </span>
        </div>
        <div className="rounded-md border border-line bg-surface px-3">
          {dashboard?.quotas.length ? (
            dashboard.quotas.map((row) => (
              <QuotaLine key={`${row.provider}:${row.window}`} row={row} />
            ))
          ) : (
            <EmptyState>No quota data</EmptyState>
          )}
        </div>
      </section>

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

      {dashboard?.errors.length ? (
        <div className="text-xs text-signal-warn">
          {dashboard.errors.join(" · ")}
        </div>
      ) : null}
    </div>
  );
}
