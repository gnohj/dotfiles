export type QuotaPace = {
  status?: string;
  timeRemainingPercent?: number;
  elapsedPercent?: number;
  projectedExhaustedAt?: string;
  projectionConfidence?: string;
};

export type QuotaWindow = {
  id: string;
  label: string;
  kind?: string;
  percentRemaining?: number;
  percentUsed?: number;
  resetsAt?: string;
  resetText?: string;
  windowSeconds?: number;
  pace?: QuotaPace;
};

export type QuotaRunway = {
  status: string;
  usableRunwaySeconds?: number;
};

export type QuotaAvailability = {
  scope: string;
  status: string;
  effectivePercentRemaining?: number;
  limitingWindowIds?: string[];
  runway?: QuotaRunway;
};

export type QuotaProvider = {
  provider: string;
  notSetUp?: boolean;
  accountKey?: string;
  plan?: string;
  source?: string;
  windows: QuotaWindow[];
  credits?: { remaining?: number; unlimited?: boolean; unit?: string };
  state: {
    status: string;
    reused?: boolean;
    refreshedAt?: string;
    error?: string;
    reason?: string;
    retryAfter?: string;
    remedyCommand?: string;
  };
  quotaSemantics?: {
    status: string;
    unresolvedWindowIds?: string[];
    effectiveAvailability?: QuotaAvailability[];
  };
};

export type QuotaColors = {
  danger: string;
  orange: string;
  warning: string;
  live: string;
  groups: string[];
};

export type TokenStatus = "ok" | "warn" | "critical" | "expired" | "missing";

export type TokenRow = {
  account: string;
  status: TokenStatus;
  daysLeft: number | null;
  storedDaysAgo: number | null;
  expires: string;
};

export type ScheduleJob = {
  name: string;
  remaining: string;
  status: string;
  runTarget: string | null;
  toggleTarget: string | null;
  toggleSource: string | null;
  enabled: boolean;
  ai: boolean;
};

export type ScheduleSection = {
  name: string;
  jobs: ScheduleJob[];
};

export type RunScheduleResult = {
  target: string;
  pid: number | null;
  logPath: string;
};

export type ToggleScheduleResult = {
  target: string;
  enabled: boolean;
  logPath: string;
};

export type OperationsDashboard = {
  quotaProviders: QuotaProvider[];
  quotaGeneratedAt: string;
  quotaColors: QuotaColors;
  tokens: TokenRow[];
  schedules: ScheduleSection[];
  activeSchedules: number;
  problemSchedules: number;
  totalSchedules: number;
  aiSchedules: number;
  errors: string[];
  refreshedAt: string;
};
