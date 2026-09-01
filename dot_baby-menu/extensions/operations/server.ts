import { execFile } from "node:child_process";
import { appendFile, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  OperationsDashboard,
  QuotaRow,
  RunScheduleResult,
  ScheduleJob,
  ScheduleSection,
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

function parseSchedules(
  output: string,
): Pick<
  OperationsDashboard,
  "schedules" | "activeSchedules" | "problemSchedules" | "totalSchedules"
> {
  const sections: ScheduleSection[] = [];
  let activeSchedules = 0;
  let problemSchedules = 0;
  let totalSchedules = 0;
  let current: ScheduleSection | undefined;

  for (const line of output.split("\n")) {
    if (!line) continue;
    const [kind, first = "", second = "", third = "", fourth = "", fifth = ""] =
      line.split("\t");
    if (kind === "summary") {
      activeSchedules = Number(first) || 0;
      problemSchedules = Number(second) || 0;
      totalSchedules = Number(third) || 0;
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
      };
      current.jobs.push(job);
    }
  }

  return {
    schedules: sections,
    activeSchedules,
    problemSchedules,
    totalSchedules,
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
