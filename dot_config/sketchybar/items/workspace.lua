-- Combined workspace widget - workspace indicator + window list
-- Reads Rift through lib/rift.lua (rift-cli)
local constants = require("constants")
local settings = require("config.settings")
local Rift = require("lib.rift")

sbar.add("event", constants.events.RIFT_WORKSPACE_CHANGED)

local frontApps = {}
local rift = nil
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

local function init_rift()
	local ok, result = pcall(function()
		return Rift.new()
	end)

	if ok then
		rift = result
		log_message("INFO", "Rift reachable")
		return true
	else
		log_message("ERROR", "Rift not reachable: " .. tostring(result))
		return false
	end
end

local function ensure_connection()
	if not rift or not rift:is_initialized() then
		log_message("WARN", "Rift not initialized, attempting reconnect")
		return init_rift()
	end
	return true
end

-- Support multiple apps per workspace (array of apps or single app string)
local spaceConfigs = {
	["Q"] = { name = "Browser", app = "Google Chrome" },
	["W"] = { name = "Slack", app = "Slack" },
	["E"] = { name = "Teams", app = "Microsoft Teams" },
	["B"] = { name = "Helium", app = "Helium" },
	["G"] = { name = "Mail", apps = { "Mail", "Outlook (PWA)" } },
	["R"] = { name = "Kitty", app = "kitty" },
	["F"] = { name = "System", apps = { "Finder", "Photos" } },
	["D"] = { name = "Discord", app = "Discord" },
	["C"] = { name = "Calendar", app = "Calendar" },
	["V"] = { name = "Passwords", app = "Bitwarden" },
	["S"] = { name = "Music", app = "Spotify" },
	["T"] = { name = "Terminal", app = "Ghostty" },
	["Y"] = { name = "Notes", app = "Notes" },
	["X"] = { name = "Productivity", apps = { "Whimsical", "Claude", "Zoom" } },
	["A"] = { name = "Social", apps = { "YouTube", "Reddit", "Twitch", "X" } },
	["M"] = { name = "Texting", app = "Messages" },
	["K"] = { name = "Settings", apps = { "System Settings", "OpenSuperWhisper" } },
	["Z"] = { name = "Brave", app = "Zen" },
	["U"] = { name = "Tailscale", app = "Tailscale" },
	["I"] = { name = "Firstmate", app = "Firstmate 3000" },
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
local shownWorkspace = nil
local shownSignature = nil

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
		log_message("ERROR", "Cannot update windows - Rift not reachable")
		update_running = false
		return
	end

	local ok, currentWorkspace = pcall(function()
		return rift:list_current():match("[^\r\n]+")
	end)

	if not ok then
		log_message("ERROR", "Failed to get current workspace: " .. tostring(currentWorkspace))
		rift = nil  -- force full reconnect on next call
		update_running = false
		return
	end

	log_message("INFO", "Current workspace: " .. tostring(currentWorkspace))

	local ok2, windowsJson = pcall(function()
		return rift:list_all_windows()
	end)

	if not ok2 then
		log_message("ERROR", "Failed to list windows: " .. tostring(windowsJson))
		rift = nil  -- force full reconnect on next call
		update_running = false
		return
	end

	local windowCount = 0
	local windowIds = {}
	for _, window in ipairs(windowsJson) do
		if window["workspace"] == currentWorkspace then
			windowCount = windowCount + 1
			windowIds[#windowIds + 1] = tostring(window["window-id"])
		end
	end

	local hasWindows = windowCount > 0

	-- Get focused window first to determine which app icon to show
	local focusedAppName = nil
	if hasWindows then
		local ok3, focusedWindowJson = pcall(function()
			return rift:focused_window()
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

	local signature = currentWorkspace .. "|" .. table.concat(windowIds, ",")
	if signature == shownSignature then
		log_message("INFO", "updateWindows skipped, nothing changed on " .. currentWorkspace)
		update_running = false
		return
	end
	shownSignature = signature
	shownWorkspace = currentWorkspace

	sbar.remove("/" .. constants.items.FRONT_APPS .. "\\.*/")
	frontApps = {}
	workspaceItem:set({ drawing = hasWindows and isShowingSpaces })
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
				click_script = Rift.focus_command(window),
				drawing = isShowingSpaces,
			})
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

frontAppWatcher:subscribe(constants.events.RIFT_WORKSPACE_CHANGED, function(env)
	log_message("INFO", "RIFT_WORKSPACE_CHANGED event received: " .. tostring(env.FOCUSED_WORKSPACE))
	getWindows()
end)

frontAppWatcher:subscribe(constants.events.FRONT_APP_SWITCHED, function(env)
	log_message("INFO", "FRONT_APP_SWITCHED event received: " .. tostring(env.INFO))
	if env.INFO then
		selectFocusedWindow(env.INFO)
		if shownWorkspace and next(frontApps) then
			updateWorkspaceIndicator(shownWorkspace, true, env.INFO)
		end
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

-- Sketchybar often starts before Rift after login, so keep retrying instead of disabling the widget.
local RETRY_DELAY = 5 -- seconds between attempts
local RETRY_EVENT = "workspace_retry_init"

sbar.exec("sketchybar --add event " .. RETRY_EVENT)

frontAppWatcher:subscribe(RETRY_EVENT, function()
	if rift and rift:is_initialized() then
		return -- already connected, nothing to do
	end
	if init_rift() then
		log_message("INFO", "Rift reachable on retry — workspace widget enabled")
		getWindows()
	else
		sbar.exec("sleep " .. RETRY_DELAY .. " && sketchybar --trigger " .. RETRY_EVENT)
	end
end)

if init_rift() then
	log_message("INFO", "workspace.lua initialized")
	getWindows()
else
	log_message("WARN", "Rift not yet reachable - retrying every " .. RETRY_DELAY .. "s")
	sbar.exec("sleep " .. RETRY_DELAY .. " && sketchybar --trigger " .. RETRY_EVENT)
end
