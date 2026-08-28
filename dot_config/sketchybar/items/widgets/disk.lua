local constants = require("constants")
local syspanel = require("lib.syspanel")
local colors = require("config.colors")

-- counts the APFS reserve as used, matching duf rather than df's capacity column
local function get_disk_percentage(callback)
	sbar.exec(
		[[volume=/System/Volumes/Data; [ -d "$volume" ] || volume=/; df -k "$volume" | awk 'NR==2 {
      total = $2
      avail = $4

      if (total > 0) {
        printf "%.0f", ((total - avail)/total)*100
      } else {
        printf "0"
      }
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

local disk = sbar.add("item", constants.items.DISK, {
	position = "right",
	popup = { align = "center" },
	padding_left = -5,
	padding_right = -5,
	update_freq = 300,
	icon = {
		string = "󰋊",
		color = colors.blue,
		padding_right = 2,
	},
	label = {
		string = "??%",
		color = colors.green,
		padding_left = 0,
	},
})

local function update()
	get_disk_percentage(function(percentage)
		disk:set({
			label = {
				string = percentage .. "%  ",
			},
		})
	end)
end

disk:subscribe({ "routine", "forced", "system_woke" }, update)

update()

syspanel.attach(disk, {
	icon = "󰋊",
	title = "Disk",
	section = "VOLUMES",
	mode = "disk",
})
