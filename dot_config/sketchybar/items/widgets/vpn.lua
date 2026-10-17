local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")
local dimens = require("config.dimens")

-- Private Internet Access exit-location indicator, drawn while connected and the cluster is expanded (network.lua); left-click opens the PIA app.
local vpn = sbar.add("item", constants.items.VPN, {
	position = "right",
	drawing = false,
	padding_left = 0,
	padding_right = dimens.padding.gap,
	update_freq = 30,
	updates = true,
	icon = {
		string = settings.icons.text.vpn.on,
		color = colors.blue,
		padding_left = 0,
		padding_right = 2,
	},
	label = {
		string = "",
		color = colors.blue,
		padding_left = 0,
	},
	script = "~/.config/sketchybar/items/widgets/vpn.sh",
	click_script = "open -a 'Private Internet Access'",
})

vpn:subscribe({ "forced", "routine", "system_woke", "wifi_change" })
