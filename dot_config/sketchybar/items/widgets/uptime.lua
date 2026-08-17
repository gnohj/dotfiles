local constants = require("constants")
local colors = require("config.colors")

local function get_uptime_days(callback)
	sbar.exec(
		[[sysctl -n kern.boottime | awk -v now="$(date +%s)" '{
      days = 0

      if (match($0, /sec = [0-9]+/)) {
        boot = substr($0, RSTART + 6, RLENGTH - 6)
        days = int((now - boot) / 86400)
      }

      if (days < 0) {
        days = 0
      }

      printf "%02d", days
    }']],
		function(result)
			local days = result:match("%d+")
			if callback then
				callback(days or "00")
			end
		end
	)
end

local uptime = sbar.add("item", constants.items.UPTIME, {
	position = "right",
	padding_left = -5,
	padding_right = -5,
	update_freq = 1800,
	icon = {
		string = "󰜷",
		color = colors.blue,
		padding_left = 13,
		padding_right = 2,
	},
	label = {
		string = "??d",
		color = colors.green,
		padding_left = 0,
	},
})

local function update()
	get_uptime_days(function(days)
		uptime:set({
			label = {
				string = days .. "d ",
			},
		})
	end)
end

uptime:subscribe({ "routine", "forced", "system_woke" }, update)

update()
