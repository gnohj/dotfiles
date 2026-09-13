local constants = require("constants")
local colors = require("config.colors")

local THRESHOLDS = {
	{ at = 90, color = colors.red },
	{ at = 80, color = colors.orange },
	{ at = 65, color = colors.yellow },
	{ at = 0, color = colors.green },
}

local cpu_temp = sbar.add("item", constants.items.CPU_TEMP, {
	position = "right",
	update_freq = 10,
	icon = { string = "󰔏", padding_left = 3, padding_right = 5 },
	label = { string = "--°", color = colors.green, padding_left = 0, padding_right = 5 },
})

local function update()
	sbar.exec("$HOME/.local/bin/cpu-temp 2>/dev/null", function(result)
		local degrees = tonumber(result)
		if not degrees then
			cpu_temp:set({ label = { string = "--°", color = colors.green } })
			return
		end
		local color = colors.green
		for _, step in ipairs(THRESHOLDS) do
			if degrees >= step.at then
				color = step.color
				break
			end
		end
		cpu_temp:set({ label = { string = degrees .. "°", color = color } })
	end)
end

cpu_temp:subscribe({ "routine", "forced", "system_woke" }, update)

update()
