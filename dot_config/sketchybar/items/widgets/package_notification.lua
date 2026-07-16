local constants = require("constants")
local dimens = require("config.dimens")

-- Unified package notification widget (Brew + MAS + Mise).
-- Flex-gap convention: leading 0, glyph<->number 2, trailing = dimens.padding.gap.
local package_notification = sbar.add("item", "widgets.package_notification", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	icon = {
		string = "􀐛", -- Homebrew icon (same as original brew widget)
		padding_left = 0,
		padding_right = 2,
	},
	label = {
		padding_left = 0,
		padding_right = 0,
	},
	update_freq = 3600,
	script = "~/.config/sketchybar/items/widgets/package_notification.sh",
	drawing = true,
})

package_notification:subscribe({ "forced", "routine" })

-- Custom event for manual package updates
package_notification:subscribe("package_update")
