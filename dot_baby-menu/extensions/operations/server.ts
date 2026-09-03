import { execFile } from "node:child_process";
import { appendFile, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import type {
  OperationsDashboard,
  QuotaRow,
  RunScheduleResult,
  ScheduleJob,
  ScheduleSection,
  ToggleScheduleResult,
} from "./types";

const home = homedir();
const quotaScript = join(
  home,
  ".config/sketchybar/items/widgets/agent-quota.sh",
);
const schedulesScript = join(
  home,
  ".config/sketchybar/items/widgets/schedules-panel.py",
);
const actionLog = join(home, ".logs/baby-menu/operations.log");

function execute(
  file: string,
  args: string[],
  env: NodeJS.ProcessEnv = process.env,
): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile(
      file,
      args,
      { env, timeout: 30_000, maxBuffer: 2 * 1024 * 1024 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr.trim() || error.message));
          return;
        }
        resolve(stdout);
      },
    );
  });
}

async function logAction(fields: Record<string, unknown>): Promise<void> {
  await mkdir(join(home, ".logs/baby-menu"), { recursive: true });
  await appendFile(
    actionLog,
    `${JSON.stringify({ timestamp: new Date().toISOString(), ...fields })}\n`,
  );
}

function parseQuotas(output: string): QuotaRow[] {
  return output
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [provider = "", window = "", remaining = "", reset = ""] =
        line.split("\t");
      return { provider, window, remaining, reset };
    });
}

function commandSucceeds(file: string, args: string[]): Promise<boolean> {
  return new Promise((resolveResult) => {
    execFile(
      file,
      args,
      { env: process.env, timeout: 30_000, maxBuffer: 2 * 1024 * 1024 },
      (error) => resolveResult(!error),
    );
  });
}

function parseSchedules(
  output: string,
): Pick<
  OperationsDashboard,
  | "schedules"
  | "activeSchedules"
  | "problemSchedules"
  | "totalSchedules"
  | "aiSchedules"
> {
  const sections: ScheduleSection[] = [];
  let activeSchedules = 0;
  let problemSchedules = 0;
  let totalSchedules = 0;
  let aiSchedules = 0;
  let current: ScheduleSection | undefined;

  for (const line of output.split("\n")) {
    if (!line) continue;
    const [
      kind,
      first = "",
      second = "",
      third = "",
      fourth = "",
      fifth = "",
      sixth = "",
      seventh = "",
      eighth = "",
      ninth = "",
      tenth = "",
    ] = line.split("\t");
    if (kind === "summary") {
      activeSchedules = Number(first) || 0;
      problemSchedules = Number(second) || 0;
      totalSchedules = Number(third) || 0;
      aiSchedules = Number(fourth) || 0;
      continue;
    }
    if (kind === "section") {
      current = { name: first, jobs: [] };
      sections.push(current);
      continue;
    }
    if (kind === "job" && current) {
      const job: ScheduleJob = {
        name: first,
        remaining: second,
        status: third,
        runTarget: fourth === "launchd" && fifth ? fifth : null,
        toggleTarget: sixth === "launchd" && seventh ? seventh : null,
        toggleSource: sixth === "launchd" && eighth ? eighth : null,
        enabled: ninth === "true",
        ai: tenth === "true",
      };
      current.jobs.push(job);
    }
  }

  return {
    schedules: sections,
    activeSchedules,
    problemSchedules,
    totalSchedules,
    aiSchedules,
  };
}

function runTargetFrom(input: unknown): string {
  if (!input || typeof input !== "object" || !("target" in input)) {
    throw new Error("Missing schedule target");
  }
  const target = input.target;
  if (
    typeof target !== "string" ||
    !/^gui\/\d+\/[A-Za-z0-9._-]+$/.test(target)
  ) {
    throw new Error("Invalid schedule target");
  }
  return target;
}

function toggleRequestFrom(input: unknown): {
  target: string;
  enabled: boolean;
} {
  if (
    !input ||
    typeof input !== "object" ||
    !("target" in input) ||
    !("enabled" in input)
  ) {
    throw new Error("Missing schedule toggle request");
  }
  const target = input.target;
  const enabled = input.enabled;
  const expectedTarget = new RegExp(
    `^gui/${process.getuid()}/[A-Za-z0-9._-]+$`,
  );
  if (
    typeof target !== "string" ||
    !expectedTarget.test(target) ||
    typeof enabled !== "boolean"
  ) {
    throw new Error("Invalid schedule toggle request");
  }
  return { target, enabled };
}

