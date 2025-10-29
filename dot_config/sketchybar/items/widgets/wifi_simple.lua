local constants = require("constants")
local settings = require("config.settings")

-- Simple WiFi status widget (no speed monitoring, event-driven only)
local wifi = sbar.add("item", constants.items.WIFI, {
	position = "right",
	icon = {
		string = settings.icons.text.wifi.disconnected,
		color = settings.colors.magenta,
		padding_left = 8,
		padding_right = 8,
	},
	label = {
		drawing = false,  -- No label, just icon
	},
})

local function updateWifiStatus()
	-- Quick check for IP address (non-blocking)
	sbar.exec("ipconfig getifaddr en0", function(ip)
		local isConnected = ip ~= ""

		local wifiIcon = settings.icons.text.wifi.disconnected
		local wifiColor = settings.colors.magenta

		if isConnected then
			wifiIcon = settings.icons.text.wifi.connected
			wifiColor = settings.colors.light_blue

			-- Check for VPN (non-blocking, runs after WiFi check)
			sbar.exec("scutil --nwi | grep -m1 'utun' | awk '{ print $1 }'", function(vpn)
				local isVPNConnected = vpn ~= ""

				if isVPNConnected then
					wifi:set({
						icon = {
							string = settings.icons.text.wifi.vpn,
							color = settings.colors.green,
						},
					})
				else
					wifi:set({
						icon = {
							string = wifiIcon,
							color = wifiColor,
						},
					})
				end
			end)
		else
			-- Not connected, no need to check VPN
			wifi:set({
				icon = {
					string = wifiIcon,
					color = wifiColor,
				},
			})
		end
	end)
end

-- Subscribe to WiFi change events (event-driven, no polling)
wifi:subscribe("wifi_change", function()
	updateWifiStatus()
end)

-- Subscribe to system wake event
wifi:subscribe("system_woke", function()
	updateWifiStatus()
end)

-- Subscribe to forced refresh
wifi:subscribe("forced", function()
	updateWifiStatus()
end)

-- Click to open WiFi settings
wifi:subscribe("mouse.clicked", function()
	-- Open WiFi in System Settings
	sbar.exec("open x-apple.systempreferences:com.apple.preference.network?Wi-Fi")
end)

-- Initial update on load
updateWifiStatus()
