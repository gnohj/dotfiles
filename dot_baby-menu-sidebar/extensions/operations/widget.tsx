import type { RefreshableBabyMenuWidget } from "@babymenu/contracts";
import { OperationsView } from "./components";
import { refreshOperations } from "./refresh";
import { applyHostTheme } from "./host-theme";

export const operationsWidget: RefreshableBabyMenuWidget = {
  id: "operations",
  title: "usage",
  render: () => {
    applyHostTheme();
    return (
      <OperationsView
        variant={
          document.documentElement.dataset.windowMode === "sidebar"
            ? "usage"
            : "all"
        }
      />
    );
  },
  viewRefreshIntervalMs: 30_000,
  refreshView: refreshOperations,
};

export const accountsWidget: RefreshableBabyMenuWidget = {
  id: "operations-accounts",
  title: "accounts",
  render: () => {
    applyHostTheme();
    return <OperationsView variant="accounts" />;
  },
  viewRefreshIntervalMs: 30_000,
  refreshView: refreshOperations,
};

export const cronWidget: RefreshableBabyMenuWidget = {
  id: "operations-cron",
  title: "cron",
  render: () => {
    applyHostTheme();
    return <OperationsView variant="cron" />;
  },
};
