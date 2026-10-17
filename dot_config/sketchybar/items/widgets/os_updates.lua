local SCRIPT <const> = "~/.config/sketchybar/items/widgets/os_updates.sh "

for _, host in ipairs({ "mac", "omarchy" }) do
	local item = sbar.add("item", "widgets.os_updates." .. host, {
		drawing = false,
		updates = "on",
		update_freq = 3600,
		script = SCRIPT .. host,
	})
	item:subscribe({ "forced", "routine", "system_woke" })
end
