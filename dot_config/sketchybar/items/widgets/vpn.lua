local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")
local dimens = require("config.dimens")

-- Private Internet Access exit-location indicator, drawn only while connected; vpn.sh toggles it and left-click opens the PIA app.
local vpn = sbar.add("item", constants.items.VPN, {
	position = "right",
	drawing = false,
	padding_left = 0,
	padding_right = dimens.padding.gap,
	update_freq = 30,
	icon = {
		string = settings.icons.text.vpn.on,
		color = colors.blue,
		padding_left = 0,
		padding_right = 2,
	},
	label = {
		string = "—",
		color = colors.blue,
		padding_left = 0,
	},
	script = "~/.config/sketchybar/items/widgets/vpn.sh",
	click_script = "open -a 'Private Internet Access'",
})

vpn:subscribe({ "forced", "routine", "system_woke", "wifi_change" })
