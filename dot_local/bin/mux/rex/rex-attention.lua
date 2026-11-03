-- ctrl+;: cycle panes wanting you on every `rex hosts` entry, blocked first, then unseen error and done, newest first.
local TERM = "com.superlogical.terminal"
local SEEN = os.getenv("HOME") .. "/.local/state/rex-herdr-keys/attention-seen"
local TIER = { blocked = 1, error = 2, done = 3 }

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

-- Rex keeps done/error until replaced, so seen = marked by this script or sized by an app since the record arrived.
local seen = {}
local f = io.open(SEEN)
if f ~= nil then
  for line in f:lines() do
    local key, at = line:match("^(.-)\t(.*)$")
    if key ~= nil then seen[key] = at end
  end
  f:close()
end

local function app_clients(api)
  local ids, first = {}, nil
  for _, c in ipairs((api.call("client.list") or {}).clients or {}) do
    if c.info ~= nil and c.info.kind == "app" and c.connection_state == "connected" then
      ids[c.client_id] = true
      if c.info.platform ~= "ios" and (first == nil or c.connected_at > first.connected_at) then first = c end
    end
  end
  return ids, first and first.client_id
end

local function sized_since(api, apps, session_id, block_id, at)
  local size = api.block.call(TERM, "size", { session_id = session_id, block_id = block_id })
  for _, d in ipairs((size and size.desired) or {}) do
    if apps[d.client_id] and epoch(d.updated_at) >= at then return true end
  end
  return false
end

local here_host, here_block = rex.args.host or "", rex.args.block or ""
local hosts = { { api = rex, label = "" } }
for _, label in ipairs(rex.servers()) do table.insert(hosts, { api = rex.server(label), label = label }) end

local queue, keep, current = {}, {}, nil
for _, host in ipairs(hosts) do
  local apps, client = app_clients(host.api)
  for _, s in ipairs((host.api.call("session.list") or {}).sessions or {}) do
    host.api.call("session.attach", { session_id = s.session_id })
    for _, b in ipairs((host.api.call("session.list_blocks", { session_id = s.session_id }) or {}).blocks or {}) do
      local best
      local st = host.api.block.call(TERM, "program_status", { session_id = s.session_id, block_id = b.block_id })
      for _, r in ipairs((st and st.records) or {}) do
        local tier = TIER[r.state]
        if tier ~= nil and (best == nil or tier < best.tier or (tier == best.tier and r.updated_at > best.updated_at)) then
          best = { tier = tier, updated_at = r.updated_at }
        end
      end
      if best ~= nil then
        local item = { api = host.api, client = client, session_id = s.session_id, block_id = b.block_id,
                       key = host.label .. "|" .. b.block_id, tier = best.tier, at = epoch(best.updated_at), stamp = best.updated_at }
        local is_here = host.label == here_host and b.block_id == here_block
        if item.tier > 1 and seen[item.key] == item.stamp then keep[item.key] = item.stamp end
        if is_here then
          current = item
          if item.tier > 1 then keep[item.key] = item.stamp end
        end
        if item.tier == 1 or is_here or (seen[item.key] ~= item.stamp and not sized_since(host.api, apps, s.session_id, b.block_id, item.at)) then
          table.insert(queue, item)
        end
      end
    end
  end
end

table.sort(queue, function(a, b)
  if a.tier ~= b.tier then return a.tier < b.tier end
  return a.at > b.at
end)
-- The pane you are leaving counts as seen, so a done one drops out instead of keeping its slot in the cycle.
local live = {}
for _, item in ipairs(queue) do
  if item ~= current or item.tier == 1 then table.insert(live, item) end
end

local target
for i, item in ipairs(live) do
  if item == current then target = live[i % #live + 1] end
end
target = target or live[1]

local function save()
  local out = io.open(SEEN, "w")
  if out == nil then return end
  for key, at in pairs(keep) do out:write(key, "\t", at, "\n") end
  out:close()
end

local function notify(title, text)
  local osascript = io.open("/usr/bin/osascript")
  if osascript == nil then return end
  osascript:close()
  rex.exec{ "osascript", "-e", string.format("display notification %q with title %q", text, title) }
end

if target == nil or target == current then
  save()
  if target == nil then notify("No agents need attention", "nothing blocked or unseen right now") else notify("Only agent needing attention", "you're already on it") end
  return
end
if target.tier > 1 then keep[target.key] = target.stamp end
save()

if target.client == nil then error("No Rex app is connected to the host holding " .. target.block_id, 0) end
local _, err = target.api.call("session.focus_block", { session_id = target.session_id, block_id = target.block_id })
if err ~= nil then error(err, 0) end
_, err = target.api.call("client.perform", { client_id = target.client, action = "session.select", args = { session_id = target.session_id } })
if err ~= nil then error(err, 0) end
