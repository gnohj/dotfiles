--- rift module: window queries for items/workspace.lua via rift-cli (Mach IPC, under 10ms per call).

local cjson = require("cjson")

local CLI = "/opt/homebrew/bin/rift-cli"

local Rift = {}
Rift.__index = Rift

local function query(args)
	local handle = io.popen(CLI .. " query " .. args .. " 2>/dev/null")
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

local function query_workspaces()
	return query("workspaces")
end

local function has_focused_window(ws)
	for _, w in ipairs(ws.windows or {}) do
		if w.is_focused then
			return true
		end
	end
	return false
end

-- Shared display mode marks one workspace active per display, so ask the active display.
local function active_display_workspace()
	for _, display in ipairs(query("displays")) do
		if display.is_active_context then
			for _, ws in ipairs(query("workspaces --display " .. display.uuid)) do
				if ws.is_active then
					return ws.name
				end
			end
		end
	end
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
	local active = {}
	for _, ws in ipairs(self.workspaces) do
		if ws.is_active then
			if has_focused_window(ws) then
				return ws.name
			end
			active[#active + 1] = ws.name
		end
	end
	if #active > 1 then
		return active_display_workspace() or active[1]
	end
	return active[1] or error("rift reported no active workspace")
end

function Rift:list_all_windows()
	local windows = {}
	for _, ws in ipairs(self:snapshot()) do
		for _, w in ipairs(ws.windows or {}) do
			windows[#windows + 1] = {
				["window-id"] = math.tointeger(w.window_server_id) or w.window_server_id,
				["app-name"] = w.app_name,
				["bundle-id"] = w.bundle_id,
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
