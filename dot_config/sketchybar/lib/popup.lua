local M = {}

-- One invocation so the closes and the open apply in order; mouse.exited.global cannot do this, as it
-- only fires when the pointer leaves the bar (upstream #178) and never during a click on another widget.
function M.open_exclusive(name)
	sbar.exec("sketchybar -m --set '/.*/' popup.drawing=off --set " .. name .. " popup.drawing=on")
end

return M
