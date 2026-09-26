import type { RefreshableBabyMenuWidget } from "@babymenu/contracts";
import { OperationsView } from "./components";
import { refreshOperations } from "./refresh";

export const operationsWidget: RefreshableBabyMenuWidget = {
  id: "operations",
  title: "usage",
  render: () => (
    <OperationsView
      variant={
        document.documentElement.dataset.windowMode === "sidebar"
          ? "usage"
          : "all"
      }
    />
  ),
  viewRefreshIntervalMs: 30_000,
  refreshView: refreshOperations,
};

export const accountsWidget: RefreshableBabyMenuWidget = {
  id: "operations-accounts",
  title: "accounts",
  render: () => <OperationsView variant="accounts" />,
  viewRefreshIntervalMs: 30_000,
  refreshView: refreshOperations,
};

export const cronWidget: RefreshableBabyMenuWidget = {
  id: "operations-cron",
  title: "cron",
  render: () => <OperationsView variant="cron" />,
};
