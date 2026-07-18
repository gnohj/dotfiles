local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")
local dimens = require("config.dimens")

local tailscale = sbar.add("item", constants.items.TAILSCALE, {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	update_freq = 30,
	icon = {
		string = settings.icons.text.tailscale.off,
		color = colors.red,
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		string = "",
		color = colors.grey,
		padding_left = 4,
		padding_right = 0,
		drawing = false,
	},
	script = "~/.config/sketchybar/items/widgets/tailscale.sh",
	click_script = "open -a 'Tailscale'",
})

tailscale:subscribe({ "forced", "routine", "system_woke", "wifi_change" })
