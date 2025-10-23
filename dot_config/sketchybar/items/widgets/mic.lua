local constants = require("constants")

local mic = sbar.add("item", constants.items.MIC or "mic", {
	position = "right",
	updates = true,
	update_freq = 10,
	padding_right = 4, -- Space before notification widgets
	-- padding_left = -10,
	label = {
		drawing = true,
		padding_left = -8, -- Minimal space between icon and text
		padding_right = 12, -- Space after text
		font = "MesloLGM Nerd Font:Regular:12.0",
	},
	script = "~/.config/sketchybar/items/widgets/mic.sh",
	click_script = "~/.config/sketchybar/items/widgets/mic-click.sh",
})

-- Subscribe to volume_change event
mic:subscribe("volume_change")
