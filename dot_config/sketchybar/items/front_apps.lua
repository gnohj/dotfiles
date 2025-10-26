local constants = require("constants")
local settings = require("config.settings")
local frontApps = {}

-- Logging setup
local log_dir = os.getenv("HOME") .. "/.logs/sketchybar"
local log_file = log_dir .. "/front_apps_" .. os.date("%Y%m") .. ".log"
os.execute("mkdir -p " .. log_dir)

local function log_message(level, message)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local log_entry = string.format("[%s] [%s] [FRONT_APPS] %s\n", timestamp, level, message)
  local f = io.open(log_file, "a")
  if f then
    f:write(log_entry)
    f:close()
  end
end

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
  log_message("INFO", "updateWindows called")
  sbar.remove("/" .. constants.items.FRONT_APPS .. "\\.*/")
  frontApps = {}

  log_message("INFO", "Executing GET_CURRENT_WORKSPACE query")
  -- Get current workspace first, then process all windows
  sbar.exec(constants.aerospace.GET_CURRENT_WORKSPACE, function(workspaceOutput)
    log_message("INFO", "GET_CURRENT_WORKSPACE callback received")
    local currentWorkspace = workspaceOutput:match("[^\r\n]+")

    local foundWindows = string.gmatch(windows, "[^\n]+")
    for window in foundWindows do
      local parsedWindow = {}
      for key, value in string.gmatch(window, "(%w+)=([%w%s]+)") do
        parsedWindow[key] = value
      end
      local windowId = parsedWindow["id"]
      local windowName = parsedWindow["name"]
      local icon = settings.icons.apps[windowName]
        or settings.icons.apps["default"]

      -- Create label with workspace name
      local labelString = windowName .. " | " .. currentWorkspace

      frontApps[windowName] =
        sbar.add("item", constants.items.FRONT_APPS .. "." .. windowName, {
          label = {
            padding_left = -15,
            string = labelString,
          },
          -- icon = {
          -- 	string = icon,
          -- 	font = settings.fonts.icons(),
          -- },
          click_script = "aerospace focus --window-id " .. windowId,
        })

      frontApps[windowName]:subscribe(
        constants.events.FRONT_APP_SWITCHED,
        function(env)
          selectFocusedWindow(env.INFO)
        end
      )
    end

    log_message("INFO", "Executing GET_CURRENT_WINDOW query")
    -- After all items are created, select the focused window
    sbar.exec(constants.aerospace.GET_CURRENT_WINDOW, function(frontAppName)
      log_message("INFO", "GET_CURRENT_WINDOW callback received for: " .. tostring(frontAppName))
      selectFocusedWindow(frontAppName:gsub("[\n\r]", ""))
      log_message("INFO", "updateWindows completed successfully")
    end)
  end)
end

local function getWindows()
  log_message("INFO", "getWindows called - executing LIST_WINDOWS query")
  sbar.exec(constants.aerospace.LIST_WINDOWS, updateWindows)
end

frontAppWatcher:subscribe(constants.events.UPDATE_WINDOWS, function()
  log_message("INFO", "UPDATE_WINDOWS event received")
  getWindows()
end)

log_message("INFO", "front_apps.lua initialized - calling getWindows")
getWindows()
