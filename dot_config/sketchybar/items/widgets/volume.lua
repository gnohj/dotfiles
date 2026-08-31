local constants = require("constants")
local popup = require("lib.popup")
local settings = require("config.settings")

local currentAudioDevice = "None"

local volumeValue = sbar.add("item", constants.items.VOLUME .. ".value", {
	position = "right",
	padding_left = -10,
	padding_right = -4,
	label = {
		string = "??%",
		-- net 2px to the glyph, matching cpu/memory/mic; the icons above carry no padding of their own.
		padding_left = -8,
		color = settings.colors.green,
	},
})

local volumeBracket = sbar.add("bracket", constants.items.VOLUME .. ".bracket", { volumeValue.name }, {
	popup = {
		align = "center",
	},
})

local popupWidth <const> = settings.dimens.graphics.popup.width
local muteToggle <const> = "osascript -e 'set volume output muted not (output muted of (get volume settings))'"

sbar.add("event", "sound_refresh")

-- Slider tracks the level the same way the mic bar label does: red when there is nothing to hear.
local function levelColor(level, muted)
	if muted or level == 0 then
		return settings.colors.red
	elseif level <= 25 then
		return settings.colors.yellow
	end
	return settings.colors.green
end

local volumeHeader = sbar.add("item", constants.items.VOLUME .. ".header", {
	position = "popup." .. volumeBracket.name,
	icon = {
		align = "left",
		string = settings.icons.text.volume._100 .. "  Output",
		width = popupWidth - 52,
		padding_left = 12,
		padding_right = 0,
		color = settings.colors.blue,
		font = { style = settings.fonts.styles.bold },
	},
	label = popup.close_label(),
	click_script = popup.close_script(volumeBracket.name),
})

local volumeToggle = sbar.add("item", constants.items.VOLUME .. ".toggle", {
	position = "popup." .. volumeBracket.name,
	icon = {
		align = "left",
		string = "Output enabled",
		width = popupWidth * 0.8,
		color = settings.colors.dirty_white,
	},
	label = {
		align = "right",
		string = settings.icons.text.switch.on,
		width = popupWidth * 0.2,
		color = settings.colors.green,
		font = { size = 18 },
	},
	click_script = muteToggle .. " && sketchybar --trigger sound_refresh",
})

local function updateHeader()
	sbar.exec("osascript -e 'output muted of (get volume settings)'", function(muted)
		local on = not muted:match("true")
		sbar.exec("osascript -e 'output volume of (get volume settings)'", function(level)
			volumeSlider:set({ slider = { highlight_color = levelColor(tonumber(level) or 0, not on) } })
		end)
		volumeHeader:set({
			icon = {
				string = (on and settings.icons.text.volume._100 or settings.icons.text.volume._0) .. "  Output",
				color = on and settings.colors.blue or settings.colors.grey,
			},
		})
		volumeToggle:set({
			icon = { color = on and settings.colors.dirty_white or settings.colors.grey },
			label = {
				string = on and settings.icons.text.switch.on or settings.icons.text.switch.off,
				color = on and settings.colors.green or settings.colors.grey,
			},
		})
	end)
end

volumeValue:subscribe("sound_refresh", updateHeader)

local volumeSlider = sbar.add("slider", constants.items.VOLUME .. ".slider", settings.dimens.graphics.popup.width, {
	position = "popup." .. volumeBracket.name,
	click_script = 'osascript -e "set volume output volume $PERCENTAGE"',
})

volumeValue:subscribe("volume_change", function(env)
	local icon = settings.icons.text.volume._0
	local volume = tonumber(env.INFO)

	sbar.exec("SwitchAudioSource -t output -c", function(result)
		local currentOutputDevice = result:sub(1, -2)
		print("Current Output Device: " .. currentOutputDevice)
		if volume > 0 and currentOutputDevice == "EarFun Air Pro 3" then
			icon = "􀟥"
		elseif volume > 0 and currentOutputDevice == "Gnohj AirPods Pro" then
			icon = "􀪷"
		elseif volume > 0 and currentOutputDevice == "Thunder Flash" or currentOutputDevice == "AirPods von Anna" then
			icon = "􀺹"
		-- elseif currentOutputDevice == "External Headphones" then
		-- 	icon = "􀝎 "
		elseif volume > 60 then
			icon = settings.icons.text.volume._100
		elseif volume > 30 then
			icon = settings.icons.text.volume._66
		elseif volume > 10 then
			icon = settings.icons.text.volume._33
		elseif volume > 0 then
			icon = settings.icons.text.volume._10
		end
		-- end

		local lead = ""
		if volume < 10 then
			lead = "0"
		end

		-- volumeIcon:set({ label = icon })
		volumeSlider:set({
			slider = { percentage = volume, highlight_color = levelColor(volume, false) },
		})

		local hasVolume = volume ~= 0
		volumeValue:set({
			icon = {
				string = icon,
				color = settings.colors.blue,
			},
			label = {
				string = hasVolume and lead .. volume .. "%" or "",
				padding_right = hasVolume and 8 or 0,
			},
		})
	end)
end)

local function hideVolumeDetails()
	volumeBracket:set({ popup = { drawing = false } })
	sbar.remove("/" .. constants.items.VOLUME .. ".device\\.*/")
end

local function toggleVolumeDetails(env)
	if env.BUTTON == "right" then
		-- The .prefpane path this used to open is pre-Ventura and now lands on the Settings home screen.
		sbar.exec("open 'x-apple.systempreferences:com.apple.Sound-Settings.extension'")
		return
	end

	popup.toggle(volumeBracket, function()
		popup.open_exclusive(volumeBracket.name)
		updateHeader()
		sbar.exec("SwitchAudioSource -t output -c", function(result)
			currentAudioDevice = result:sub(1, -2)
			sbar.exec("SwitchAudioSource -a -t output", function(available)
				local current = currentAudioDevice
				local counter = 0
				for device in string.gmatch(available, "[^\r\n]+") do
					local color = settings.colors.grey
					if current == device then
						color = settings.colors.magenta
					end
					sbar.add("item", constants.items.VOLUME .. ".device." .. counter, {
						position = "popup." .. volumeBracket.name,
						align = "center",
						label = { string = device, color = color },
						click_script = 'SwitchAudioSource -s "'
							.. device
							.. '" && sketchybar --set /'
							.. constants.items.VOLUME
							.. ".device\\.*/ label.color="
							.. settings.colors.grey
							.. " --set $NAME label.color="
							.. settings.colors.magenta,
					})
					counter = counter + 1
				end
			end)
		end)
	end, hideVolumeDetails)
end

local function changeVolume(env)
	local delta = env.SCROLL_DELTA
	sbar.exec('osascript -e "set volume output volume (output volume of (get volume settings) + ' .. delta .. ')"')
end

volumeValue:subscribe("mouse.clicked", toggleVolumeDetails)
volumeValue:subscribe("mouse.scrolled", changeVolume)
-- volumeValue:subscribe("mouse.exited.global", hideVolumeDetails)
