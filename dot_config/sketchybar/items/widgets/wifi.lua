local constants = require("constants")
local popup = require("lib.popup")
local settings = require("config.settings")

local popupWidth <const> = 320
-- Rows sized to the popup's inner width: at the full popupWidth the values sit flush against the border.
local rowWidth <const> = popupWidth - 2 * settings.dimens.padding.icon
local scriptPath <const> = "~/.config/sketchybar/items/widgets/wifi-panel.sh"
local settingsPane <const> = "open 'x-apple.systempreferences:com.apple.wifi-settings-extension'"

local wifi = sbar.add("item", constants.items.WIFI, {
	position = "right",
	-- 0, not 2: bluetooth now sits to the left and already contributes the full gap on its right.
	padding_left = 0,
	padding_right = settings.dimens.padding.gap,
	update_freq = 30,
	label = { drawing = false },
	icon = {
		string = settings.icons.text.wifi.disconnected,
		color = settings.colors.magenta,
		padding_left = 0,
		padding_right = 0,
	},
	popup = { align = "center" },
})

local header = sbar.add("item", constants.items.WIFI .. ".header", {
	position = "popup." .. wifi.name,
	icon = {
		align = "left",
		string = settings.icons.text.wifi.connected .. "  Wi-Fi",
		width = rowWidth - 52,
		padding_left = 12,
		padding_right = 0,
		color = settings.colors.blue,
		font = { style = settings.fonts.styles.bold },
	},
	label = popup.close_label(),
	click_script = popup.close_script(wifi.name),
})

-- Per-generation row names, as in the bluetooth panel: a remove and the re-add flush together.
local refreshEvent <const> = "wifi_refresh"
sbar.add("event", refreshEvent)

-- Most reopens are byte-identical, so skip the rebuild and its layout churn entirely.
local lastResult = nil
local opening = false
local removePattern = nil
local generation = 0
local rowCount = 0

local pending = {}

