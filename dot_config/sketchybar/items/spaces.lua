local constants = require("constants")
local settings = require("config.settings")

local spaces = {}

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
		for workspaceName in workspacesOutput:gmatch("[^%s]+") do
			if workspaceName and spaceConfigs[workspaceName] then
				addWorkspaceItem(workspaceName)
			else
			end
		end
	end)
end

createWorkspaces()
