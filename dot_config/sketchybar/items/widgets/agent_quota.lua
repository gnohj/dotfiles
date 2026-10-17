local colors = require("config.colors")
local dimens = require("config.dimens")

-- Tightest remaining quota window across Claude (both accounts), Codex and Copilot.
local agent_quota = sbar.add("item", "agent_quota", {
	position = "right",
	padding_left = 0,
	-- Last item in the notifications badge, so this is the badge's closing inner space.
	padding_right = 8,
	updates = "on",
	update_freq = 1800,
	icon = {
		string = "󰚩",
		color = colors.cyan,
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		drawing = false,
	},
	script = "~/.config/sketchybar/items/widgets/agent-quota.sh",
})

agent_quota:subscribe({ "forced", "routine", "system_woke" })
