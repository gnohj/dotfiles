local constants = require("constants")
local popup = require("lib.popup")
local settings = require("config.settings")

local popupWidth <const> = settings.dimens.graphics.popup.large_width
local scriptPath <const> = "~/.config/sketchybar/items/widgets/bluetooth.sh"
local settingsPane <const> = "open 'x-apple.systempreferences:com.apple.BluetoothSettings'"

-- sbar.exec, not the item's `script` property: an item carrying both `script` and `popup` never receives it.
local bluetooth = sbar.add("item", constants.items.BLUETOOTH, {
	position = "right",
	-- Cancels disk's item padding_right of -5, so its label's own 10 is the whole seam.
	padding_left = 5,
	padding_right = settings.dimens.padding.gap,
	update_freq = 30,
	label = { drawing = false },
	icon = {
		string = settings.icons.text.bluetooth.on,
		color = settings.colors.grey,
		padding_left = 0,
		padding_right = 0,
	},
	popup = { align = "center" },
})

local header = sbar.add("item", constants.items.BLUETOOTH .. ".header", {
	position = "popup." .. bluetooth.name,
	icon = {
		align = "left",
		string = settings.icons.text.bluetooth.on .. "  Bluetooth",
		width = popupWidth - 52,
		padding_left = 12,
		padding_right = 0,
		color = settings.colors.blue,
		font = { style = settings.fonts.styles.bold },
	},
	label = popup.close_label(),
	click_script = popup.close_script(bluetooth.name),
})

local minorTypeIcons <const> = {
	Headphones = settings.icons.text.bluetooth.headphones,
	Headset = settings.icons.text.bluetooth.headset,
	Mouse = settings.icons.text.bluetooth.mouse,
	Keyboard = settings.icons.text.bluetooth.keyboard,
	Speaker = settings.icons.text.bluetooth.speaker,
	Gamepad = settings.icons.text.bluetooth.gamepad,
}

local sectionTitles <const> = {
	connected = "CONNECTED",
	paired = "PAIRED",
	available = "AVAILABLE",
}

-- Per-generation row names: SbarLua flushes a remove and the re-add together, so a name match would swallow the new rows.
-- Most reopens are byte-identical, so skip the rebuild and its layout churn entirely.
local lastResult = nil
local opening = false
local removePattern = nil
local generation = 0
local rowCount = 0
local pending = {}

