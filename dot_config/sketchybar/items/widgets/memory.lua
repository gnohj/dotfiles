---@diagnostic disable-next-line: undefined-global
local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")

-- Memory usage percentage (matching btop: used = active + wired, over hw.memsize)
local function get_memory_percentage(callback)
	sbar.exec([[total=$(sysctl -n hw.memsize); vm_stat | awk -v total="$total" '
    /page size/ {pagesize=$8}
    /Pages active/ {active=$3}
    /Pages wired/ {wired=$4}
    END {
      gsub(/:/, "", active); gsub(/:/, "", wired)

      used = (active + wired) * pagesize

      if (total > 0) {
        printf "%.0f", (used/total)*100
      } else {
        printf "0"
      }
    }']], function(result)
		local percentage = tonumber(result)
		if percentage and callback then
			callback(percentage)
		elseif callback then
			callback(0)
		end
	end)
end

local memory = sbar.add("item", constants.items.MEMORY, {
	position = "right",
	padding_left = -5,
	update_freq = 10,
	icon = {
		string = "",
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
	get_memory_percentage(function(percentage)
		memory:set({
			label = {
				string = percentage .. "%  ",
			},
		})
	end)
end

memory:subscribe({ "routine", "forced", "system_woke" }, update)

update()
