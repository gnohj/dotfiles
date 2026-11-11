-- Prefix tabs with their position (ctrl+N's target) in multi-tab sessions; run as `rex do --all`.
local TERM = "com.superlogical.terminal"
local HOME = os.getenv("HOME")
local STATE = HOME .. "/.local/state/rex-tab-numbers"
local DEFAULT = "^Window %x%x%x%x%x%x%x%x$"
local MAX_LABEL = 128

-- Tabs that follow their live title, by window id: the session, the title, and the label Rex last accepted.
local live = {}
local pending = {}

local function strip(label)
  return (label:gsub("^%d+%. ", ""))
end

local function load_state()
  local f = io.open(STATE)
  if f == nil then return end
  for line in f:lines() do
    local id, sid, base, label = line:match("^([^\t]+)\t(session:[^\t]*)\t([^\t]*)\t(.*)$")
    if id == nil then
      -- Rows from before the session id was stored.
      id, label = line:match("^([^\t]+)\t(.*)$")
      base = label and strip(label)
    end
    if id ~= nil then live[id] = { sid = sid, base = base, label = label } end
  end
  f:close()
end

local function save_state()
  local f = io.open(STATE, "w")
  if f == nil then return end
  for id, row in pairs(live) do
    if row.sid == nil then
      f:write(id, "\t", row.label, "\n")
    else
      f:write(id, "\t", row.sid, "\t", row.base, "\t", row.label, "\n")
    end
  end
  f:close()
end

local function tilde(path)
  if path == HOME then return "~" end
  if path:sub(1, #HOME + 1) == HOME .. "/" then return "~" .. path:sub(#HOME + 1) end
  return path
end

-- Rex trims a label and refuses one with a control character, so the title is cleaned the same way first.
local function clean(title)
  return (title:gsub("\194[\128-\159]", " "):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function truncate(label)
  if #label <= MAX_LABEL then return label end
  local cut = MAX_LABEL
  while cut > 0 and label:byte(cut + 1) >= 0x80 and label:byte(cut + 1) < 0xC0 do cut = cut - 1 end
  return (label:sub(1, cut):gsub("%s+$", ""))
end

-- What Rex shows for an unlabelled tab: the terminal title, else "<program> <cwd>"; nil when neither can be read.
local function live_title(sid, block_id)
  if block_id == nil then return "" end
  local t = rex.block.call(TERM, "title", { session_id = sid, block_id = block_id })
  if t ~= nil and t.title ~= nil and t.title ~= "" then return t.title end
  local p = rex.block.call(TERM, "process", { session_id = sid, block_id = block_id })
  if t == nil and p == nil then return nil end
  local fg = p and (p.foreground or p.child)
  if fg == nil or fg.name == nil then return "" end
  local name = (fg.name:gsub("^%-", ""))
  return fg.cwd and (name .. " " .. tilde(fg.cwd)) or name
end

-- Returns the window ids in the session, or nil when the session could not be read.
local function renumber(sid)
  pending[sid] = nil
  local view = rex.session.view{ session_id = sid }
  if view == nil then return nil end
  local windows = view.windows or {}
  local present, wrote, changed = {}, {}, false
  for i, w in ipairs(windows) do
    present[w.window_id] = true
    local row = live[w.window_id]
    local follows = (row ~= nil and row.label == w.label) or w.label:match(DEFAULT) ~= nil
    local base
    if follows then
      local title = live_title(sid, w.focused_block_id)
      -- An unreadable title keeps the last one, so a failed read never costs the tab its row.
      base = title and clean(title):lower() or (row and row.base or "")
    else
      base = strip(w.label)
      if row ~= nil then
        live[w.window_id] = nil
        changed = true
      end
    end
    local want
    if #windows == 1 then
      want = truncate(base)
    else
      want = truncate(base == "" and tostring(i) or (i .. ". " .. base))
    end
    if want ~= w.label and not (want == "" and w.label:match(DEFAULT)) then
      -- A refused or lost write leaves the row as it was, so the tab still follows on the next event.
      if rex.session.set_window_label{ session_id = sid, window_id = w.window_id, label = want } ~= nil and follows then
        wrote[w.window_id] = { base = base, label = want }
      end
    elseif follows and row ~= nil and (row.sid ~= sid or row.base ~= base) then
      live[w.window_id] = { sid = sid, base = base, label = w.label }
      changed = true
    end
  end
  if next(wrote) ~= nil then
    -- The row holds the label Rex stored, read back, since Rex may normalise what it was sent.
    local after = rex.session.view{ session_id = sid }
    local stored = {}
    for _, w in ipairs((after or {}).windows or {}) do stored[w.window_id] = w.label end
    for id, sent in pairs(wrote) do
      local label = stored[id] or sent.label
      live[id] = label:match(DEFAULT) == nil and { sid = sid, base = sent.base, label = label } or nil
    end
    changed = true
  end
  if changed then save_state() end
  return present
end

local function soon(sid)
  if sid == nil then return end
  if pending[sid] ~= nil then pending[sid]:cancel() end
  pending[sid] = rex.after(0.3, function() renumber(sid) end)
end

load_state()
local healthy = true
local seen = {}
local listed = rex.call("session.list")
if listed == nil then healthy = false end
for _, s in ipairs((listed or {}).sessions or {}) do
  rex.call("session.attach", { session_id = s.session_id })
  local present = renumber(s.session_id)
  if present == nil then
    healthy = false
  else
    -- Only a session that was actually read can prove one of its windows is gone.
    for id, row in pairs(live) do
      if row.sid == s.session_id and not present[id] then live[id] = nil end
    end
    for id in pairs(present) do seen[id] = true end
  end
end
if healthy then
  for id, row in pairs(live) do
    if row.sid == nil and not seen[id] then live[id] = nil end
  end
end
save_state()

for _, event in ipairs({ "session_view_changed", "terminal.title_changed", "terminal.process_changed", "terminal.pwd_changed" }) do
  rex.on(event, function(ctx) soon(ctx.session_id) end)
end

rex.on("window_closed", function(ctx, ev)
  if live[ev.window_id] == nil then return end
  live[ev.window_id] = nil
  save_state()
end)

rex.on("session_destroyed", function(ctx, ev)
  local changed = false
  for id, row in pairs(live) do
    if row.sid == ev.session_id then
      live[id] = nil
      changed = true
    end
  end
  if changed then save_state() end
end)
