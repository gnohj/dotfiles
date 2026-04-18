local colors = require("config.colors")

-- Dirty repos notification widget
local dirty_repos = sbar.add("item", "widgets.dirty_repos_notification", {
	position = "right",
	padding_right = 12,
	updates = "on",
	icon = {
		string = "󰘬",
		color = colors.cyan,
		padding_left = 0,
		padding_right = 1,
	},
	label = {
		string = "?",
		padding_left = 1,
		padding_right = 0,
	},
	update_freq = 300,
	script = "~/.config/sketchybar/items/widgets/dirty_repos_notification.sh",
	drawing = true,
})

dirty_repos:subscribe({ "forced", "routine", "system_woke" })
