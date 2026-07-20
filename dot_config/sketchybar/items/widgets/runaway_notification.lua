local colors = require("config.colors")
local dimens = require("config.dimens")

-- Runaway alert: hidden until runaway_notification.sh flags a high-CPU pane-escaped process and sets a red count; click opens a popup listing each runaway (comm · pid · %core · cwd).
local runaway = sbar.add("item", "widgets.runaway_notification", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	drawing = false,
	icon = {
		string = "􀇾", -- exclamationmark.triangle
		color = colors.red,
		padding_left = 0,
		padding_right = 2,
	},
	label = {
		string = "0",
		padding_left = 0,
		padding_right = 0,
	},
	update_freq = 60,
	popup = { align = "center" },
	script = "~/.config/sketchybar/items/widgets/runaway_notification.sh",
	click_script = "~/.config/sketchybar/items/widgets/runaway-click.sh",
})

runaway:subscribe({ "forced", "routine", "system_woke" })
