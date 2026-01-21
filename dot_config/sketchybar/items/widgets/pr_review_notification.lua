local constants = require("constants")
local colors = require("config.colors")

-- PR Review notification widget
local pr_review = sbar.add("item", "widgets.pr_review_notification", {
	position = "right",
	padding_right = 12,
	updates = "on",
	icon = {
		string = "",
		color = colors.blue,
		padding_left = 0,
		padding_right = 1,
	},
	label = {
		string = "?",
		padding_left = 1,
		padding_right = 0,
	},
	update_freq = 300,
	script = "~/.config/sketchybar/items/widgets/pr_review_notification.sh",
	drawing = true,
})

pr_review:subscribe({ "forced", "routine", "system_woke" })
