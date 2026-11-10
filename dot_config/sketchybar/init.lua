require("install.sbar")

---@diagnostic disable-next-line: lowercase-global
sbar = require("sketchybar")

sbar.begin_config()
sbar.hotload(true)

require("constants")
require("config")
require("bar")
require("default")
require("items")

local supersede = require("lib.supersede")
supersede.exit_if_superseded()
sbar.end_config()
supersede.watch()
sbar.event_loop()
