local colors = require("config.colors")

-- tmux-dash (AI agents) notification widget
local tmux_dash = sbar.add("item", "widgets.tmux_dash_notification", {
	position = "right",
	padding_right = 12,
	updates = "on",
	icon = {
		string = "󰚩",
		color = colors.blue,
		padding_left = 0,
		padding_right = 1,
	},
	label = {
		string = "0",
		padding_left = 1,
		padding_right = 0,
	},
	update_freq = 10,
	script = "~/.config/sketchybar/items/widgets/tmux-dash_notification.sh",
	drawing = true,
})

tmux_dash:subscribe({ "forced", "routine", "system_woke" })
