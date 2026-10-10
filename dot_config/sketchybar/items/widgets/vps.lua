local colors = require("config.colors")

-- Remote dev-box CPU, memory, disk and temperature; one ssh round-trip in vps.sh sets all four.
local function add(name, icon, padding_left, padding_right)
	return sbar.add("item", name, {
		position = "right",
		padding_left = padding_left,
		padding_right = padding_right,
		icon = { string = icon, color = colors.white, padding_right = 2 },
		label = { string = "--", color = colors.grey, padding_left = 0, padding_right = 10 },
	})
end

return {
	temp = function()
		add("widgets.vps_temp", "󰔏", -16, -2)
	end,
	disk = function()
		add("widgets.vps_disk", "󰋊", -12, 0)
	end,
	memory = function()
		add("widgets.vps_memory", "", -12, 0)
	end,
	cpu = function()
		local cpu = add("widgets.vps_cpu", "", -12, 0)
		cpu:set({ update_freq = 15, updates = "on", script = "~/.config/sketchybar/items/widgets/vps.sh" })
		cpu:subscribe({ "forced", "routine", "system_woke" })
	end,
}
