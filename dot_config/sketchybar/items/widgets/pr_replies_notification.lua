local constants = require("constants")
local colors = require("config.colors")
local dimens = require("config.dimens")

-- Flex-gap convention: leading 0, glyph<->number 2, trailing = dimens.padding.gap.
local pr_replies = sbar.add("item", "widgets.pr_replies_notification", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	icon = {
		string = "󰭹",
		color = colors.blue,
		padding_left = 0,
		padding_right = 2,
	},
	label = {
		string = "􀆅",
		padding_left = 0,
		padding_right = 0,
	},
	-- Slower than the review badge: this is one GraphQL call over every open PR, not a search hit.
	update_freq = 600,
	script = "~/.config/sketchybar/items/widgets/pr_replies_notification.sh",
	click_script = "~/.config/sketchybar/items/widgets/pr-replies-click.sh",
	drawing = true,
})

pr_replies:subscribe({ "forced", "routine", "system_woke" })
