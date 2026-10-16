local groups = require("items.widgets.groups")

local DND_CLICK = "~/.config/sketchybar/items/widgets/dnd-click.sh"

groups.edge("status", 0, DND_CLICK)
require("items.widgets.calendar")
require("items.widgets.battery")
require("items.widgets.dnd") -- Do Not Disturb (Focus) toggle, shown as the status group's border
require("items.widgets.tailscale") -- Tailscale tailnet connection indicator
require("items.widgets.vpn") -- PIA VPN exit-location indicator
require("items.widgets.wifi") -- WiFi status icon + details popover
require("items.widgets.bluetooth") -- Bluetooth power toggle + connected/paired device panel
require("items.widgets.volume")
require("items.widgets.mic")
groups.edge("status", 8, DND_CLICK)
groups.spacer()
groups.edge("vps", 0)
local vps = require("items.widgets.vps")
vps.temp()
vps.disk()
vps.memory()
vps.cpu()
groups.edge("vps", 12)
groups.spacer()
groups.edge("system", 0)
require("items.widgets.cpu_temp")
require("items.widgets.disk")
require("items.widgets.memory")
require("items.widgets.cpu")
groups.edge("system", 12)
groups.spacer()
groups.edge("notifications", 0)
require("items.widgets.agent_quota")
require("items.widgets.package_notification") -- Unified Brew + MAS + Mise
require("items.widgets.pr_review_notification") -- GitHub PR review requests
require("items.widgets.github_notification")
groups.edge("notifications", 8)
groups.build()
