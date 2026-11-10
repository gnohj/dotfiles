-- SketchyBar only stops a config that already owns items, so one still loading on reload must stop itself.
local M = {}

local pid = os.getenv("SKETCHYBAR_CONFIG_PID")
local pidFile = os.getenv("SKETCHYBAR_CONFIG_PID_FILE")

local FIRST_CHECK_SECONDS = 2
local RECHECK_SECONDS = 30

local function superseded()
	if not pid or not pidFile then
		return false
	end
	local file = io.open(pidFile, "r")
	if not file then
		return false
	end
	local current = file:read("a")
	file:close()
	return current ~= pid
end

function M.exit_if_superseded()
	if superseded() then
		os.exit(0)
	end
end

function M.watch(seconds)
	sbar.delay(seconds or FIRST_CHECK_SECONDS, function()
		M.exit_if_superseded()
		M.watch(RECHECK_SECONDS)
	end)
end

return M
