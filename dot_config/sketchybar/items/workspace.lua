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

-- Fixed chip slots are reused in place, since adding and removing items reflows the whole bar.
local chips = {}
for i = 1, 8 do
	chips[i] = sbar.add("item", constants.items.FRONT_APPS .. "." .. i, {
		position = "left",
		drawing = false,
		icon = {
			string = "",
			width = 34,
			padding_left = 0,
			padding_right = 0,
			background = { drawing = true, image = { scale = 0.56, padding_left = 10 } },
		},
		label = {
			font = { size = 13.0 },
			color = settings.colors.dark_grey,
			padding_left = 0,
			padding_right = 3,
		},
		padding_left = 0,
		padding_right = 0,
	})
end

local workspaceItem = sbar.add("item", constants.items.SPACES, {
	position = "left",
	icon = {
		string = utf8.char(0xF0635),
		font = { size = 12.0 },
		color = settings.colors.cyan,
		padding_left = 6,
		padding_right = 2,
	},
	label = {
		font = { style = settings.fonts.styles.bold, size = 13.0 },
		color = settings.colors.cyan,
		padding_left = 0,
		padding_right = 11,
	},
	padding_left = 0,
	padding_right = 0,
	drawing = isShowingSpaces,
})

local chipNames = { constants.items.SPACES }
for _, chip in ipairs(chips) do
	chipNames[#chipNames + 1] = chip.name
end
sbar.add("bracket", constants.items.FRONT_APPS, chipNames, {
	position = "left",
	background = {
		height = 24,
		corner_radius = 12,
		border_width = 1,
		color = settings.colors.transparent,
		border_color = settings.colors.with_alpha(settings.colors.dark_grey, 0.5),
		padding_left = 0,
		padding_right = 0,
	},
})
require("items.rift_layout")
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
		local color = isSelected and settings.colors.cyan or settings.colors.dark_grey
		app:set({ label = { color = color } })
	end
end

local function updateWorkspaceIndicator(currentWorkspace)
	if currentWorkspace then
		workspaceItem:set({ label = { string = currentWorkspace }, drawing = isShowingSpaces })
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

	frontApps = {}
	updateWorkspaceIndicator(currentWorkspace)

	local used = 0
	for _, window in ipairs(windowsJson) do
		local windowName = window["app-name"]
		if window["workspace"] == currentWorkspace and not frontApps[windowName] and used < #chips then
			used = used + 1
			chips[used]:set({
				drawing = isShowingSpaces,
				icon = { background = { image = { string = "app." .. (window["bundle-id"] or windowName) } } },
				label = { string = windowName },
				click_script = Rift.focus_command(window),
			})
			frontApps[windowName] = chips[used]
		end
	end
	for i = used + 1, #chips do
		chips[i]:set({ drawing = false })
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
