local constants = require("constants")
local popup = require("lib.popup")
local settings = require("config.settings")

local isCharging = false

local battery = sbar.add("item", constants.items.BATTERY, {
	position = "right",
	update_freq = 60,
})

local popupWidth <const> = settings.dimens.graphics.popup.width
local batteryPopup = sbar.add("item", battery.name .. ".header", {
	position = "popup." .. battery.name,
	icon = {
		align = "left",
		string = "Battery",
		width = popupWidth - 52,
		padding_left = 12,
		padding_right = 0,
		color = settings.colors.blue,
	},
	label = popup.close_label(),
	click_script = popup.close_script(battery.name),
})

battery:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("pmset -g batt", function(batteryInfo)
		local icon = "!"
		local label = "?"

		local found, _, charge = batteryInfo:find("(%d+)%%")
		if found then
			charge = tonumber(charge)
			label = charge .. "%"
		end

		local color = settings.colors.blue
		local charging, _, _ = batteryInfo:find("AC Power")

		isCharging = charging

		if charging then
			icon = settings.icons.text.battery.charging
		else
			if found and charge > 80 then
				icon = settings.icons.text.battery._100
			elseif found and charge > 60 then
				icon = settings.icons.text.battery._75
			elseif found and charge > 40 then
				icon = settings.icons.text.battery._50
			elseif found and charge > 30 then
				icon = settings.icons.text.battery._50
				color = settings.colors.yellow
			elseif found and charge > 20 then
				icon = settings.icons.text.battery._25
				color = settings.colors.orange
			else
				icon = settings.icons.text.battery._0
				color = settings.colors.red
			end
		end

		local lead = ""
		if found and charge < 10 then
			lead = "0"
		end

		battery:set({
			icon = {
				string = icon,
				color = color,
			},
			label = {
				color = settings.colors.light_green,
				string = lead .. label,
				padding_left = -8,
			},
		})
	end)
end)

battery:subscribe("mouse.clicked", function()
	popup.toggle(battery, function()
		popup.open_exclusive(battery.name)
		sbar.exec("pmset -g batt", function(batteryInfo)
			local found, _, remaining = batteryInfo:find("(%d+:%d+) remaining")
			local label = found and ("Time remaining: " .. remaining .. "h")
				or (isCharging and "Charging" or "No estimate")
			batteryPopup:set({ icon = { string = label } })
		end)
	end)
end)
