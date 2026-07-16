local colors = require("config.colors")
local dimens = require("config.dimens")

-- Flex-gap convention: leading 0, glyph<->check 2, trailing = dimens.padding.gap.
local health_check = sbar.add("item", "widgets.health_check_notification", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	icon = {
		string = "󰥔",
		color = colors.green,
		padding_left = 0,
		padding_right = 2,
	},
	label = {
		string = "􀆅",
		padding_left = 0,
		padding_right = 0,
	},
	update_freq = 1800,
	script = "~/.config/sketchybar/items/widgets/health_check_notification.sh",
	drawing = true,
})

health_check:subscribe({ "forced", "routine", "system_woke" })
