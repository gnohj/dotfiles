local constants = require("constants")
local settings = require("config.settings")

-- Add the brew_update event
os.execute("sketchybar --add event brew_update")

-- Configure the brew item
sbar.add("item", constants.items.BREW_NOTIFICATION, {
	position = "right",
	width = settings.dimens.padding.item,
	padding_right = 8, -- Add some spacing
	icon = " ",
	-- Set freq to update every 1hr
	update_freq = 1800 * 2,
	label = {
		padding_left = 2,
	},
	script = "~/.config/sketchybar/items/widgets/brew_notification.sh",
	drawing = true, -- Changed from false since you want it visible
})

-- Subscribe the item to the brew_update event
os.execute("sketchybar --subscribe " .. constants.items.BREW_NOTIFICATION .. " brew_update")
