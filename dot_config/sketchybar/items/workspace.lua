-- Simplified workspace widget - single item with icon + text
local constants = require("constants")
local settings = require("config.settings")

local isShowingSpaces = true

-- Workspace configurations
local spaceConfigs = {
  ["Q"] = { name = "Work", app = "Brave Browser" },
  ["W"] = { name = "Slack", app = "Slack" },
  ["E"] = { name = "Teams", app = "Microsoft Teams" },
  ["B"] = { name = "Browser", app = "Google Chrome" },
  ["G"] = { name = "Mail", app = "Mail" },
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

-- Single workspace item with both background image and label
local workspaceItem = sbar.add("item", constants.items.SPACES, {
  icon = {
    drawing = true,
    string = "",
    padding_left = 30,  -- Push icon to make room for background image
    padding_right = 0,
  },
  label = {
    drawing = true,
    string = "",
    color = settings.colors.cyan,
    padding_left = 10,
    padding_right = 8,
  },
  background = {
    height = 26,
    corner_radius = 9,
    border_width = 0,
    color = settings.colors.transparent,
    image = "app.default",
  },
  padding_left = 3,
  padding_right = 3,
  drawing = isShowingSpaces,
})

local function updateWorkspaceIndicator(env)
  local workspace = env and env.FOCUSED_WORKSPACE

  if workspace then
    local config = spaceConfigs[workspace]
    if config and config.app then
      workspaceItem:set({
        label = {
          string = config.app,
          color = settings.colors.cyan,
        },
        background = {
          image = "app." .. config.app,
        },
      })
    else
      workspaceItem:set({
        label = {
          string = workspace,
          color = settings.colors.grey,
        },
        background = {
          image = "app.default",
        },
      })
    end
  end
end

-- Subscribe to workspace changes
workspaceItem:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, function(env)
  updateWorkspaceIndicator(env)
end)

-- Subscribe to menu/spaces toggle
workspaceItem:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
  local showingMenu = env.isShowingMenu == "on"
  isShowingSpaces = not showingMenu
  workspaceItem:set({ drawing = isShowingSpaces })
end)
