local colors = require("config.colors")
local dimens = require("config.dimens")

-- rbw (Bitwarden) vault-lock indicator.
-- Relocated from the tmux status line, where it was redrawn per-session even
-- though the vault is global state. Hidden while the vault is unlocked; shows a
-- red lock glyph when locked (or when the rbw agent isn't running).
-- Flex-gap convention: icon-only, leading 0, trailing = dimens.padding.gap.
local rbw_lock = sbar.add("item", "widgets.rbw_lock", {
	position = "right",
	padding_left = 0,
	padding_right = dimens.padding.gap,
	updates = "on",
	drawing = false,
	icon = {
		string = "􀎡", -- SF Symbol lock.fill
		color = colors.red,
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
