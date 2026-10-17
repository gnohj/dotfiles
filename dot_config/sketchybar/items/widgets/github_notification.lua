local constants = require("constants")
local colors = require("config.colors")
local groups = require("items.widgets.groups")

local FLAG <const> = os.getenv("HOME") .. "/github-custom-notification.txt"

local push = sbar.add("item", constants.items.GITHUB_NOTIFICATION, {
	position = "right",
	padding_left = 0,
	padding_right = 0,
	updates = "on",
	icon = { drawing = false },
	label = { string = "\u{f09b} \u{f062}", color = colors.blue, padding_left = 0, padding_right = 0 },
})

local function update()
	local file = io.open(FLAG, "r")
	if file then
		file:close()
	end
	groups.show("push", file ~= nil)
end

push:subscribe({ "forced", "routine", "system_woke" }, update)

return update
