local constants = require("constants")
local dimens = require("config.dimens")

-- Flex-gap convention: leading 0, glyph<->number 2, trailing = dimens.padding.gap.
sbar.add("item", constants.items.GITHUB_NOTIFICATION, {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	icon = { padding_left = 0, padding_right = 2 },
	label = { padding_left = 0, padding_right = 0 },
	script = "~/.config/sketchybar/items/widgets/github_notification.sh",
	drawing = false,
})
