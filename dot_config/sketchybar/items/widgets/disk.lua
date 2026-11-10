local constants = require("constants")
local colors = require("config.colors")
local resources = require("lib.resources")

local disk = sbar.add("item", constants.items.DISK, {
	position = "right",
	padding_left = -12,
	padding_right = 0,
	icon = {
		font = { size = 14.0 },
		string = "󰋊",
		color = colors.blue,
		padding_right = 2,
	},
	label = {
		string = "??%",
		color = colors.cyan,
		padding_left = 0,
		-- Real padding, not the trailing spaces this used to append: a glyph is not a spacing unit.
		padding_right = 10,
	},
})

resources.attach("disk", disk, "%  ", "--")
