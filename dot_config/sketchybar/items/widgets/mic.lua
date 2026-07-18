local constants = require("constants")

local mic = sbar.add("item", constants.items.MIC or "mic", {
	position = "right",
	updates = true,
	update_freq = 10,
	padding_right = 4,
	icon = {
		padding_left = 0,
	},
	label = {
		drawing = true,
		padding_left = -8,
		padding_right = 12,
		font = "MesloLGM Nerd Font:Regular:12.0",
	},
	script = "~/.config/sketchybar/items/widgets/mic.sh",
	click_script = "~/.config/sketchybar/items/widgets/mic-click.sh",
})

mic:subscribe("volume_change")
