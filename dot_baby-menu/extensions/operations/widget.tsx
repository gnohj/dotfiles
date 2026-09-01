import type { RefreshableBabyMenuWidget } from "@babymenu/contracts";
import { OperationsView } from "./components";
import { refreshOperations } from "./refresh";

export const operationsWidget: RefreshableBabyMenuWidget = {
  id: "operations",
  title: "operations",
  render: () => <OperationsView />,
  viewRefreshIntervalMs: 30_000,
  refreshView: refreshOperations,
};
