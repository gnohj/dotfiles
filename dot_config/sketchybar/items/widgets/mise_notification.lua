local constants = require("constants")

sbar.add("item", constants.items.MISE_NOTIFICATION, {
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
	script = "~/.config/sketchybar/items/widgets/mise_notification.sh",
	drawing = true,
	updates = true, -- Enable updates on events
})

sbar.subscribe(constants.items.MISE_NOTIFICATION, "mise_update")
