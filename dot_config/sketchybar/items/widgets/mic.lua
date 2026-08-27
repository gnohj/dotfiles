local constants = require("constants")

local mic = sbar.add("item", constants.items.MIC or "mic", {
	position = "right",
	updates = true,
	update_freq = 10,
	padding_right = 4,
	icon = {
		padding_left = 0,
		-- 2, not the default 10: cpu/memory/volume all sit their value this close to the glyph.
		padding_right = 2,
	},
	label = {
		drawing = true,
		padding_left = 0,
		padding_right = 8,
	},
	script = "~/.config/sketchybar/items/widgets/mic.sh",
	click_script = "~/.config/sketchybar/items/widgets/mic-click.sh",
})

mic:subscribe("volume_change")
