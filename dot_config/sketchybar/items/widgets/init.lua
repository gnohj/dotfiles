require("items.widgets.calendar")
require("items.widgets.battery")
require("items.widgets.uptime") -- Right-side items lay out right-to-left, so this order puts it between dnd and battery
require("items.widgets.dnd") -- Do Not Disturb (Focus) toggle
require("items.widgets.tailscale") -- Tailscale tailnet connection indicator
require("items.widgets.vpn") -- PIA VPN exit-location indicator
require("items.widgets.wifi") -- WiFi status icon + details popover
require("items.widgets.bluetooth") -- Bluetooth power toggle + connected/paired device panel
require("items.widgets.disk")
require("items.widgets.memory")
require("items.widgets.cpu")
require("items.widgets.volume")
require("items.widgets.mic")
require("items.widgets.agent_quota") -- Claude (work + personal), Codex, Copilot quota headroom
require("items.widgets.errors_notification") -- Unified errors: service-log errors + orphan processes
require("items.widgets.package_notification") -- Unified Brew + MAS + Mise
require("items.widgets.pr_review_notification") -- GitHub PR review requests
require("items.widgets.github_notification")
