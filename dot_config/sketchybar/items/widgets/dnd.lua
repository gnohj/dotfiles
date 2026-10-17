local colors = require("config.colors")
local dimens = require("config.dimens")

local dnd = sbar.add("item", "widgets.dnd", {
	position = "right",
	drawing = false,
	-- Calendar label already trails padding.label; top up to the usual gap.
	padding_left = dimens.padding.gap - dimens.padding.label,
	padding_right = dimens.padding.label,
	updates = "on",
	icon = {
		string = "􀆺", -- SF Symbol moon.fill (matches Apple's Focus icon)
		color = colors.red,
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		drawing = false,
	},
	update_freq = 5,
	script = "~/.config/sketchybar/items/widgets/dnd.sh",
	click_script = "~/.config/sketchybar/items/widgets/dnd-click.sh",
})

dnd:subscribe({ "forced", "routine", "system_woke", "dnd_changed" })
