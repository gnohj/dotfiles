import { execFile } from "node:child_process";
import {
  appendFile,
  mkdir,
  readdir,
  readFile,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import {
  claudeFromDesktop,
  claudeFromStatusline,
  claudeFromUsage,
  selectClaudeCard,
  type Captures,
  type DesktopSample,
} from "./claude-quota";
import type {
  OperationsDashboard,
  QuotaColors,
  QuotaProvider,
  RunScheduleResult,
  ScheduleJob,
  ScheduleSection,
  ToggleScheduleResult,
  TokenRow,
  TokenStatus,
} from "./types";

const home = homedir();
const quotaAxiFallback = join(
  home,
  ".local/share/mise/installs/npm-quota-axi/latest/bin/quota-axi",
);
const planUsageHistory = join(
  home,
  "Library/Application Support/Claude/plan-usage-history.json",
);
const capturedResetDirectory = join(home, ".logs/sketchybar");
const schedulesScript = join(
  home,
  ".config/sketchybar/items/widgets/schedules-panel.py",
);
const claudeAccountScript = join(home, ".local/bin/claude-account");
const paletteFile = join(
  home,
  ".config/colorscheme/active/active-colorscheme.sh",
);
const actionLog = join(home, ".logs/baby-menu/operations.log");
const disabledSchedulesDirectory = join(
  home,
  ".local/state/baby-menu/disabled-schedules",
);
const defaultQuotaColors: QuotaColors = {
  danger: "#ff6a7a",
  orange: "#f5a65b",
  warning: "#ffd86b",
  live: "#6ae3b6",
  groups: ["#a3b8c6", "#c0aed2", "#a7cfbd", "#dab183", "#88a1b2"],
};

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

// quota-axi exits non-zero whenever any provider needs auth, so its JSON is read regardless; launchd's minimal PATH may lack the shim.
function runQuotaAxi(
  file: string,
  args: string[],
  env: NodeJS.ProcessEnv,
): Promise<string> {
  return new Promise((resolveOutput, reject) => {
    execFile(
      file,
      args,
      { env, timeout: 30_000, maxBuffer: 8 * 1024 * 1024 },
      (error, stdout, stderr) => {
        if (stdout.trim()) resolveOutput(stdout);
        else
          reject(
            error ?? new Error(stderr.trim() || "quota-axi returned nothing"),
          );
      },
    );
  });
}

// quota-axi is a `#!/usr/bin/env node` script, and an app launched outside a shell has no node on its PATH.
const nodePath = [
  "/opt/homebrew/bin",
  join(home, ".local/bin"),
  join(home, ".local/share/mise/shims"),
].join(":");

async function quotaAxi(
  args: string[],
  baseEnv: NodeJS.ProcessEnv = process.env,
): Promise<QuotaProvider[]> {
  const env = {
    ...baseEnv,
    PATH: `${nodePath}:${baseEnv.PATH ?? "/usr/bin:/bin"}`,
  };
  const fullArgs = [...args, "--json", "--full"];
  const output = await runQuotaAxi("quota-axi", fullArgs, env).catch(
    (error: NodeJS.ErrnoException) =>
      error.code === "ENOENT"
        ? runQuotaAxi(quotaAxiFallback, fullArgs, env)
        : Promise.reject(error),
  );
  const parsed = JSON.parse(output) as {
    providers?: QuotaProvider[];
  };
  return parsed.providers ?? [];
}

const CAPTURE_NAME =
  /^claude_(?:pct|reset)_(?:personal|work)_(?:five_hour|seven_day)$/;
const CAPTURE_VALUE = /^[0-9]+(?:\.[0-9]+)?$/;
// The work account's sessions mostly run on the VPS, whose statusline writes there, so its captures are read too and the newest file wins.
const captureHosts = (process.env.BABY_MENU_CAPTURE_HOSTS ?? "dev-box")
  .split(",")
  .filter(Boolean);
const remoteCaptureScript =
  'cd "$HOME/.logs/sketchybar" 2>/dev/null || exit 0; for f in claude_pct_* claude_reset_*; do [ -f "$f" ] && printf "%s\\t%s\\t%s\\n" "$f" "$(stat -c %Y "$f")" "$(cat "$f")"; done';

async function localCaptures(): Promise<Captures> {
  const captures: Captures = new Map();
  const names = await readdir(capturedResetDirectory).catch(
    () => [] as string[],
  );
  await Promise.all(
    names
      .filter((name) => CAPTURE_NAME.test(name))
      .map(async (name) => {
        const file = join(capturedResetDirectory, name);
        const [raw, info] = await Promise.all([
          readFile(file, "utf8").catch(() => ""),
          stat(file).catch(() => undefined),
        ]);
        const value = raw.trim();
        if (info && CAPTURE_VALUE.test(value))
          captures.set(name, { value, mtimeMs: info.mtimeMs });
      }),
  );
  return captures;
}

function remoteCaptures(host: string): Promise<Captures> {
  return new Promise((resolveCaptures) => {
    execFile(
      "/usr/bin/ssh",
      [
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=4",
        "-o",
        "ClearAllForwardings=yes",
        host,
        remoteCaptureScript,
      ],
      { timeout: 10_000, maxBuffer: 256 * 1024 },
      (_error, stdout) => {
        const captures: Captures = new Map();
        for (const line of stdout.split("\n")) {
          const [name = "", mtime = "", value = ""] = line.split("\t");
          const seconds = Number(mtime);
          if (
            CAPTURE_NAME.test(name) &&
            CAPTURE_VALUE.test(value.trim()) &&
            Number.isFinite(seconds)
          ) {
            captures.set(name, {
              value: value.trim(),
              mtimeMs: seconds * 1000,
            });
          }
        }
        resolveCaptures(captures);
      },
    );
  });
}

async function statuslineCaptures(): Promise<Captures> {
  const all: Captures[] = await Promise.all([
    localCaptures(),
    ...captureHosts.map((host) => remoteCaptures(host)),
  ]);
  const merged: Captures = new Map();
  for (const captures of all) {
    for (const [name, capture] of captures) {
      const current = merged.get(name);
      if (!current || capture.mtimeMs > current.mtimeMs)
        merged.set(name, capture);
    }
  }
  return merged;
}

// Before any statusline capture exists, the personal card falls back to the desktop app's own usage history.
async function claudePersonalFromDesktop(
  generatedAtMs: number,
): Promise<QuotaProvider | undefined> {
  const history = JSON.parse(
    await readFile(planUsageHistory, "utf8").catch(() => "{}"),
  ) as { samples?: DesktopSample[] };
  return claudeFromDesktop(history.samples?.at(-1), generatedAtMs);
}

async function quotaProviders(errors: string[]): Promise<QuotaProvider[]> {
  let generatedAtMs = Date.now();
  const failed = (error: unknown): QuotaProvider[] => {
    errors.push(error instanceof Error ? error.message : String(error));
    return [];
  };
  const [captures, work, others, personalUsage, workUsage, desktop] =
    await Promise.all([
      statuslineCaptures(),
      quotaAxi(["--provider", "claude"], {
        ...process.env,
        CLAUDE_ACCOUNT: "work",
        CLAUDE_CONFIG_DIR: join(home, ".claude-work"),
      }).catch(failed),
      quotaAxi([]).catch(failed),
      execute(claudeAccountScript, ["usage", "personal"]).catch(() => ""),
      execute(claudeAccountScript, ["usage", "work"]).catch(() => ""),
      claudePersonalFromDesktop(generatedAtMs).catch(() => undefined),
    ]);
  generatedAtMs = Date.now();
  const personal = selectClaudeCard("personal", generatedAtMs, [
    claudeFromStatusline(captures, "personal", generatedAtMs),
    claudeFromUsage(personalUsage, "personal", generatedAtMs),
    desktop,
  ]);
  const workCard = selectClaudeCard("work", generatedAtMs, [
    claudeFromStatusline(captures, "work", generatedAtMs),
    claudeFromUsage(workUsage, "work", generatedAtMs),
    ...work,
  ]);
  // The default claude reading is the Keychain-locked personal login, which the statusline or desktop card already covers.
  const rest = others.filter((provider) => provider.provider !== "claude");
  return [
    ...(personal ? [personal] : []),
    ...(workCard ? [workCard] : []),
    ...rest.filter((provider) => !provider.notSetUp),
  ];
}

async function logAction(fields: Record<string, unknown>): Promise<void> {
  await mkdir(join(home, ".logs/baby-menu"), { recursive: true });
  await appendFile(
    actionLog,
    `${JSON.stringify({ timestamp: new Date().toISOString(), ...fields })}\n`,
  );
}

function parseQuotaColors(output: string): QuotaColors {
  const values = Object.fromEntries(
    [
      ...output.matchAll(
        /^(gnohj_color(?:01|02|03|04|05|06|11|12|18))=(#[0-9a-f]{6})$/gim,
      ),
    ].map(([, name, color]) => [name, color]),
  );
  return {
    danger: values.gnohj_color11 ?? defaultQuotaColors.danger,
    orange: values.gnohj_color06 ?? defaultQuotaColors.orange,
    warning: values.gnohj_color12 ?? defaultQuotaColors.warning,
    live: values.gnohj_color02 ?? defaultQuotaColors.live,
    groups: ["04", "01", "03", "05", "18"].map(
      (key, index) =>
        values[`gnohj_color${key}`] ?? defaultQuotaColors.groups[index],
    ),
  };
}

// token-check exits 1 whenever any account is short of "ok", but still prints every row.
function executeIgnoringExit(file: string, args: string[]): Promise<string> {
  return new Promise((resolveOutput) => {
    execFile(
      file,
      args,
      { env: process.env, timeout: 30_000, maxBuffer: 1024 * 1024 },
      (_error, stdout) => resolveOutput(stdout),
    );
  });
}

const tokenStatuses: readonly TokenStatus[] = [
  "ok",
  "warn",
  "critical",
  "expired",
  "missing",
];

function parseTokens(output: string): TokenRow[] {
  return output
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [account = "", stored = "", expires = "", status = ""] =
        line.split("\t");
      const age = /\((\d+)d ago\)/.exec(stored);
      const expiry = /expires ~(\S+) \((-?\d+)d\)/.exec(expires);
      return {
        account,
        status: (tokenStatuses as string[]).includes(status)
          ? (status as TokenStatus)
          : "missing",
        daysLeft: expiry ? Number(expiry[2]) : null,
        storedDaysAgo: age ? Number(age[1]) : null,
        expires: expiry ? (expiry[1] ?? "") : "",
      };
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
  const uid = process.getuid?.();
  const expectedTarget = new RegExp(`^gui/${uid}/[A-Za-z0-9._-]+$`);
  if (
    uid === undefined ||
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

async function persistSchedulePreference(
  target: string,
  enabled: boolean,
): Promise<void> {
  const label = target.slice(target.lastIndexOf("/") + 1);
  const marker = join(disabledSchedulesDirectory, `${label}.disabled`);
  await mkdir(disabledSchedulesDirectory, { recursive: true });
  if (enabled) {
    await rm(marker, { force: true });
    return;
  }
  await writeFile(marker, "");
}

export const actions = {
  async getDashboard(): Promise<OperationsDashboard> {
    const errors: string[] = [];
    const providers = await quotaProviders(errors);
    const scheduleResult = await execute("/usr/bin/python3", [
      schedulesScript,
    ]).catch((error: unknown) => {
      errors.push(error instanceof Error ? error.message : String(error));
      return "";
    });
    const tokenResult = await executeIgnoringExit("/bin/bash", [
      claudeAccountScript,
      "token-check",
    ]);
    const quotaColors = await readFile(paletteFile, "utf8")
      .then(parseQuotaColors)
      .catch((error: unknown) => {
        errors.push(error instanceof Error ? error.message : String(error));
        return defaultQuotaColors;
      });
    const tokens = parseTokens(tokenResult);
    if (!tokens.length)
      errors.push("claude-account token-check returned no rows");

    return {
      quotaProviders: providers,
      quotaGeneratedAt: new Date().toISOString(),
      quotaColors,
      tokens,
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

      await persistSchedulePreference(target, enabled);

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
