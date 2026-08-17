local colors = require("config.colors")
local dimens = require("config.dimens")
local settings = require("config.settings")

-- rbw (Bitwarden) vault-lock indicator.
-- Relocated from the tmux status line, where it was redrawn per-session even
-- though the vault is global state. Always visible in the palette blue; the glyph carries the state (closed padlock locked, open unlocked), so the colour never changes.
-- Flex-gap convention: icon-only, leading 0, trailing = dimens.padding.gap.
local rbw_lock = sbar.add("item", "widgets.rbw_lock", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	icon = {
		string = settings.icons.text.lock.locked,
		color = colors.blue,
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		drawing = false,
	},
	update_freq = 15,
	script = "~/.config/sketchybar/items/widgets/rbw_lock.sh",
})

rbw_lock:subscribe({ "forced", "routine", "system_woke" })
