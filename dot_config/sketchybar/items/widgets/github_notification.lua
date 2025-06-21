local constants = require("constants")

sbar.add("item", constants.items.GITHUB_NOTIFICATION, {
	position = "right",
	script = "~/.config/sketchybar/items/widgets/github_notification.sh",
	drawing = false,
})
