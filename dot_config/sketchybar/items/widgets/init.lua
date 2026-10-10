require("items.widgets.calendar")
require("items.widgets.battery")
require("items.widgets.dnd") -- Do Not Disturb (Focus) toggle
require("items.widgets.tailscale") -- Tailscale tailnet connection indicator
require("items.widgets.vpn") -- PIA VPN exit-location indicator
require("items.widgets.wifi") -- WiFi status icon + details popover
require("items.widgets.bluetooth") -- Bluetooth power toggle + connected/paired device panel
require("items.widgets.agent_quota")
require("items.widgets.volume")
require("items.widgets.mic")
local vps = require("items.widgets.vps") -- each dev-box metric sits right of its local twin
vps.temp()
require("items.widgets.cpu_temp")
vps.disk()
require("items.widgets.disk")
vps.memory()
require("items.widgets.memory")
vps.cpu()
require("items.widgets.cpu")
require("items.widgets.package_notification") -- Unified Brew + MAS + Mise
require("items.widgets.pr_review_notification") -- GitHub PR review requests
require("items.widgets.github_notification")
