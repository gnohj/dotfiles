-- Combined workspace widget - workspace indicator + window list
-- Uses ONLY AeroSpaceLua socket connection (no CLI)
local constants = require("constants")
local settings = require("config.settings")
local Aerospace = require("lib.aerospace")

local frontApps = {}
local aerospace = nil
local isShowingSpaces = true

-- Logging setup
local log_dir = os.getenv("HOME") .. "/.logs/sketchybar"
local log_file = log_dir .. "/workspace_" .. os.date("%Y%m") .. ".log"
os.execute("mkdir -p " .. log_dir)

local function log_message(level, message)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local log_entry = string.format("[%s] [%s] [WORKSPACE] %s\n", timestamp, level, message)
	local f = io.open(log_file, "a")
	if f then
		f:write(log_entry)
		f:close()
	end
end

-- Initialize AeroSpace socket connection
local function init_aerospace()
	local ok, result = pcall(function()
		return Aerospace.new()
	end)

	if ok then
		aerospace = result
		log_message("INFO", "AeroSpace socket connection established")
		return true
	else
		log_message("ERROR", "Failed to connect to AeroSpace socket: " .. tostring(result))
		return false
	end
end

-- Reconnect if socket is closed
local function ensure_connection()
	if not aerospace or not aerospace:is_initialized() then
		log_message("WARN", "Socket not initialized, attempting reconnect")
		return init_aerospace()
	end
	return true
end

-- Workspace configurations
local spaceConfigs = {
	["Q"] = { name = "Work", app = "Brave Browser" },
	["W"] = { name = "Slack", app = "Slack" },
	["E"] = { name = "Teams", app = "Microsoft Teams" },
	["B"] = { name = "Browser", app = "Google Chrome" },
	["G"] = { name = "Mail", app = "Mail" },
	["R"] = { name = "Notes", app = "Notes" },
	["F"] = { name = "System", app = "Marta" },
	["D"] = { name = "Discord", app = "Discord" },
	["C"] = { name = "Calendar", app = "Calendar" },
	["V"] = { name = "Passwords", app = "Bitwarden" },
	["S"] = { name = "Music", app = "Spotify" },
	["T"] = { name = "Terminal", app = "Ghostty" },
	["X"] = { name = "Whimsical", app = "Whimsical" },
	["A"] = { name = "YouTube", app = "YouTube" },
	["Z"] = { name = "Brave", app = "Zen" },
}

-- Create workspace indicator item (icon-only)
local workspaceItem = sbar.add("item", constants.items.SPACES, {
	icon = {
		drawing = false,
	},
	label = {
		drawing = false,
	},
	background = {
		height = 26,
		corner_radius = 9,
		border_width = 2,
		color = settings.colors.bg1,
		image = "app.default",
	},
	padding_left = 3,
	padding_right = 3,
	drawing = isShowingSpaces,
})

-- Create front apps bracket and watcher
sbar.add("bracket", constants.items.FRONT_APPS, {}, { position = "left" })
local frontAppWatcher = sbar.add("item", {
	drawing = false,
	updates = true,
})

-- Debouncing
local update_pending = false
local update_running = false

local function selectFocusedWindow(frontAppName)
	for appName, app in pairs(frontApps) do
		local isSelected = appName == frontAppName
		-- Active: cyan, Inactive: dark grey
		local color = isSelected and settings.colors.cyan or settings.colors.dark_grey
		app:set({
			label = { color = color },
			icon = { color = color },
		})
	end
end

local function updateWorkspaceIndicator(currentWorkspace, hasWindows)
	if not ensure_connection() then
		return
	end

	-- Only update if we have windows
	if not hasWindows then
		return
	end

	if currentWorkspace then
		local config = spaceConfigs[currentWorkspace]
		if config and config.app then
			workspaceItem:set({
				background = { image = "app." .. config.app },
				drawing = isShowingSpaces,
			})
		else
			workspaceItem:set({
				background = { image = "app.default" },
				drawing = isShowingSpaces,
			})
		end
	end
end

