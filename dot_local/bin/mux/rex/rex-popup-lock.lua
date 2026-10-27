-- Keeps focus on popup BLOCK until it closes; run as `rex do -s SESSION rex-popup-lock.lua block=B client=C`.
local popup = rex.args.block

-- The app that pressed the key, else the newest one; a CLI client has no focus to move.
local function app_client()
  local r = rex.call("client.list", {})
  local latest
  for _, c in ipairs(r and r.clients or {}) do
    local app = c.info and c.info.kind == "app" and c.info.platform ~= "ios" and c.connection_state == "connected"
    if app and c.client_id == rex.args.client then return c.client_id end
    if app and (latest == nil or c.connected_at > latest.connected_at) then latest = c end
  end
  return latest and latest.client_id
end

local client = app_client()

local function window_of(view)
  for _, w in ipairs(view.windows) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == popup then return w end
      end
    end
  end
end

local function block_count(w)
  local n = 0
  for _, layer in ipairs(w.layers or {}) do n = n + #(layer.blocks or {}) end
  return n
end

-- The app overrides the server's focus_block, so only its own actions move keyboard focus.
local function app_do(action, args)
  rex.call("client.perform", { client_id = client, action = action, args = args })
end

local function held(view)
  local w = window_of(view)
  return w ~= nil and view.active_window_id == w.window_id and w.focused_block_id == popup, w
end

local function reclaim(reselect)
  local view = rex.session.view{}
  if view == nil then return end
  local ok, w = held(view)
  if w == nil then return rex.stop() end
  if ok and not reselect then return end
  if client == nil then
    rex.session.focus_block{ block_id = popup }
    return
  end
  if reselect or view.active_window_id ~= w.window_id then
    app_do("session.select", { session_id = rex.session_id, window_id = w.window_id })
  end
  for _ = 1, block_count(w) do
    view = rex.session.view{}
    if view == nil or held(view) then return end
    app_do("pane.focus_next")
  end
end

rex.on("session_view_changed", function()
  reclaim(false)
end)

-- A sidebar session pick never reaches the server, so watch the window title's session half.
local SHOWN_SESSION = [[PATH=/opt/homebrew/bin:$PATH; rift-cli query windows 2>/dev/null | jq -r 'first(.[] | select(.bundle_id == "com.superlogical.rex" and .is_focused) | .title) // empty' 2>/dev/null]]
local home

local function watch_shown_session()
  local r = rex.exec{ "/bin/sh", "-c", SHOWN_SESSION }
  local shown = r and r.stdout:match(".* %- (.-)%s*$")
  if shown == nil then return end
  if home == nil then home = shown end
  if shown ~= home then reclaim(true) end
end

local rift = rex.exec{ "/bin/sh", "-c", "PATH=/opt/homebrew/bin:$PATH; command -v rift-cli" }
if rift and rift.ok then rex.every(0.25, watch_shown_session) end
