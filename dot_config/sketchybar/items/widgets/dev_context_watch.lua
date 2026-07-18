-- Invisible poller: detects a bare `ssh <host>` (one the `vps` wrapper didn't launch) and drives dev-context to match, reverting to local on disconnect. No display of its own; it just fires dev_context_change, which repaints the dev-context + tailscale widgets.
local dev_context_watch = sbar.add("item", "widgets.dev_context_watch", {
	position = "right",
	drawing = false,
	updates = "on",
	update_freq = 5,
	script = "~/.config/sketchybar/items/widgets/dev-context-watch.sh",
})

dev_context_watch:subscribe({ "forced", "routine", "system_woke" })
