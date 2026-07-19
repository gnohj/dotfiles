-- Combined workspace widget - workspace indicator + window list
-- Uses ONLY AeroSpaceLua socket connection (no CLI)
local constants = require("constants")
local settings = require("config.settings")
local Aerospace = require("lib.aerospace")

local frontApps = {}
local aerospace = nil
local isShowingSpaces = true

local log_dir = os.getenv("HOME") .. "/.logs/sketchybar"
local log_file = log_dir .. "/workspace_" .. os.date("%Y%m") .. ".log"
sbar.exec("mkdir -p " .. log_dir)

local function log_message(level, message)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local log_entry = string.format("[%s] [%s] [WORKSPACE] %s", timestamp, level, message)
	-- Use async logging to avoid blocking the event loop
	sbar.exec("echo '" .. log_entry:gsub("'", "'\\''") .. "' >> " .. log_file)
end

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

local function ensure_connection()
	if not aerospace or not aerospace:is_initialized() then
		log_message("WARN", "Socket not initialized, attempting reconnect")
		return init_aerospace()
	end
	return true
end

-- Support multiple apps per workspace (array of apps or single app string)
local spaceConfigs = {
	["Q"] = { name = "Browser", app = "Google Chrome" },
	["W"] = { name = "Slack", app = "Slack" },
	["E"] = { name = "Teams", app = "Microsoft Teams" },
	["B"] = { name = "Helium", app = "Helium" },
	["G"] = { name = "Mail", app = "Mail" },
	["R"] = { name = "Kitty", app = "kitty" },
	["F"] = { name = "System", apps = { "Finder", "Photos" } },
	["D"] = { name = "Discord", app = "Discord" },
	["C"] = { name = "Calendar", app = "Calendar" },
	["V"] = { name = "Passwords", app = "Bitwarden" },
	["S"] = { name = "Music", app = "Spotify" },
	["T"] = { name = "Terminal", app = "Ghostty" },
	["Y"] = { name = "Notes", app = "Notes" },
	["X"] = { name = "Productivity", apps = { "Whimsical", "Claude" } },
	["A"] = { name = "YouTube", app = "YouTube" },
	["M"] = { name = "Texting", app = "Messages" },
	["K"] = { name = "Settings", apps = { "System Settings", "OpenSuperWhisper" } },
	["Z"] = { name = "Brave", app = "Zen" },
	["U"] = { name = "Tailscale", app = "Tailscale" },
}

local function getAppForWorkspace(workspace, focusedApp)
	local config = spaceConfigs[workspace]
	if not config then
		return nil
	end

	if config.apps then
		for _, app in ipairs(config.apps) do
			if focusedApp == app then
				return app
			end
		end
		return config.apps[1]
	end

	return config.app
end

local workspaceItem = sbar.add("item", constants.items.SPACES, {
	position = "left",
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

local function updateWorkspaceIndicator(currentWorkspace, hasWindows, focusedApp)
	if not ensure_connection() then
		return
	end

	if not hasWindows then
		return
	end

	if currentWorkspace then
		local appToShow = getAppForWorkspace(currentWorkspace, focusedApp)

		if appToShow then
			workspaceItem:set({
				background = { image = "app." .. appToShow },
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

	sbar.remove("/" .. constants.items.FRONT_APPS .. "\\.*/")
	frontApps = {}

	local ok, currentWorkspace = pcall(function()
		return aerospace:list_current():match("[^\r\n]+")
	end)

	if not ok then
		log_message("ERROR", "Failed to get current workspace: " .. tostring(currentWorkspace))
		aerospace = nil  -- force full reconnect on next call
		update_running = false
		return
	end

	log_message("INFO", "Current workspace: " .. tostring(currentWorkspace))

	local ok2, windowsJson = pcall(function()
		return aerospace:list_all_windows()
	end)

	if not ok2 then
		log_message("ERROR", "Failed to list windows: " .. tostring(windowsJson))
		aerospace = nil  -- force full reconnect on next call
		update_running = false
		return
	end

	local windowCount = 0
	for _, window in ipairs(windowsJson) do
		if window["workspace"] == currentWorkspace then
			windowCount = windowCount + 1
		end
	end

	local hasWindows = windowCount > 0
	workspaceItem:set({ drawing = hasWindows and isShowingSpaces })

	-- Get focused window first to determine which app icon to show
	local focusedAppName = nil
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
				focusedAppName = focusedData[1]["app-name"]
				log_message("INFO", "Focused window: " .. tostring(focusedAppName))
			end
		end
	end

	updateWorkspaceIndicator(currentWorkspace, hasWindows, focusedAppName)

	for _, window in ipairs(windowsJson) do
		local windowId = tostring(window["window-id"])
		local windowName = window["app-name"]
		local workspace = window["workspace"]

		if workspace == currentWorkspace then
			local labelString = windowName .. " | " .. workspace

			frontApps[windowName] = sbar.add("item", constants.items.FRONT_APPS .. "." .. windowName, {
				position = "left",
				label = {
					padding_left = -15,
					string = labelString,
				},
				click_script = "aerospace focus --window-id " .. windowId,
				drawing = isShowingSpaces,
			})

			frontApps[windowName]:subscribe(constants.events.FRONT_APP_SWITCHED, function(env)
				selectFocusedWindow(env.INFO)
				if not ensure_connection() then
					return
				end
				local ok, currWorkspace = pcall(function()
					return aerospace:list_current():match("[^\r\n]+")
				end)
				if ok then
					updateWorkspaceIndicator(currWorkspace, true, env.INFO)
				end
			end)
		end
	end

	if focusedAppName then
		selectFocusedWindow(focusedAppName)
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

	workspaceItem:set({ drawing = visible })

	for _, app in pairs(frontApps) do
		app:set({ drawing = visible })
	end
end

-- Workspace changes are handled in updateWindows, not via a separate subscribe
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

frontAppWatcher:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
	local showingMenu = env.isShowingMenu == "on"
	log_message("INFO", "SWAP_MENU_AND_SPACES event received, showingMenu: " .. tostring(showingMenu))
	setVisibility(not showingMenu)
end)

workspaceItem:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
	local showingMenu = env.isShowingMenu == "on"
	setVisibility(not showingMenu)
end)

-- Retry init on a schedule until AeroSpace's socket is reachable. Sketchybar
-- often starts before AeroSpace is fully up after boot/login, which used to
-- log a permanent failure and leave the workspace widget disabled forever.
local RETRY_DELAY = 5 -- seconds between attempts
local RETRY_EVENT = "workspace_retry_init"

sbar.exec("sketchybar --add event " .. RETRY_EVENT)

frontAppWatcher:subscribe(RETRY_EVENT, function()
	if aerospace and aerospace:is_initialized() then
		return -- already connected, nothing to do
	end
	if init_aerospace() then
		log_message("INFO", "AeroSpace reachable on retry — workspace widget enabled")
		getWindows()
	else
		sbar.exec("sleep " .. RETRY_DELAY .. " && sketchybar --trigger " .. RETRY_EVENT)
	end
end)

if init_aerospace() then
	log_message("INFO", "workspace.lua initialized")
	getWindows()
else
	log_message("WARN", "AeroSpace socket not yet reachable - retrying every " .. RETRY_DELAY .. "s")
	sbar.exec("sleep " .. RETRY_DELAY .. " && sketchybar --trigger " .. RETRY_EVENT)
end
