local constants = require("constants")
local colors = require("config.colors")
local groups = require("items.widgets.groups")

local THRESHOLDS = {
	{ at = 90, color = colors.red },
	{ at = 80, color = colors.orange },
	{ at = 65, color = colors.yellow },
}

local cpu_temp = sbar.add("item", constants.items.CPU_TEMP, {
	position = "right",
	padding_left = -5,
	update_freq = 10,
	updates = true,
	icon = { string = "󰔏", color = colors.blue, padding_left = 3, padding_right = 5, font = { size = 14.0 } },
	label = { string = "--°", color = colors.cyan, padding_left = 0, padding_right = 8 },
})

local function update()
	sbar.exec("$HOME/.local/bin/cpu-temp 2>/dev/null", function(result)
		local degrees = tonumber(result)
		if not degrees then
			cpu_temp:set({ icon = { color = colors.blue }, label = { string = "--°", color = colors.cyan } })
			groups.changed()
			return
		end
		local color
		for _, step in ipairs(THRESHOLDS) do
			if degrees >= step.at then
				color = step.color
				break
			end
		end
		cpu_temp:set({ icon = { color = color or colors.blue }, label = { string = degrees .. "°", color = color or colors.cyan } })
		groups.changed()
	end)
end

cpu_temp:subscribe({ "routine", "forced", "system_woke" }, update)

update()
