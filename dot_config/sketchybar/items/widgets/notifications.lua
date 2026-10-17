local groups = require("items.widgets.groups")

groups.edge("notifications", 8)
groups.toggle("notifications")
require("items.widgets.pr_review_notification") -- GitHub PR review requests
require("items.widgets.package_notification") -- Unified Brew + MAS + Mise
require("items.widgets.agent_quota")
groups.edge("notifications", 0)
groups.spacer("notifications")
