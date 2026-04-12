local colors = require("config.colors")

-- Recon (Claude Code agents) notification widget
local recon = sbar.add("item", "widgets.recon_notification", {
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
	script = "~/.config/sketchybar/items/widgets/recon_notification.sh",
	drawing = true,
})

recon:subscribe({ "forced", "routine", "system_woke" })
