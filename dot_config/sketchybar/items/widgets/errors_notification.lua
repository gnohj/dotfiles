local colors = require("config.colors")
local dimens = require("config.dimens")

-- Unified errors badge: service-log errors + orphan processes; click opens a grouped popup.
local errors = sbar.add("item", "widgets.errors_notification", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	icon = {
		string = "􀇾", -- exclamationmark.triangle
		color = colors.green,
		padding_left = 0,
		padding_right = 2,
	},
	label = {
		string = "􀆅",
		padding_left = 0,
		padding_right = 0,
	},
	update_freq = 60,
	popup = { align = "center" },
	script = "~/.config/sketchybar/items/widgets/errors_notification.sh",
	click_script = "~/.config/sketchybar/items/widgets/errors-click.sh",
})

errors:subscribe({ "forced", "routine", "system_woke" })
