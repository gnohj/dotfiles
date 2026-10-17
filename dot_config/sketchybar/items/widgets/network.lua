local colors = require("config.colors")
local constants = require("constants")
local dimens = require("config.dimens")

local TOGGLE <const> = "widgets.network_toggle"
local REFRESH <const> = "network_refresh"
local VALUE_GAP <const> = 4

local members <const> = {
	constants.items.BLUETOOTH,
	constants.items.WIFI,
	constants.items.VPN,
	constants.items.TAILSCALE,
}

-- Collapsed, the first alarming item here stands in for the cluster, Wi-Fi otherwise.
local priority <const> = { constants.items.WIFI, constants.items.TAILSCALE, constants.items.BLUETOOTH }

local function hex(color)
	return string.format("0x%08x", color)
end

local alarms <const> = {
	[hex(colors.red)] = true,
	[hex(colors.orange)] = true,
	[hex(colors.yellow)] = true,
	[hex(colors.shell_yellow)] = true,
}

local expanded = false

local function alarming(name)
	local item = sbar.query(name)
	return type(item) == "table" and item.icon ~= nil and alarms[item.icon.color] == true
end

local function representative()
	for _, name in ipairs(priority) do
		if alarming(name) then
			return name
		end
	end
	return constants.items.WIFI
end

local function visible(name, shown)
	if name == constants.items.VPN then
		local vpn = sbar.query(name)
		return expanded and type(vpn) == "table" and vpn.label.value ~= ""
	end
	return expanded or name == shown
end

local function trail(item)
	local label = item.label.drawing == "on" and item.label.padding_right or 0
	return label + item.geometry.padding_right
end

local function apply()
	local shown = representative()
	local rightmost
	for _, name in ipairs(members) do
		local on = visible(name, shown)
		sbar.set(name, { drawing = on and "on" or "off" })
		if on then
			rightmost = name
		end
	end
	local last = rightmost and sbar.query(rightmost)
	if type(last) ~= "table" or not last.label then
		return
	end
	sbar.set(TOGGLE, {
		padding_left = VALUE_GAP - trail(last),
		label = { string = expanded and "󰄽" or "󰄾", color = sbar.query(shown).icon.color },
	})
end

local M = {}

function M.toggle()
	sbar.add("event", REFRESH)
	local toggle = sbar.add("item", TOGGLE, {
		position = "right",
		padding_left = 0,
		padding_right = 0,
		icon = { drawing = false },
		label = { string = "󰄾", color = colors.grey, padding_left = 0, padding_right = dimens.padding.gap },
	})
	toggle:subscribe("mouse.clicked", function()
		expanded = not expanded
		apply()
	end)
end

function M.watch()
	local watcher = sbar.add("item", { drawing = false, updates = true, update_freq = 5 })
	watcher:subscribe({ "routine", "forced", "system_woke", "wifi_change", REFRESH }, apply)
	apply()
end

return M
