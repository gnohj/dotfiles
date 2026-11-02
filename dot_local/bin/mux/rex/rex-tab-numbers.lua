-- Prefix tabs with their position (ctrl+N's target) in multi-tab sessions; run as `rex do --all`.
local TERM = "com.superlogical.terminal"
local HOME = os.getenv("HOME")
local STATE = HOME .. "/.local/state/rex-tab-numbers"
local DEFAULT = "^Window %x%x%x%x%x%x%x%x$"
local MAX_LABEL = 128

-- Tabs that follow their live title, by window id, with the label last written; anything else is a custom label to keep.
local live = {}
local pending = {}

local function load_state()
  local f = io.open(STATE)
  if f == nil then return end
  for line in f:lines() do
    local id, label = line:match("^([^\t]+)\t(.*)$")
    if id ~= nil then live[id] = label end
  end
  f:close()
end

local function save_state()
  local f = io.open(STATE, "w")
  if f == nil then return end
  for id, label in pairs(live) do f:write(id, "\t", label, "\n") end
  f:close()
end

local function strip(label)
  return (label:gsub("^%d+%. ?", ""))
end

local function tilde(path)
  if path == HOME then return "~" end
  if path:sub(1, #HOME + 1) == HOME .. "/" then return "~" .. path:sub(#HOME + 1) end
  return path
end

local function truncate(label)
  if #label <= MAX_LABEL then return label end
  local cut = MAX_LABEL
  while cut > 0 and label:byte(cut + 1) >= 0x80 and label:byte(cut + 1) < 0xC0 do cut = cut - 1 end
  return label:sub(1, cut)
end

-- What Rex shows for an unlabelled tab: the terminal title, else "<program> <cwd>".
local function live_title(sid, block_id)
  if block_id == nil then return "" end
  local t = rex.block.call(TERM, "title", { session_id = sid, block_id = block_id })
  if t ~= nil and t.title ~= nil and t.title ~= "" then return t.title end
  local p = rex.block.call(TERM, "process", { session_id = sid, block_id = block_id })
  local fg = p and (p.foreground or p.child)
  if fg == nil or fg.name == nil then return "" end
  local name = (fg.name:gsub("^%-", ""))
  return fg.cwd and (name .. " " .. tilde(fg.cwd)) or name
end

local function renumber(sid)
  pending[sid] = nil
  local view = rex.session.view{ session_id = sid }
  if view == nil then return end
  local windows = view.windows or {}
  local changed = false
  for i, w in ipairs(windows) do
    local follows = live[w.window_id] == w.label or w.label:match(DEFAULT) ~= nil
    local base = follows and live_title(sid, w.focused_block_id):lower() or strip(w.label)
    local want
    if #windows == 1 then
      want = truncate(base)
    else
      want = truncate(base == "" and tostring(i) or (i .. ". " .. base))
    end
    local record = (follows and want ~= "") and want or nil
    if live[w.window_id] ~= record then
      live[w.window_id] = record
      changed = true
    end
    if want ~= w.label and not (want == "" and w.label:match(DEFAULT)) then
      rex.session.set_window_label{ session_id = sid, window_id = w.window_id, label = want }
    end
  end
  if changed then save_state() end
end

local function soon(sid)
  if sid == nil then return end
  if pending[sid] ~= nil then pending[sid]:cancel() end
  pending[sid] = rex.after(0.3, function() renumber(sid) end)
end

load_state()
local seen = {}
for _, s in ipairs((rex.call("session.list") or {}).sessions or {}) do
  rex.call("session.attach", { session_id = s.session_id })
  renumber(s.session_id)
  for _, w in ipairs((rex.session.view{ session_id = s.session_id } or {}).windows or {}) do seen[w.window_id] = true end
end
for id in pairs(live) do
  if not seen[id] then live[id] = nil end
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
