local constants = require("constants")
local settings = require("config.settings")

local calendar = sbar.add("item", constants.items.CALENDAR, {
	position = "right",
	update_freq = 1,
	icon = { padding_left = 0, padding_right = 0, font = { size = 14.0 } },
	-- Battery's box already carries a trailing 8, so the label's default padding doubled the seam.
	label = { padding_left = 0 },
	color = settings.colors.cyan,
})

local displayedDate

calendar:subscribe({ "forced", "routine", "system_woke" }, function(env)
	local date = os.date("%a %d, %H:%M")
	if date == displayedDate then
		return
	end
	displayedDate = date
	calendar:set({
		label = {
			string = date,
			color = settings.colors.cyan,
		},
	})
end)

calendar:subscribe("mouse.clicked", function(env)
	sbar.exec("open -a 'Calendar'")
end)
