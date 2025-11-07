local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")

-- Function to get CPU usage percentage (matching iStats calculation)
local function get_cpu_percentage(callback)
	sbar.exec([[top -l 2 -n 0 -s 0 | grep "CPU usage" | tail -1 | awk '{
      user = $3
      sys = $5
      gsub(/%/, "", user)
      gsub(/%/, "", sys)
      total = user + sys
      printf "%.0f", total
    }']], function(result)
		local percentage = tonumber(result)
		if percentage and callback then
			callback(percentage)
		elseif callback then
			callback(0)
		end
	end)
end

local cpu = sbar.add("item", constants.items.CPU, {
	position = "right",
	update_freq = 30,
	icon = {
		string = "",
		color = colors.light_blue,
		padding_right = 2,
	},
	label = {
		string = "??%",
		color = colors.green,
		padding_left = 0,
	},
})

local function update()
	get_cpu_percentage(function(percentage)
		cpu:set({
			label = {
				string = percentage .. "%  ",
			},
		})
	end)
end

cpu:subscribe({ "routine", "forced", "system_woke" }, update)

-- Initial update
update()
