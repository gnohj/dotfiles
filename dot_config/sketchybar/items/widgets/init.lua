local colors = require("config.colors")
local settings = require("config.settings")
local groups = require("items.widgets.groups")

local DND_CLICK = "~/.config/sketchybar/items/widgets/dnd-click.sh"

groups.edge("status", 0, DND_CLICK)
require("items.widgets.calendar")
require("items.widgets.dnd") -- Do Not Disturb (Focus) toggle, a moon, red while Focus is off and blue while on
require("items.widgets.tailscale") -- Tailscale tailnet connection indicator
require("items.widgets.vpn") -- PIA VPN exit-location indicator
require("items.widgets.wifi") -- WiFi status icon + details popover
require("items.widgets.bluetooth") -- Bluetooth power toggle + connected/paired device panel
require("items.widgets.battery")
require("items.widgets.volume")
require("items.widgets.mic")
groups.edge("status", 8, DND_CLICK)
groups.spacer()
groups.edge("vps", 0)
groups.toggle("vps")
groups.uptime("vps", "widgets.vps_uptime")
local vps = require("items.widgets.vps")
vps.temp()
vps.disk()
vps.memory()
vps.cpu()
groups.glyph("vps", settings.icons.text.linux, colors.white)
groups.edge("vps", 12)
groups.spacer()
groups.edge("system", 0)
groups.toggle("system")
require("items.widgets.uptime")
require("items.widgets.cpu_temp")
require("items.widgets.disk")
require("items.widgets.memory")
require("items.widgets.cpu")
groups.glyph("system", settings.icons.text.apple, colors.cyan, 1)
groups.edge("system", 12)
groups.spacer("push")
groups.edge("push", 10)
local push = require("items.widgets.github_notification")
groups.edge("push", 10)
groups.build()
push()
