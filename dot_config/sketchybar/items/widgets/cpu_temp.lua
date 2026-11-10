local constants = require("constants")
local colors = require("config.colors")
local resources = require("lib.resources")

local cpu_temp = sbar.add("item", constants.items.CPU_TEMP, {
	position = "right",
	padding_left = -5,
	icon = { string = "󰔏", color = colors.blue, padding_left = 3, padding_right = 5, font = { size = 14.0 } },
	label = { string = "--°", color = colors.cyan, padding_left = 0, padding_right = 8 },
})

resources.attach("temp", cpu_temp, "°", "--°")
