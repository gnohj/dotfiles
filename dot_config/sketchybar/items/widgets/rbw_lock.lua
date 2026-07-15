local colors = require("config.colors")

-- rbw (Bitwarden) vault-lock indicator.
-- Relocated from the tmux status line, where it was redrawn per-session even
-- though the vault is global state. Hidden while the vault is unlocked; shows a
-- red lock glyph when locked (or when the rbw agent isn't running).
local rbw_lock = sbar.add("item", "widgets.rbw_lock", {
	position = "right",
	padding_right = 8,
	updates = "on",
	drawing = false,
	icon = {
		string = "􀎡", -- SF Symbol lock.fill
		color = colors.red,
		padding_left = 0,
		padding_right = 4,
	},
	label = {
		drawing = false,
	},
	update_freq = 15,
	script = "~/.config/sketchybar/items/widgets/rbw_lock.sh",
})

rbw_lock:subscribe({ "forced", "routine", "system_woke" })
