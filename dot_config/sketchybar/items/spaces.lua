local constants = require("constants")
local settings = require("config.settings")

local spaces = {}
local currentWorkspace = nil -- Track current workspace to prevent stale focused_app updates

local swapWatcher = sbar.add("item", {
	drawing = false,
	updates = true,
})

local currentWorkspaceWatcher = sbar.add("item", {
	drawing = false,
	updates = true,
})

local spaceConfigs <const> = {
	["Q"] = { name = "Work", app = "Brave Browser" },
	["W"] = { name = "Slack", app = "Slack" },
	["E"] = { name = "Teams", app = "Microsoft Teams" },
	["B"] = { name = "Browser", app = "Google Chrome" },
	["G"] = { name = "Mail", app = "Mail" },
	-- ["F"] = { name = "System", app = "System Settings" },
	["F"] = { name = "System", app = "Marta" },
	["D"] = { name = "Discord", app = "Discord" },
	["C"] = { name = "Calendar", app = "Calendar" },
	["V"] = { name = "Passwords", app = "Bitwarden" },
	["S"] = { name = "Music", app = "Spotify" },
	["T"] = { name = "Terminal", app = "Ghostty" },
	["X"] = { name = "Whimsical", app = "Whimsical" },
	["A"] = { name = "YouTube", app = "YouTube" },
	["Z"] = { name = "Brave", app = "Zen" },
	-- ["T"] = { name = "Terminal", app = "WezTerm" },
}

local function selectCurrentWorkspace(focusedWorkspaceName)
	for sid, item in pairs(spaces) do
		if item ~= nil then
			local isSelected = sid == constants.items.SPACES .. "." .. focusedWorkspaceName
			print("selected", isSelected)

			local spaceConfig = spaceConfigs[focusedWorkspaceName]

			if spaceConfig.app then
				-- App icon workspace
				item:set({
					label = {
						color = isSelected and settings.colors.bg1 or settings.colors.light_blue,
					},
					background = {
						height = 26,
						corner_radius = 9,
						border_width = 2,
						color = isSelected and settings.colors.transparent or settings.colors.bg1,
						image = "app." .. spaceConfig.app,
					},
				})
			else
				-- Nerd font icon workspace
				item:set({
					icon = {
						color = isSelected and settings.colors.bg1 or settings.colors.light_blue,
					},
					label = {
						color = isSelected and settings.colors.bg1 or settings.colors.light_blue,
					},
					background = {
						height = 26,
						corner_radius = 9,
						border_width = 2,
						color = isSelected and settings.colors.light_blue or settings.colors.bg1,
					},
				})
			end
		end
	end

	sbar.trigger(constants.events.UPDATE_WINDOWS)
end

local function findAndSelectCurrentWorkspace()
	sbar.exec(constants.aerospace.GET_CURRENT_WORKSPACE, function(focusedWorkspaceOutput)
		local focusedWorkspaceName = focusedWorkspaceOutput:match("[^\r\n]+")
		selectCurrentWorkspace(focusedWorkspaceName)
	end)
end

