local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")
local tiers = require("lib.tiers")

-- CPU usage percentage (matching btop: proper 1s sample window, not back-to-back)
local function get_cpu_percentage(callback)
	sbar.exec(
		[[top -l 2 -n 0 -s 1 | grep "CPU usage" | tail -1 | awk '{
      user = $3
      sys = $5
      gsub(/%/, "", user)
      gsub(/%/, "", sys)
      total = user + sys
      printf "%.0f", total
    }']],
		function(result)
			local percentage = tonumber(result)
			if percentage and callback then
				callback(percentage)
			elseif callback then
				callback(0)
			end
		end
	)
end

local cpu = sbar.add("item", constants.items.CPU, {
	position = "right",
	padding_left = -12,
	update_freq = 10,
	updates = true,
	icon = {
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
	end)
end

cpu:subscribe({ "routine", "forced", "system_woke" }, update)

update()
