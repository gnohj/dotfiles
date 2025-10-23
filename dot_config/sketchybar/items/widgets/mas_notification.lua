local constants = require("constants")

sbar.add("item", constants.items.MAS_NOTIFICATION, {
	position = "right",
	padding_right = 8,
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
	script = "~/.config/sketchybar/items/widgets/mas_notification.sh",
	drawing = true,
})
