local constants = require("constants")
local settings = require("config.settings")

local calendar = sbar.add("item", constants.items.CALENDAR, {
	position = "right",
	update_freq = 1,
	icon = { padding_left = 0, padding_right = 0 },
	color = settings.colors.light_blue,
})

calendar:subscribe({ "forced", "routine", "system_woke" }, function(env)
	calendar:set({
		label = {
			string = os.date("%a %d %b, %H:%M"),
			color = settings.colors.light_green,
		},
	})
end)

calendar:subscribe("mouse.clicked", function(env)
	sbar.exec("open -a 'Calendar'")
end)
