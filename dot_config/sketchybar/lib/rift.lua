--- rift module: window queries for items/workspace.lua via rift-cli (Mach IPC, under 10ms per call).

local cjson = require("cjson")

local CLI = "/opt/homebrew/bin/rift-cli"

local Rift = {}
Rift.__index = Rift

local function query_workspaces()
	local handle = io.popen(CLI .. " query workspaces 2>/dev/null")
	if not handle then
		error("rift-cli could not be started")
	end
	local raw = handle:read("*a")
	handle:close()
	local ok, data = pcall(cjson.decode, raw)
	if not ok or type(data) ~= "table" then
		error("rift is not reachable")
	end
	return data
end

function Rift.new()
	query_workspaces()
	return setmetatable({ initialized = true }, Rift)
end

function Rift:is_initialized()
	return self.initialized
end

-- items/workspace.lua always asks for the current workspace first, so that call takes the one snapshot the others reuse.
function Rift:snapshot()
	return self.workspaces or query_workspaces()
end

function Rift:list_current()
	self.workspaces = query_workspaces()
	for _, ws in ipairs(self.workspaces) do
		if ws.is_active then
			return ws.name
		end
	end
	error("rift reported no active workspace")
end

function Rift:list_all_windows()
	local windows = {}
	for _, ws in ipairs(self:snapshot()) do
		for _, w in ipairs(ws.windows or {}) do
			windows[#windows + 1] = {
				["window-id"] = math.tointeger(w.window_server_id) or w.window_server_id,
				["app-name"] = w.app_name,
				["window-title"] = w.title,
				["workspace"] = ws.name,
				rift_id = cjson.encode(w.id),
			}
		end
	end
	return windows
end

function Rift:focused_window()
	for _, ws in ipairs(self:snapshot()) do
		for _, w in ipairs(ws.windows or {}) do
			if w.is_focused then
				return cjson.encode({ { ["app-name"] = w.app_name } })
			end
		end
	end
	return ""
end

function Rift.focus_command(window)
	return string.format("%s execute window focus --window-id '%s' --window-server-id %s",
		CLI, window.rift_id, tostring(window["window-id"]))
end

return Rift
