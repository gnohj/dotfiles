local colors = require("config.colors")
local groups = require("items.widgets.groups")

-- Names, not values: the palette can change under a running bar.
local TIER_COLORS <const> = { "yellow", "orange", "red" }
local BEAT <const> = "/usr/bin/python3 $HOME/.local/bin/resource-watch beat 2>/dev/null"

local M = {}
local widgets, shown = {}, {}

local function refresh()
	sbar.exec(BEAT, function(result)
		local changed = false
		for metric, widget in pairs(widgets) do
			local value, tier = tostring(result):match(metric .. " (%d+) (%d)")
			local text = value and (value .. widget.unit) or widget.unknown
			local key = text .. (tier or "")
			if shown[metric] ~= key then
				shown[metric] = key
				local color = colors[TIER_COLORS[tonumber(tier)]]
				widget.item:set({
					icon = { color = color or colors.accent },
					label = { string = text, color = color or (value and colors.text or colors.grey) },
				})
				changed = true
			end
		end
		if changed then
			groups.changed()
		end
	end)
end

local driver = sbar.add("item", { drawing = false, updates = true, update_freq = 10 })
driver:subscribe({ "routine", "forced", "system_woke" }, refresh)

function M.attach(metric, item, unit, unknown)
	widgets[metric] = { item = item, unit = unit, unknown = unknown }
	refresh()
end

return M
