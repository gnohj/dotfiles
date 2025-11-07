local constants = require("constants")

-- Unified package notification widget (Brew + MAS + Mise)
local package_notification = sbar.add("item", "widgets.package_notification", {
	position = "right",
	padding_right = 8,
	icon = {
		string = "􀐛", -- Homebrew icon (same as original brew widget)
		padding_left = 0,
		padding_right = 1,
	},
	label = {
		padding_left = 1,
		padding_right = 0,
	},
	update_freq = 3600, -- Update every hour
	script = "~/.config/sketchybar/items/widgets/package_notification.sh",
	drawing = true,
})

-- Subscribe to forced refresh and routine updates
package_notification:subscribe({ "forced", "routine" })

-- Add custom event for manual package updates
package_notification:subscribe("package_update")
