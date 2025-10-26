local constants = require("constants")
local settings = require("config.settings")

-- Simple focused app display: "App Name | X"
-- Only queries current window, no LIST_WINDOWS overhead

local focused_app = sbar.add("item", "focused_app", {
	position = "left",
	icon = {
		drawing = false,
	},
	label = {
		padding_left = 5,
		color = settings.colors.cyan,
	},
})

local function updateFocusedApp()
	-- Get current workspace
	sbar.exec(constants.aerospace.GET_CURRENT_WORKSPACE, function(workspace_output)
		local workspace = workspace_output:match("[^\r\n]+")

		-- Get current focused window
		sbar.exec(constants.aerospace.GET_CURRENT_WINDOW, function(window_output)
			local app_name = window_output:match("[^\r\n]+")

			if app_name and app_name ~= "" then
				focused_app:set({
					label = { string = app_name .. " | " .. workspace },
					drawing = true,
				})
			else
				-- No focused window, just show workspace
				focused_app:set({
					label = { string = workspace },
					drawing = true,
				})
			end
		end)
	end)
end

-- Subscribe to workspace changes
focused_app:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, function()
	updateFocusedApp()
end)

-- Subscribe to front app switched (when focus changes)
focused_app:subscribe(constants.events.FRONT_APP_SWITCHED, function()
	updateFocusedApp()
end)

-- Initial update
updateFocusedApp()
