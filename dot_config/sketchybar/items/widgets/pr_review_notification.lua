local constants = require("constants")
local colors = require("config.colors")
local dimens = require("config.dimens")

-- Flex-gap convention: leading 0, glyph<->number 2, trailing = dimens.padding.gap.
local pr_review = sbar.add("item", "widgets.pr_review_notification", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	icon = {
		string = "",
		color = colors.blue,
		padding_left = 0,
		padding_right = 2,
	},
	label = {
		string = "?",
		padding_left = 0,
		padding_right = 0,
	},
	update_freq = 300,
	script = "~/.config/sketchybar/items/widgets/pr_review_notification.sh",
	drawing = true,
})

pr_review:subscribe({ "forced", "routine", "system_woke" })
