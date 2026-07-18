local colors = require("config.colors")
local dimens = require("config.dimens")

-- Dev-context picker: paint script sets the icon from ~/.local/state/dev-context; click script opens a popup of Local + SSH aliases + online Tailscale peers, and `dev-context set <token>` fires dev_context_change to repaint.
local dev_context = sbar.add("item", "widgets.dev_context", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	update_freq = 10,
	icon = {
		string = "󰌢", -- nf-md-laptop (local default)
		color = colors.red, -- local = red; paint script flips to purple when connected
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		drawing = false,
		padding_left = 4,
		padding_right = 0,
	},
	popup = { align = "center" },
	script = "~/.config/sketchybar/items/widgets/dev-context.sh",
	click_script = "~/.config/sketchybar/items/widgets/dev-context-click.sh",
})

dev_context:subscribe({ "forced", "routine", "system_woke", "dev_context_change" })
