export type QuotaRow = {
  provider: string;
  window: string;
  remaining: string;
  reset: string;
};

export type ScheduleJob = {
  name: string;
  remaining: string;
  status: string;
  runTarget: string | null;
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

export type OperationsDashboard = {
  quotas: QuotaRow[];
  schedules: ScheduleSection[];
  activeSchedules: number;
  problemSchedules: number;
  totalSchedules: number;
  errors: string[];
  refreshedAt: string;
};
