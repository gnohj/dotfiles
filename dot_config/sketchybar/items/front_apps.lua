local constants = require("constants")
local settings = require("config.settings")
local frontApps = {}
sbar.add("bracket", constants.items.FRONT_APPS, {}, { position = "left" })
local frontAppWatcher = sbar.add("item", {
	drawing = false,
	updates = true,
})

local function selectFocusedWindow(frontAppName)
	-- print("frontAppz", frontAppName)
	for appName, app in pairs(frontApps) do
		local isSelected = appName == frontAppName
		local color = isSelected and settings.colors.cyan or settings.colors.grey
		app:set({
			label = { color = color },
			icon = { color = color },
		})
	end
end

local function updateWindows(windows)
	sbar.remove("/" .. constants.items.FRONT_APPS .. "\\.*/")
	frontApps = {}

	-- Get current workspace first, then process all windows
	sbar.exec(constants.aerospace.GET_CURRENT_WORKSPACE, function(workspaceOutput)
		local currentWorkspace = workspaceOutput:match("[^\r\n]+")

		local foundWindows = string.gmatch(windows, "[^\n]+")
		for window in foundWindows do
			local parsedWindow = {}
			for key, value in string.gmatch(window, "(%w+)=([%w%s]+)") do
				parsedWindow[key] = value
			end
			local windowId = parsedWindow["id"]
			local windowName = parsedWindow["name"]
			local icon = settings.icons.apps[windowName] or settings.icons.apps["default"]

			-- Create label with workspace name
			local labelString = windowName .. " | " .. currentWorkspace

			frontApps[windowName] = sbar.add("item", constants.items.FRONT_APPS .. "." .. windowName, {
				label = {
					padding_left = 0,
					string = labelString,
				},
				icon = {
					string = icon,
					font = settings.fonts.icons(),
				},
				click_script = "aerospace focus --window-id " .. windowId,
			})

			frontApps[windowName]:subscribe(constants.events.FRONT_APP_SWITCHED, function(env)
				selectFocusedWindow(env.INFO)
			end)
		end

		-- After all items are created, select the focused window
		sbar.exec(constants.aerospace.GET_CURRENT_WINDOW, function(frontAppName)
			selectFocusedWindow(frontAppName:gsub("[\n\r]", ""))
		end)
	end)
end

local function getWindows()
	sbar.exec(constants.aerospace.LIST_WINDOWS, updateWindows)
end

frontAppWatcher:subscribe(constants.events.UPDATE_WINDOWS, function()
	getWindows()
end)

getWindows()