local function addRow(options)
	options.name = constants.items.BLUETOOTH .. ".r" .. generation .. "." .. rowCount
	pending[#pending + 1] = options
	rowCount = rowCount + 1
end

-- The remove rides in the same invocation as the adds, so nothing is torn down mid-layout.
local function clearRows()
	lastResult = nil
	removePattern = rowCount > 0 and ("/" .. constants.items.BLUETOOTH .. ".r" .. generation .. "\\.*/") or nil
	rowCount = 0
	pending = {}
	generation = generation + 1
end

local function addSection(title)
	addRow({
		position = "popup." .. bluetooth.name,
		icon = {
			align = "left",
			string = title,
			width = popupWidth,
			color = settings.colors.grey,
			font = { size = settings.dimens.text.label - 2, style = settings.fonts.styles.bold },
		},
		label = { drawing = false },
	})
end

-- click_script, not mouse.clicked: subscriptions on popup children never fire, so actions refresh via the top-level item's event.
local refreshEvent <const> = "bluetooth_refresh"
sbar.add("event", refreshEvent)

local function addDevice(section, device)
	local connected = section == "connected"
	local action = connected and "disconnect" or "connect"
	addRow({
		position = "popup." .. bluetooth.name,
		icon = {
			align = "left",
			string = (minorTypeIcons[device.minorType] or settings.icons.text.bluetooth.default)
				.. "  "
				.. popup.ellipsize(device.name, 22),
			width = popupWidth * 0.72,
			color = connected and settings.colors.white or settings.colors.dirty_white,
		},
		label = {
			align = "right",
			string = device.battery,
			width = popupWidth * 0.28,
			color = connected and settings.colors.green or settings.colors.grey,
		},
		click_script = scriptPath .. " " .. action .. ' "' .. device.address .. '"',
	})
end

local function addAction(icon, text, clickScript)
	addRow({
		position = "popup." .. bluetooth.name,
		icon = {
			align = "left",
			string = icon .. "  " .. text,
			width = popupWidth,
			color = settings.colors.grey,
		},
		label = { drawing = false },
		click_script = clickScript or "",
	})
end

local function parse(result)
	local state = {
		power = "off",
		hasBlueutil = false,
		connected = {},
		paired = {},
		available = {},
	}

	for line in result:gmatch("[^\r\n]+") do
		local fields = {}
		-- Walk the tabs explicitly: a plain gmatch drops the trailing empty fields a device with no battery leaves.
		local from = 1
		while true do
			local tab = line:find("\t", from, true)
			if not tab then
				fields[#fields + 1] = line:sub(from)
				break
			end
			fields[#fields + 1] = line:sub(from, tab - 1)
			from = tab + 1
		end

		local kind = fields[1]
		if kind == "power" then
			state.power = fields[2]
		elseif kind == "blueutil" then
			state.hasBlueutil = fields[2] == "yes"
		elseif state[kind] then
			table.insert(state[kind], {
				name = fields[2] or "",
				address = fields[3] or "",
				minorType = fields[4] or "",
				battery = fields[5] or "",
			})
		end
	end

	return state
end

local function applyIcon(state)
	local icon, color
	if state.power ~= "on" then
		icon, color = settings.icons.text.bluetooth.off, settings.colors.red
	elseif #state.connected > 0 then
		icon, color = settings.icons.text.bluetooth.connected, settings.colors.blue
	else
		icon, color = settings.icons.text.bluetooth.on, settings.colors.grey
	end
	bluetooth:set({ icon = { string = icon, color = color } })
end

local function applyPopup(state)
	clearRows()

	local on = state.power == "on"
	header:set({
		icon = {
			string = (on and settings.icons.text.bluetooth.on or settings.icons.text.bluetooth.off) .. "  Bluetooth",
			color = on and settings.colors.blue or settings.colors.grey,
		},
	})
	addRow({
		position = "popup." .. bluetooth.name,
		icon = {
			align = "left",
			string = "Bluetooth power",
			width = popupWidth * 0.8,
			color = on and settings.colors.dirty_white or settings.colors.grey,
		},
		label = {
			align = "right",
			string = on and settings.icons.text.switch.on or settings.icons.text.switch.off,
			width = popupWidth * 0.2,
			color = on and settings.colors.green or settings.colors.grey,
			font = { size = 18 },
		},
		click_script = scriptPath .. " toggle",
	})

	for _, kind in ipairs({ "connected", "paired", "available" }) do
		if #state[kind] > 0 then
			addSection(sectionTitles[kind])
			for _, device in ipairs(state[kind]) do
				addDevice(kind, device)
			end
		end
	end

	if state.hasBlueutil then
		-- Named for what it can actually find: an inquiry is Classic-BT only, so BLE peripherals stay invisible.
		addAction(settings.icons.text.bluetooth.on, "Scan (classic only)", scriptPath .. " scan")
	else
		addAction(settings.icons.text.gear, "Rebuild nix to enable toggle/scan")
	end

	popup.build(bluetooth.name, removePattern, pending, opening)
	opening = false
end

local function refreshIcon()
	sbar.exec(scriptPath .. " list", function(result)
		applyIcon(parse(result))
	end)
end

-- No in-flight guard: callbacks are serial, and a flag would deadlock the panel the first time one failed to fire.
local function refreshPopup()
	sbar.exec(scriptPath .. " list", function(result)
		if result == lastResult and rowCount > 0 then
			if opening then
				bluetooth:set({ popup = { drawing = true } })
				opening = false
			end
			return
		end
		local state = parse(result)
		applyIcon(state)
		applyPopup(state)
		-- After, not before: applyPopup clears the rows, and clearRows invalidates this.
		lastResult = result
	end)
end

local function toggleDetails(env)
	if env.BUTTON == "right" then
		sbar.exec(settingsPane)
		return
	end

	popup.toggle(bluetooth, function()
		opening = true
		popup.close_others(bluetooth.name)
		refreshPopup()
	end)
end

bluetooth:subscribe({ "forced", "routine", "system_woke" }, refreshIcon)
bluetooth:subscribe(refreshEvent, refreshPopup)
bluetooth:subscribe("mouse.clicked", toggleDetails)
