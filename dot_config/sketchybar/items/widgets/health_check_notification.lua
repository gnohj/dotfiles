local colors = require("config.colors")

-- Health check notification widget
local health_check = sbar.add("item", "widgets.health_check_notification", {
	position = "right",
	padding_right = 12,
	updates = "on",
	icon = {
		string = "󰥔",
		color = colors.green,
		padding_left = 0,
		padding_right = 1,
	},
	label = {
		string = "􀆅",
		padding_left = 1,
		padding_right = 0,
	},
	update_freq = 1800,
	script = "~/.config/sketchybar/items/widgets/health_check_notification.sh",
	drawing = true,
})

health_check:subscribe({ "forced", "routine", "system_woke" })
