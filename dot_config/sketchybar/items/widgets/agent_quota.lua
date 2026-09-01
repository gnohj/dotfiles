local colors = require("config.colors")
local dimens = require("config.dimens")

-- Tightest remaining quota window across Claude (both accounts), Codex and Copilot.
local agent_quota = sbar.add("item", "agent_quota", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	update_freq = 1800,
	icon = {
		string = "󰚩",
		color = colors.green,
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		drawing = false,
	},
	script = "~/.config/sketchybar/items/widgets/agent-quota.sh",
})

agent_quota:subscribe({ "forced", "routine", "system_woke" })
