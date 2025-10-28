-- Simplified workspace widget - workspace indicator only (NO AeroSpaceLua socket)
-- AeroSpaceLua socket API was causing freezes - commented out for stability
local constants = require("constants")
local settings = require("config.settings")
-- local Aerospace = require("lib.aerospace")  -- DISABLED - causes freezes

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

local function updateWorkspaceIndicator(env)
  local workspace = env and env.FOCUSED_WORKSPACE

  if workspace then
    local config = spaceConfigs[workspace]
    if config and config.app then
      workspaceItem:set({
        background = { image = "app." .. config.app },
        drawing = isShowingSpaces,
      })
    else
      -- Unknown workspace - show default icon
      workspaceItem:set({
        background = { image = "app.default" },
        drawing = isShowingSpaces,
      })
    end
  end
end

-- Subscribe to workspace changes (using event data, not socket API)
workspaceItem:subscribe(constants.events.AEROSPACE_WORKSPACE_CHANGED, function(env)
  updateWorkspaceIndicator(env)
end)

-- Subscribe to menu/spaces toggle
workspaceItem:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
  local showingMenu = env.isShowingMenu == "on"
  isShowingSpaces = not showingMenu
  workspaceItem:set({ drawing = isShowingSpaces })
end)

-- Initialize with default icon
workspaceItem:set({
  background = { image = "app.default" },
  drawing = isShowingSpaces,
})
