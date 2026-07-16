local colors = require("config.colors")
local dimens = require("config.dimens")

-- Dev-context indicator + toggle: follows ~/.local/state/dev-context (local = grey laptop, vps = mint server), click flips it.
local dev_context = sbar.add("item", "widgets.dev_context", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	icon = {
		string = "󰌢", -- nf-md-laptop (local default)
		color = colors.grey,
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		drawing = false,
	},
	update_freq = 10,
	script = "~/.config/sketchybar/items/widgets/dev-context.sh",
	click_script = "~/.config/sketchybar/items/widgets/dev-context-click.sh",
})

dev_context:subscribe({ "forced", "routine", "system_woke", "dev_context_change" })
