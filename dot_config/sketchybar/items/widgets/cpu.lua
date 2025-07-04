local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")

-- Function to get CPU usage percentage (matching iStats calculation)
local function get_cpu_percentage()
	local handle = io.popen([[
    top -l 2 -n 0 -s 0 | grep "CPU usage" | tail -1 | awk '{
      user = $3
      sys = $5
      gsub(/%/, "", user)
      gsub(/%/, "", sys)
      total = user + sys
      printf "%.0f", total
    }'
  ]])
	if handle then
		local result = handle:read("*a")
		handle:close()
		local percentage = tonumber(result)
		if percentage then
			return percentage
		end
	end
	return 0
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
	local percentage = get_cpu_percentage()
	cpu:set({
		label = {
			string = percentage .. "%  ",
		},
	})
end

cpu:subscribe({ "routine", "forced", "system_woke" }, update)

-- Initial update
update()