function manageableSource(source: string): boolean {
  const resolvedSource = resolve(source);
  const allowedDirectories = [
    resolve(join(home, "Library/LaunchAgents")),
    resolve("/Library/LaunchAgents"),
  ];
  return (
    resolvedSource.endsWith(".plist") &&
    allowedDirectories.some(
      (directory) => dirname(resolvedSource) === directory,
    )
  );
}

export const actions = {
  async getDashboard(): Promise<OperationsDashboard> {
    const errors: string[] = [];
    const quotaResult = await execute("/bin/bash", [quotaScript], {
      ...process.env,
      AGENT_QUOTA_OUTPUT_ONLY: "1",
    }).catch((error: unknown) => {
      errors.push(error instanceof Error ? error.message : String(error));
      return "";
    });
    const scheduleResult = await execute("/usr/bin/python3", [
      schedulesScript,
    ]).catch((error: unknown) => {
      errors.push(error instanceof Error ? error.message : String(error));
      return "";
    });

    return {
      quotas: parseQuotas(quotaResult),
      ...parseSchedules(scheduleResult),
      errors,
      refreshedAt: new Date().toISOString(),
    };
  },

  async toggleSchedule(input: unknown): Promise<ToggleScheduleResult> {
    const { target, enabled } = toggleRequestFrom(input);
    const startedAt = Date.now();
    await logAction({
      action: "toggleSchedule",
      status: "requested",
      target,
      enabled,
    });

    try {
      const scheduleResult = await execute("/usr/bin/python3", [
        schedulesScript,
      ]);
      const dashboard = parseSchedules(scheduleResult);
      const job = dashboard.schedules
        .flatMap((section) => section.jobs)
        .find((candidate) => candidate.toggleTarget === target);
      if (!job?.toggleSource || !manageableSource(job.toggleSource)) {
        throw new Error("Schedule is not available to toggle");
      }

      if (enabled !== job.enabled) {
        if (enabled) {
          await execute("/bin/launchctl", ["enable", target]);
          if (!(await commandSucceeds("/bin/launchctl", ["print", target]))) {
            await execute("/bin/launchctl", [
              "bootstrap",
              target.slice(0, target.lastIndexOf("/")),
              job.toggleSource,
            ]);
          }
        } else {
          await execute("/bin/launchctl", ["disable", target]);
          if (await commandSucceeds("/bin/launchctl", ["print", target])) {
            await execute("/bin/launchctl", ["bootout", target]);
          }
        }
      }

      await logAction({
        action: "toggleSchedule",
        status: enabled ? "enabled" : "disabled",
        target,
        durationMs: Date.now() - startedAt,
      });
      return { target, enabled, logPath: actionLog };
    } catch (cause) {
      await logAction({
        action: "toggleSchedule",
        status: "failed",
        target,
        enabled,
        durationMs: Date.now() - startedAt,
        error: cause instanceof Error ? cause.message : String(cause),
      });
      throw cause;
    }
  },

  async runSchedule(input: unknown): Promise<RunScheduleResult> {
    const target = runTargetFrom(input);
    const startedAt = Date.now();
    await logAction({ action: "runSchedule", status: "requested", target });

    try {
      const scheduleResult = await execute("/usr/bin/python3", [
        schedulesScript,
      ]);
      const dashboard = parseSchedules(scheduleResult);
      const allowed = dashboard.schedules.some((section) =>
        section.jobs.some((job) => job.runTarget === target),
      );
      if (!allowed) throw new Error("Schedule is not available to run");

      const output = await execute("/bin/launchctl", [
        "kickstart",
        "-p",
        target,
      ]);
      const parsedPid = Number(output.trim());
      const pid = Number.isInteger(parsedPid) ? parsedPid : null;
      await logAction({
        action: "runSchedule",
        status: "started",
        target,
        pid,
        durationMs: Date.now() - startedAt,
      });
      return { target, pid, logPath: actionLog };
    } catch (cause) {
      await logAction({
        action: "runSchedule",
        status: "failed",
        target,
        durationMs: Date.now() - startedAt,
        error: cause instanceof Error ? cause.message : String(cause),
      });
      throw cause;
    }
  },
};
