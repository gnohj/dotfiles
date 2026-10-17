local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")
local groups = require("items.widgets.groups")
local tiers = require("lib.tiers")

-- user + sys over 1s via iostat; top cost ~1.5s of CPU per sample
local sampling = false

local function get_cpu_percentage(callback)
	if sampling then
		return
	end
	sampling = true
	sbar.exec([[iostat -n0 -c2 -w1 | tail -1 | awk '{ printf "%.0f", $1 + $2 }']], function(result)
		sampling = false
		callback(tonumber(result) or 0)
	end)
end

local cpu = sbar.add("item", constants.items.CPU, {
	position = "right",
	padding_left = -12,
	update_freq = 10,
	updates = true,
	icon = {
		font = { size = 14.0 },
		string = "",
		color = colors.blue,
		padding_left = 8,
		padding_right = 2,
	},
	label = {
		string = "??%",
		color = colors.cyan,
		padding_left = 0,
		-- Real padding, not the trailing spaces this used to append: a glyph is not a spacing unit.
		padding_right = 10,
	},
})

local function update()
	get_cpu_percentage(function(percentage)
		local color = tiers.color(percentage, tiers.cpu)
		cpu:set({
			icon = { color = color or colors.blue },
			label = { string = percentage .. "%  ", color = color or colors.cyan },
		})
		groups.changed()
	end)
end

cpu:subscribe({ "routine", "forced", "system_woke" }, update)

update()
