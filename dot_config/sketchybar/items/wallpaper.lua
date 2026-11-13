-- macOS restores a display's own remembered wallpaper on reconnect, so reapply the active one.
local watcher = sbar.add("item", "wallpaper_watcher", { drawing = false, updates = true })

watcher:subscribe({ "display_change", "system_woke" }, function()
	sbar.exec("sleep 2; $HOME/.local/bin/wallpaper-apply")
end)
