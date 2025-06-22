local constants = require("constants")

local mic = sbar.add("item", constants.items.MIC or "mic", {
	position = "right",
	updates = true,
	update_freq = 10,
	label = {
		drawing = true,
		padding_left = 0, -- Minimal space between icon and text
		padding_right = 10, -- More space after text
		font = "MesloLGM Nerd Font:Regular:12.0",
	},
	padding_right = 4, -- Keep this for overall item spacing
	script = "~/.config/sketchybar/items/widgets/mic.sh",
	click_script = "~/.config/sketchybar/items/widgets/mic-click.sh",
})

-- Subscribe to volume_change event
mic:subscribe("volume_change")
