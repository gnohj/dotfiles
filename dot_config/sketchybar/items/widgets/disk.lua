local constants = require("constants")
local colors = require("config.colors")
local tiers = require("lib.tiers")

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
	padding_left = -12,
	padding_right = 0,
	update_freq = 300,
	updates = true,
	icon = {
		string = "󰋊",
		color = colors.blue,
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
	get_disk_percentage(function(percentage)
		local color = tiers.color(percentage, tiers.disk)
		disk:set({
			icon = { color = color or colors.blue },
			label = { string = percentage .. "%  ", color = color or colors.cyan },
		})
	end)
end

disk:subscribe({ "routine", "forced", "system_woke" }, update)

update()
