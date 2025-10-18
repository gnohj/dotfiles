local constants = require("constants")

sbar.add("item", constants.items.BREW_NOTIFICATION, {
	position = "right",
	padding_right = 4,
	icon = {
		string = "􀐛",
		padding_left = 0,
		padding_right = 1,
	},
	label = {
		padding_left = 1,
		padding_right = 0,
	},
	update_freq = 3600, -- Update every hour
	script = "~/.config/sketchybar/items/widgets/brew_notification.sh",
	drawing = true,
})
