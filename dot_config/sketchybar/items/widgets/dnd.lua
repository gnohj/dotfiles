local dimens = require("config.dimens")

-- No glyph or width: the status group's border shows Focus and its padded ends toggle it.
local dnd = sbar.add("item", "widgets.dnd", {
	position = "right",
	width = 0,
	padding_left = 0,
	padding_right = 0,
	updates = "on",
	icon = { drawing = false },
	label = {
		drawing = false,
	},
	update_freq = 5,
	script = "~/.config/sketchybar/items/widgets/dnd.sh",
	click_script = "~/.config/sketchybar/items/widgets/dnd-click.sh",
})

dnd:subscribe({ "forced", "routine", "system_woke", "dnd_changed" })