local function addRow(options)
	options.name = constants.items.WIFI .. ".r" .. generation .. "." .. rowCount
	pending[#pending + 1] = options
	rowCount = rowCount + 1
end

-- The remove rides in the same invocation as the adds, so nothing is torn down mid-layout.
local function clearRows()
	lastResult = nil
	removePattern = rowCount > 0 and ("/" .. constants.items.WIFI .. ".r" .. generation .. "\\.*/") or nil
	rowCount = 0
	pending = {}
	generation = generation + 1
end

local function addSection(title)
	addRow({
		position = "popup." .. wifi.name,
		icon = {
			align = "left",
			string = title,
			width = rowWidth,
			color = settings.colors.grey,
			font = { size = settings.dimens.text.label - 2, style = settings.fonts.styles.bold },
		},
		label = { drawing = false },
	})
end

local function addStat(name, value)
	addRow({
		position = "popup." .. wifi.name,
		icon = {
			align = "left",
			string = name,
			width = rowWidth * 0.5,
			color = settings.colors.dirty_white,
		},
		label = {
			align = "right",
			string = value ~= "" and value or "--",
			width = rowWidth * 0.5,
			color = value ~= "" and settings.colors.white or settings.colors.grey,
		},
	})
end

local dnsPresets <const> = { DHCP = "dhcp", Cloudflare = "cloudflare", Google = "google" }

-- Radio glyphs, not the toggle: these are one-of-N, and a switch icon reads as an independent on/off.
local radioOn <const> = "󰐾"
local radioOff <const> = "󰄰"

local function addDns(name, active)
	addRow({
		position = "popup." .. wifi.name,
		icon = {
			align = "left",
			string = (active and radioOn or radioOff) .. "  " .. name,
			width = rowWidth * 0.7,
			color = active and settings.colors.green or settings.colors.dirty_white,
		},
		label = { drawing = false },
		click_script = dnsPresets[name] and (scriptPath .. " dns " .. dnsPresets[name]) or "",
	})
end

local function addNetwork(ssid, connected, joinArg)
	addRow({
		position = "popup." .. wifi.name,
		icon = {
			align = "left",
			string = (connected and settings.icons.text.wifi.connected or settings.icons.text.wifi.router)
				.. "  "
				.. popup.ellipsize(ssid, 22),
			width = rowWidth * 0.72,
			color = connected and settings.colors.green or settings.colors.dirty_white,
		},
		label = {
			align = "right",
			string = connected and "Connected" or "",
			width = rowWidth * 0.28,
			color = settings.colors.green,
		},
		-- Rejoining the network you are already on would only drop the link, so it is not a target.
		click_script = connected and "" or (scriptPath .. " join " .. joinArg),
	})
end

local function parse(result)
	local state = { power = "off", ssid = "", stats = {}, dns = {}, networks = {} }

	for line in result:gmatch("[^\r\n]+") do
		local kind, name, value = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
		if kind == "power" then
			state.power = name
			state.ssid = value
		elseif kind == "stat" then
			table.insert(state.stats, { name = name, value = value })
		elseif kind == "dns" then
			table.insert(state.dns, { name = name, active = value == "active" })
		elseif kind == "network" then
			-- The shell ships an already-quoted join argument; pasting the raw SSID would be injectable.
			local flag, joinArg = value:match("^([^\t]*)\t(.*)$")
			table.insert(state.networks, {
				ssid = name,
				connected = flag == "connected",
				joinArg = joinArg or "",
			})
		end
	end

	return state
end

local function applyPopup(state)
	clearRows()

	local on = state.power == "on"
	header:set({
		icon = {
			string = settings.icons.text.wifi.connected .. "  " .. (state.ssid ~= "" and state.ssid or "Wi-Fi"),
			color = on and settings.colors.blue or settings.colors.grey,
		},
	})
	addRow({
		position = "popup." .. wifi.name,
		icon = {
			align = "left",
			string = "Wi-Fi power",
			width = rowWidth * 0.8,
			color = on and settings.colors.dirty_white or settings.colors.grey,
		},
		label = {
			align = "right",
			string = on and settings.icons.text.switch.on or settings.icons.text.switch.off,
			width = rowWidth * 0.2,
			color = on and settings.colors.green or settings.colors.grey,
			font = { size = 18 },
		},
		click_script = scriptPath .. " toggle",
	})

	for _, stat in ipairs(state.stats) do
		addStat(stat.name, stat.value)
	end

	if #state.dns > 0 then
		addSection("DNS PROVIDER")
		for _, entry in ipairs(state.dns) do
			addDns(entry.name, entry.active)
		end
	end

	if #state.networks > 0 then
		addSection("KNOWN NETWORKS")
		for _, network in ipairs(state.networks) do
			addNetwork(network.ssid, network.connected, network.joinArg)
		end
	end

	popup.build(wifi.name, removePattern, pending, opening)
	opening = false
end

local function refreshPopup()
	sbar.exec(scriptPath .. " list", function(result)
		if result == lastResult and rowCount > 0 then
			if opening then
				wifi:set({ popup = { drawing = true } })
				opening = false
			end
			return
		end
		applyPopup(parse(result))
		-- After, not before: applyPopup clears the rows, and clearRows invalidates this.
		lastResult = result
	end)
end

-- Bar icon stays on a fast path; ping and system_profiler take seconds, so the panel reads a cached sample.
local function refreshIcon()
	wifi:set({
		icon = {
			string = settings.icons.text.wifi.disconnected,
			color = settings.colors.magenta,
		},
	})

	sbar.exec("ipconfig getifaddr en0", function(ip)
		local wifiIcon, wifiColor

		if ip ~= "" then
			wifiIcon = settings.icons.text.wifi.connected
			wifiColor = settings.colors.blue

			-- iOS reserves 172.20.10.0/28 for Personal Hotspot, so the prefix alone identifies tethering.
			if ip:match("^172%.20%.10%.") then
				wifiIcon = settings.icons.text.wifi.hotspot
				wifiColor = settings.colors.yellow
			end
		end

		wifi:set({ icon = { string = wifiIcon, color = wifiColor } })

		sbar.exec([[sleep 2; scutil --nwi | grep -m1 'utun' | awk '{ print $1 }']], function(vpn)
			if vpn ~= "" then
				wifiIcon = settings.icons.text.wifi.vpn
				wifiColor = settings.colors.blue
			end
			wifi:set({ icon = { string = wifiIcon, color = wifiColor } })
		end)
	end)

	sbar.exec(scriptPath .. " sample")
end

local function toggleDetails(env)
	if env.BUTTON == "right" then
		sbar.exec(settingsPane)
		return
	end

	popup.toggle(wifi, function()
		opening = true
		popup.close_others(wifi.name)
		refreshPopup()
	end)
end

wifi:subscribe({ "wifi_change", "system_woke", "forced", "routine" }, refreshIcon)
wifi:subscribe(refreshEvent, refreshPopup)
wifi:subscribe("mouse.clicked", toggleDetails)
