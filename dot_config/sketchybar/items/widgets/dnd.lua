local colors = require("config.colors")
local dimens = require("config.dimens")

-- Do Not Disturb (Focus) toggle.
-- Always visible. Color reflects state: yellow when off, purple when on.
-- Left-click toggles DnD via Shortcuts (FocusOn / FocusOff).
-- Flex-gap convention: icon-only, leading 0, trailing = dimens.padding.gap.
local dnd = sbar.add("item", "widgets.dnd", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	icon = {
		string = "􀆺", -- SF Symbol moon.fill (matches Apple's Focus icon)
		color = colors.yellow,
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		drawing = false,
	},
	update_freq = 5,
	script = "~/.config/sketchybar/items/widgets/dnd.sh",
	click_script = "~/.config/sketchybar/items/widgets/dnd-click.sh",
})

dnd:subscribe({ "forced", "routine", "system_woke", "dnd_changed" })
