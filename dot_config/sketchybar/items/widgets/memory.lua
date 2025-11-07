---@diagnostic disable-next-line: undefined-global
local constants = require("constants")
local settings = require("config.settings")
local colors = require("config.colors")

-- Function to get memory usage percentage (matching iStats calculation)
local function get_memory_percentage(callback)
	sbar.exec([[vm_stat | awk '
    /page size/ {pagesize=$8}
    /Pages free/ {free=$3}
    /Pages active/ {active=$3}
    /Pages inactive/ {inactive=$3}
    /Pages speculative/ {spec=$3}
    /Pages wired/ {wired=$4}
    /Pages occupied by compressor/ {compressed=$5}
    END {
      # Remove trailing colons and convert to numbers
      gsub(/:/, "", free); gsub(/:/, "", active); gsub(/:/, "", inactive)
      gsub(/:/, "", spec); gsub(/:/, "", wired); gsub(/:/, "", compressed)

      free = free + spec
      used = (active + inactive + wired + compressed)
      total = free + used

      # Calculate percentage - this should match iStats better
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
	update_freq = 30,
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

-- Initial update
update()
