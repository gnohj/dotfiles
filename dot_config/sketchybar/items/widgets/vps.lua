local colors = require("config.colors")

-- Remote dev-box CPU + memory; one ssh round-trip in vps.sh sets both items.
local function add(name, icon, padding_left, padding_right)
	return sbar.add("item", name, {
		position = "right",
		padding_left = padding_left,
		padding_right = padding_right,
		icon = { string = icon, color = colors.purple, padding_right = 2 },
		label = { string = "--", color = colors.grey, padding_left = 0, padding_right = 10 },
	})
end

add("widgets.vps_memory", "", -5, -5)
local cpu = add("widgets.vps_cpu", "", 0, 0)

cpu:set({ update_freq = 15, updates = "on", script = "~/.config/sketchybar/items/widgets/vps.sh" })
cpu:subscribe({ "forced", "routine", "system_woke" })