local function updateWindows()
	log_message("INFO", "updateWindows called")

	if not ensure_connection() then
		log_message("ERROR", "Cannot update windows - no AeroSpace connection")
		update_running = false
		return
	end

	-- Clear existing items
	sbar.remove("/" .. constants.items.FRONT_APPS .. "\\.*/")
	frontApps = {}

	-- Get current workspace using socket
	local ok, currentWorkspace = pcall(function()
		return aerospace:list_current():match("[^\r\n]+")
	end)

	if not ok then
		log_message("ERROR", "Failed to get current workspace: " .. tostring(currentWorkspace))
		update_running = false
		return
	end

	log_message("INFO", "Current workspace: " .. tostring(currentWorkspace))

	-- Get all windows using socket
	local ok2, windowsJson = pcall(function()
		return aerospace:list_all_windows()
	end)

	if not ok2 then
		log_message("ERROR", "Failed to list windows: " .. tostring(windowsJson))
		update_running = false
		return
	end

	-- Count windows in current workspace
	local windowCount = 0
	for _, window in ipairs(windowsJson) do
		if window["workspace"] == currentWorkspace then
			windowCount = windowCount + 1
		end
	end

	-- Hide workspace indicator if no windows
	local hasWindows = windowCount > 0
	workspaceItem:set({ drawing = hasWindows and isShowingSpaces })

	-- Update workspace indicator image
	updateWorkspaceIndicator(currentWorkspace, hasWindows)

	-- Parse windows and create items
	for _, window in ipairs(windowsJson) do
		local windowId = tostring(window["window-id"])
		local windowName = window["app-name"]
		local workspace = window["workspace"]

		-- Only show windows in current workspace
		if workspace == currentWorkspace then
			local labelString = windowName .. " | " .. workspace

			frontApps[windowName] = sbar.add("item", constants.items.FRONT_APPS .. "." .. windowName, {
				label = {
					padding_left = -15,
					string = labelString,
				},
				click_script = "aerospace focus --window-id " .. windowId,
				drawing = isShowingSpaces,
			})

			frontApps[windowName]:subscribe(constants.events.FRONT_APP_SWITCHED, function(env)
				selectFocusedWindow(env.INFO)
			end)
		end
	end

	-- Get focused window using socket (only if we have windows)
	if hasWindows then
		local ok3, focusedWindowJson = pcall(function()
			return aerospace:focused_window()
		end)

		if ok3 and focusedWindowJson and focusedWindowJson ~= "" then
			local cjson = require("cjson")
			local ok4, focusedData = pcall(function()
				return cjson.decode(focusedWindowJson)
			end)

			if ok4 and focusedData and #focusedData > 0 then
				local focusedAppName = focusedData[1]["app-name"]
				log_message("INFO", "Focused window: " .. tostring(focusedAppName))
				selectFocusedWindow(focusedAppName)
			end
		end
	end

	log_message("INFO", "updateWindows completed successfully (windows: " .. windowCount .. ")")
	update_running = false
end

local function getWindows()
	if update_running then
		log_message("WARN", "Update already running, marking pending")
		update_pending = true
		return
	end

	update_running = true
	update_pending = false
	log_message("INFO", "getWindows called")

	local ok, err = pcall(updateWindows)

	if not ok then
		log_message("ERROR", "Error in updateWindows: " .. tostring(err))
		update_running = false
	end

	if update_pending then
		log_message("INFO", "Executing pending update")
		getWindows()
	end
end

local function setVisibility(visible)
	isShowingSpaces = visible
	log_message("INFO", "Setting visibility to: " .. tostring(visible))

	-- Update workspace indicator
	workspaceItem:set({ drawing = visible })

	-- Update all front app items
	for _, app in pairs(frontApps) do
		app:set({ drawing = visible })
	end
end

-- Subscribe to workspace changes (removed - handled in updateWindows)
-- workspaceItem:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, function(env)
-- 	log_message("INFO", "AEROSPACE_WORKSPACE_CHANGED event received")
-- 	updateWorkspaceIndicator()
-- end)

frontAppWatcher:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, function(env)
	log_message("INFO", "AEROSPACE_WORKSPACE_CHANGED event received: " .. tostring(env.FOCUSED_WORKSPACE))
	getWindows()
end)

frontAppWatcher:subscribe(constants.events.FRONT_APP_SWITCHED, function(env)
	log_message("INFO", "FRONT_APP_SWITCHED event received: " .. tostring(env.INFO))
	if env.INFO then
		selectFocusedWindow(env.INFO)
	end
end)

frontAppWatcher:subscribe(constants.events.UPDATE_WINDOWS, function()
	log_message("INFO", "UPDATE_WINDOWS event received")
	getWindows()
end)

-- Subscribe to menu/spaces toggle
frontAppWatcher:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
	local showingMenu = env.isShowingMenu == "on"
	log_message("INFO", "SWAP_MENU_AND_SPACES event received, showingMenu: " .. tostring(showingMenu))
	setVisibility(not showingMenu)
end)

workspaceItem:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
	local showingMenu = env.isShowingMenu == "on"
	setVisibility(not showingMenu)
end)

-- Initialize
if init_aerospace() then
	log_message("INFO", "workspace.lua initialized")
	getWindows()
else
	log_message("ERROR", "Failed to initialize AeroSpace connection - workspace widget disabled")
end
