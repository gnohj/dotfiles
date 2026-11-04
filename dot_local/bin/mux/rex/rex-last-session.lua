-- ctrl+enter: select the session the app showed before this one, here or on any `rex hosts` entry; showing a session re-requests its terminal sizes, so clicks count too.
local TERM = "com.superlogical.terminal"

local function epoch(ts)
  local y, mo, d, h, mi, s, frac, tz = (ts or ""):match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)(%.?%d*)(.*)$")
  if y == nil then return 0 end
  y, mo = tonumber(y), tonumber(mo)
  if mo <= 2 then y = y - 1 end
  local days = 365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400)
             + math.floor((153 * ((mo + 9) % 12) + 2) / 5) + tonumber(d)
  local offset = 0
  local sign, oh, om = tz:match("([%+%-])(%d+):(%d+)")
  if sign ~= nil then offset = (tonumber(oh) * 3600 + tonumber(om) * 60) * (sign == "-" and -1 or 1) end
  return days * 86400 + h * 3600 + mi * 60 + s + (tonumber("0" .. frac) or 0) - offset
end

local hosts = { { api = rex, label = "" } }
for _, label in ipairs(rex.servers()) do table.insert(hosts, { api = rex.server(label), label = label }) end

-- The pressing app, or the newest app when run from a CLI.
local me
for _, host in ipairs(hosts) do
  local c = host.api.call("client.inspect", { client_id = rex.args.client })
  if c ~= nil and c.client.info.kind == "app" then
    me = c.client.info
    break
  end
end
if me == nil then
  local newest
  for _, c in ipairs((rex.call("client.list") or {}).clients or {}) do
    if c.info ~= nil and c.info.kind == "app" and c.connection_state == "connected" and (newest == nil or c.connected_at > newest.connected_at) then newest = c end
  end
  if newest == nil then error("No Rex app is connected.", 0) end
  me = newest.info
end

-- The app connects to each host as its own client, matched by label; sizes other live clients asked for don't count, earlier connections of this app do.
local function app_client(api)
  local others, mine = {}, nil
  for _, c in ipairs((api.call("client.list") or {}).clients or {}) do
    local info = c.info or {}
    if info.kind == "app" and info.label == me.label and info.name == me.name and c.connection_state == "connected" then
      mine = mine or c.client_id
    else
      others[c.client_id] = true
    end
  end
  return others, mine
end

local function shown_at(api, others, session_id)
  api.call("session.attach", { session_id = session_id })
  local view = api.call("session.view", { session_id = session_id })
  local t = 0
  for _, w in ipairs((view and view.windows) or {}) do
    if w.window_id == view.active_window_id and w.focused_block_id ~= nil then
      local size = api.block.call(TERM, "size", { session_id = session_id, block_id = w.focused_block_id })
      for _, d in ipairs((size and size.desired) or {}) do
        if not others[d.client_id] then t = math.max(t, epoch(d.updated_at)) end
      end
    end
  end
  return t
end

-- The session last left by keyboard (sessions.lua ref) wins: size requests also come from new panes in the background, and Linux hosts record none.
local prev_ref = rex.args.prev or ""
local best, best_t, here, prev = nil, 0, nil, nil
for _, host in ipairs(hosts) do
  local others, first = app_client(host.api)
  local prefix = host.label ~= "" and (host.label:gsub("[^%w]", "-") .. "~") or ""
  if first ~= nil then
    for _, s in ipairs((host.api.call("session.list") or {}).sessions or {}) do
      if s.session_id == rex.args.session then
        here = { api = host.api, client = first }
      else
        local t = shown_at(host.api, others, s.session_id)
        local cand = { api = host.api, client = first, session_id = s.session_id, t = t }
        if prefix .. (s.session_id:gsub("^session:", "")) == prev_ref then prev = cand end
        if t > best_t then best, best_t = cand, t end
      end
    end
  end
end
if prev ~= nil then best = prev end

if best ~= nil then
  local _, err = best.api.call("client.perform", { client_id = best.client, action = "session.select", args = { session_id = best.session_id } })
  if err ~= nil then error(err, 0) end
elseif here ~= nil and here.client ~= nil then
  here.api.call("client.perform", { client_id = here.client, action = "session.previous" })
end