local function addWorkspaceItem(workspaceName, isCurrentWorkspace)
	-- Only add the item if it's the current workspace
	if not isCurrentWorkspace then
		return
	end

	local spaceName = constants.items.SPACES .. "." .. workspaceName
	print("spaceName", spaceName)
	local spaceConfig = spaceConfigs[workspaceName]
	print("spaceConfig", spaceConfig)

	local itemConfig = {
		updates = "when_shown",
		label = {
			width = 0,
			font = "SF Pro:Semibold:13.0",
			color = settings.colors.label,
			padding_left = 3,
			padding_right = 3,
		},
		padding_left = 3,
		padding_right = 3,
		click_script = "aerospace workspace " .. workspaceName,
	}

	if spaceConfig.app then
		-- Use app icon
		itemConfig.icon = { drawing = false }
		itemConfig.background = {
			height = 26,
			corner_radius = 9,
			border_width = 2,
			color = settings.colors.bg1,
			image = "app." .. spaceConfig.app,
		}
	else
		-- Use nerd font icon - include label string
		itemConfig.label.string = spaceConfig.name
		itemConfig.icon = {
			font = "SF Pro:Bold:14.0",
			color = settings.colors.light_blue,
			padding_left = 3,
			padding_right = 3,
			string = spaceConfig.icon or settings.icons.apps["default"],
		}
		itemConfig.background = {
			height = 26,
			corner_radius = 9,
			border_width = 2,
			color = settings.colors.bg1,
		}
	end

	spaces[spaceName] = sbar.add("item", spaceName, itemConfig)

	spaces[spaceName]:subscribe("mouse.entered", function()
		sbar.animate("tanh", 30, function()
			spaces[spaceName]:set({ label = { width = "dynamic" } })
		end)
	end)

	spaces[spaceName]:subscribe("mouse.exited", function()
		sbar.animate("tanh", 30, function()
			spaces[spaceName]:set({ label = { width = 0 } })
		end)
	end)

	sbar.add("item", spaceName .. ".padding", {
		width = 3, -- Using PADDINGS=3 from shell config
	})

	-- Add focused app display right after workspace
	local function updateFocusedAppForWorkspace()
		local workspaceForThisQuery = workspaceName -- Capture workspace name in closure
		sbar.exec(constants.aerospace.GET_CURRENT_WINDOW, function(window_output)
			-- Ignore this response if we've switched to a different workspace
			if currentWorkspace ~= workspaceForThisQuery then
				return
			end

			local app_name = window_output:match("[^\r\n]+")
			local focused_app_item = spaceName .. ".focused_app"

			-- Remove old focused_app if it exists
			sbar.remove(focused_app_item)

			if app_name and app_name ~= "" then
				sbar.add("item", focused_app_item, {
					position = "left",
					icon = { drawing = false },
					label = {
						string = app_name .. " | " .. workspaceName,
						padding_left = 5,
						color = settings.colors.cyan,
					},
				})
			end
		end)
	end

	updateFocusedAppForWorkspace()
end

local function createWorkspaces()
	-- First get the current workspace
	sbar.exec(constants.aerospace.GET_CURRENT_WORKSPACE, function(currentWorkspaceOutput)
		local currentWorkspaceName = currentWorkspaceOutput:match("[^\r\n]+")
		currentWorkspace = currentWorkspaceName -- Initialize current workspace tracker

		-- Then get all workspaces
		sbar.exec(constants.aerospace.LIST_ALL_WORKSPACES, function(workspacesOutput)
			for workspaceName in workspacesOutput:gmatch("[^%s]+") do
				print("Workspace:", workspaceName)

				-- Add workspace if it exists in spaceConfigs and only if it's current
				if workspaceName and spaceConfigs[workspaceName] then
					local isCurrentWorkspace = workspaceName == currentWorkspaceName
					addWorkspaceItem(workspaceName, isCurrentWorkspace)
				end
			end

			findAndSelectCurrentWorkspace()
		end)
	end)
end

swapWatcher:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
	local isShowingSpaces = env.isShowingMenu == "off" and true or false
	sbar.set("/" .. constants.items.SPACES .. "\\..*/", { drawing = isShowingSpaces })
end)

currentWorkspaceWatcher:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, function(env)
	-- Update current workspace tracker
	local newWorkspaceName = env.FOCUSED_WORKSPACE
	currentWorkspace = newWorkspaceName

	-- Remove all existing workspace items (including focused_app items)
	sbar.remove("/" .. constants.items.SPACES .. "\\..*/")
	spaces = {}

	-- Add the new current workspace item
	if newWorkspaceName and spaceConfigs[newWorkspaceName] then
		addWorkspaceItem(newWorkspaceName, true) -- true because it's the current workspace
	end

	-- Select the new workspace (this will style it as selected)
	selectCurrentWorkspace(newWorkspaceName)
end)

createWorkspaces()
