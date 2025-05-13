local constants = require("constants")
local settings = require("config.settings")

local spaces = {}

local swapWatcher = sbar.add("item", {
	drawing = false,
	updates = true,
})

local currentWorkspaceWatcher = sbar.add("item", {
	drawing = false,
	updates = true,
})

-- Modify this file with Visual Studio Code - at least vim does have problems with the icons
-- copy "Icons" from the nerd fonts cheat sheet and replace icon and name accordingly below
-- https://www.nerdfonts.com/cheat-sheet
local spaceConfigs <const> = {
	["1"] = { icon = "󰌃", name = "Work" },
	["2"] = { icon = "", name = "Dev" },
	["3"] = { icon = "", name = "Slack" },
	["4"] = { icon = "󰊻", name = "Teams" },
	["B"] = { icon = "󰖟", name = "Browser" },
	["D"] = { icon = "", name = "Discord" },
	["E"] = { icon = "󰨞", name = "Editor" },
	["C"] = { icon = "󰃭", name = "Calendar" },
	["M"] = { icon = "", name = "Mail" },
	["P"] = { icon = "", name = "Passwords" },
	["N"] = { icon = "󱞁", name = "Notes" },
	["S"] = { icon = "", name = "Music" },
	["T"] = { icon = "", name = "Terminal" },
	["W"] = { icon = "󱁉", name = "Whimsical" },
}

local function selectCurrentWorkspace(focusedWorkspaceName)
	for sid, item in pairs(spaces) do
		if item ~= nil then
			local isSelected = sid == constants.items.SPACES .. "." .. focusedWorkspaceName
			-- print("selected", isSelected)
			item:set({
				icon = { color = isSelected and settings.colors.bg1 or settings.colors.light_blue },
				label = { color = isSelected and settings.colors.bg1 or settings.colors.light_blue },
				background = { color = isSelected and settings.colors.light_blue or settings.colors.bg1 },
			})
		end
	end

	sbar.trigger(constants.events.UPDATE_WINDOWS)
end

local function findAndSelectCurrentWorkspace()
	sbar.exec(constants.aerospace.GET_CURRENT_WORKSPACE, function(focusedWorkspaceOutput)
		local focusedWorkspaceName = focusedWorkspaceOutput:match("[^\r\n]+")
		-- print("weeeez", focusedWorkspaceName)
		selectCurrentWorkspace(focusedWorkspaceName)
	end)
end

local function addWorkspaceItem(workspaceName)
	local spaceName = constants.items.SPACES .. "." .. workspaceName
	local spaceConfig = spaceConfigs[workspaceName]

	spaces[spaceName] = sbar.add("item", spaceName, {
		label = {
			width = 0,
			padding_left = 0,
			string = spaceConfig.name,
		},
		icon = {
			string = spaceConfig.icon or settings.icons.apps["default"],
			color = settings.colors.light_blue,
		},
		background = {
			color = settings.colors.bg1,
		},
		click_script = "aerospace workspace " .. workspaceName,
	})

	spaces[spaceName]:subscribe("mouse.entered", function(env)
		sbar.animate("tanh", 30, function()
			spaces[spaceName]:set({ label = { width = "dynamic" } })
		end)
	end)

	spaces[spaceName]:subscribe("mouse.exited", function(env)
		sbar.animate("tanh", 30, function()
			spaces[spaceName]:set({ label = { width = 0 } })
		end)
	end)

	sbar.add("item", spaceName .. ".padding", {
		width = settings.dimens.padding.label,
	})
end

local function createWorkspaces()
	sbar.exec(constants.aerospace.LIST_ALL_WORKSPACES, function(workspacesOutput)
		-- Debugging: print the full output with hidden characters
		-- print("Complete output with hidden characters:", string.format("%q", workspacesOutput))

		-- Split the output by newlines and spaces to process both numbers and letters
		for workspaceName in workspacesOutput:gmatch("[^%s]+") do
			-- Print workspace for debugging
			-- print("Workspace:", workspaceName)

			-- Add workspace if it exists in spaceConfigs
			if workspaceName and spaceConfigs[workspaceName] then
				addWorkspaceItem(workspaceName)
			else
				-- print("No config for workspace:", workspaceName)
			end
		end

		-- findAndSelectCurrentWorkspace()
	end)
end

-- local function createWorkspaces()
--   sbar.exec(constants.aerospace.LIST_ALL_WORKSPACES, function(workspacesOutput)
-- 	  print("blah", workspacesOutput)
-- 	        for workspaceName in workspacesOutput:gmatch("[^\r\n]+") do
--
-- 	    print("woazz", workspaceName)
--       addWorkspaceItem(workspaceName)
--     end
--
-- findAndSelectCurrentWorkspace()
--   end)
-- end

swapWatcher:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
	-- local isShowingSpaces = env.isShowingMenu == "off" and true or false
	-- sbar.set("/" .. constants.items.SPACES .. "\\..*/", { drawing = isShowingSpaces })
end)

currentWorkspaceWatcher:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, function(env)
	-- selectCurrentWorkspace(env.FOCUSED_WORKSPACE)
	-- sbar.trigger(constants.events.UPDATE_WINDOWS)
end)

createWorkspaces()
