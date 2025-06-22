local settings = require("config.settings")

local apple = sbar.add("item", "apple", {
	icon = { string = settings.icons.text.apple, color = settings.colors.cyan },
	label = { drawing = false },
	click_script = "$CONFIG_DIR/items/menus/bin/menus -s 0",
})
