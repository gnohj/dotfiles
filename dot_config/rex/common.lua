-- Helpers shared by the config modules: pane/tab lookups, per-host state files, and the floating popup.
local M = {}

M.TERM = "com.superlogical.terminal"
M.SHELL = M.TERM .. ".shell"
M.HOME = os.getenv("HOME")
M.STATE_DIR = M.HOME .. "/.local/state/rex-keys"

-- The server's own env has neither REX_BIN_DIR nor rex on PATH, so spawned helpers are handed the CLI dir.
local function rex_bin_dir()
  local dirs = { M.HOME .. "/.local/bin", "/usr/bin" }
  if os.getenv("REX_BIN_DIR") ~= nil then table.insert(dirs, 1, os.getenv("REX_BIN_DIR")) end
  for _, dir in ipairs(dirs) do
    local f = io.open(dir .. "/rex")
    if f ~= nil then
      f:close()
      return dir
    end
  end
end
M.REX_ENV = { REX_BIN_DIR = rex_bin_dir() }

function M.fail(err)
  if err ~= nil then error(err, 0) end
end

function M.read_state(name)
  local f = io.open(M.STATE_DIR .. "/" .. name)
  if f == nil then return nil end
  local v = f:read("*l")
  f:close()
  return v
end

function M.write_state(name, value)
  local f = io.open(M.STATE_DIR .. "/" .. name, "w")
  if f == nil then
    rex.exec({ "mkdir", "-p", M.STATE_DIR })
    f = io.open(M.STATE_DIR .. "/" .. name, "w")
  end
  if f == nil then return end
  f:write(value)
  f:close()
end

-- A key in another server's pane runs this server's action, so hand it to that server's own copy.
function M.forward(ctx, action)
  if type(ctx.server) ~= "string" then return false end
  M.fail(select(2, rex.exec.start({ "/bin/zsh", "-lc", 'exec "${REX_BIN_DIR:+$REX_BIN_DIR/}rex" --autostart=false -S "$0" do -s "$1" -b "$2" "$3"',
                                    ctx.server, ctx.session_id or "", ctx.block_id or "", action }, { detach = true, env = M.REX_ENV })))
  return true
end

function M.foreground(block_id)
  local p = rex.block.call(M.TERM, "process", { block_id = block_id })
  if p == nil then return nil end
  return p.foreground or p.child
end

function M.block_cwd(block_id)
  local fg = M.foreground(block_id)
  if fg ~= nil and fg.cwd ~= nil then return fg.cwd end
  local r = rex.block.call(M.TERM, "pwd", { block_id = block_id })
  if r ~= nil and r.pwd ~= nil then
    return (r.pwd:gsub("^file://[^/]*", ""))
  end
  return os.getenv("HOME")
end

function M.windows()
  local view, err = rex.session.view{}
  M.fail(err)
  return view
end

-- The app's shown tab is not the server's active_window_id, so locate the tab holding the pressed-in pane.
function M.tab_of_block(view, block_id)
  for _, w in ipairs(view.windows) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == block_id then return w end
      end
    end
  end
end

function M.tiled_layout(window)
  for _, layer in ipairs(window.layers or {}) do
    if layer.kind == "tiled" then return layer.layout end
  end
end

function M.layout_rect(node, block_id)
  if node.block_id ~= nil then return node.block_id == block_id and node.rect or nil end
  if node.split == nil then return nil end
  return M.layout_rect(node.split.before, block_id) or M.layout_rect(node.split.after, block_id)
end

-- Rex window width in px and its display scale (rift), then the sidebar width in points; Mac only.
local WINDOW_PX = [[PATH=/opt/homebrew/bin:$PATH; { rift-cli query workspaces; rift-cli query displays; } 2>/dev/null | jq -rs '(.[0] | [.[].windows[]? | select(.bundle_id == "com.superlogical.rex")] | (map(select(.is_focused)) + .)[0].frame) as $w | (.[1] | map(select($w.origin.x >= .frame.origin.x and $w.origin.x < .frame.origin.x + .frame.size.width and $w.origin.y >= .frame.origin.y and $w.origin.y < .frame.origin.y + .frame.size.height))[0].backing_scale // 2) as $s | "\($w.size.width * $s)"' 2>/dev/null]]

local function measure(window, block_id)
  local layout = window and M.tiled_layout(window)
  local rect = layout and M.layout_rect(layout, block_id)
  if rect and window.zoomed_block_id == block_id then rect = { 0, 0, 1, 1 } end
  local size = rect and rex.block.call(M.TERM, "size", { block_id = block_id })
  if size == nil or size.columns == nil then return nil end
  return rect, size
end

-- A new layer is 80x24 until the app sizes it, so its program starts at the size the bounds come to: every pane spends 2 columns and 3 rows on padding and its header.
local function layer_size(rect, size, w, h)
  if rect == nil or size == nil then return nil end
  return {
    columns = math.max(1, math.floor((size.columns + 2) / rect[3] * w) - 2),
    rows = math.max(1, math.floor((size.rows + 3) / rect[4] * h) - 3),
  }
end

-- Sidebar width as a share of the pane area's; 0 when hidden or unknown.
local function sidebar_share(rect, size)
  if rect == nil or size == nil or size.cell_width_px == nil then return 0 end
  local r = rex.exec{ "/bin/sh", "-c", WINDOW_PX }
  local window_px = tonumber(((r and r.stdout or ""):match("^(%S+)")) or "")
  if window_px == nil then return 0 end
  -- Workspace.sidebarWidth belongs to another window, so the sidebar is the width the panes leave.
  local panes_px = size.columns * size.cell_width_px / rect[3]
  if (window_px - panes_px) / panes_px < 0.05 then return 0 end
  local sidebar_px = window_px - panes_px
  return sidebar_px / (window_px - sidebar_px)
end

-- Toggle popup in one floating layer that Rex frames and closes on exit; bounds are {x,y,w,h}.
M.POPUP_LABEL = "popup"
M.POPUP_LABELS = { [M.POPUP_LABEL] = true, lazygit = true, sessions = true, ["fm-chat"] = true }

-- Only popups toggle closed; a pane floated with pane.float is left alone.
function M.is_popup(layer)
  local b = layer.kind ~= "tiled" and layer.blocks and layer.blocks[1]
  return b and M.POPUP_LABELS[b.label] == true
end

local function close_popups(view, window)
  local open, tab = false, window and window.window_id or view.active_window_id
  for _, w in ipairs(view.windows) do
    if w.window_id == tab then
      for _, layer in ipairs(w.layers or {}) do
        if M.is_popup(layer) then
          open = true
          rex.session.close_layer{ layer_id = layer.layer_id }
        end
      end
    end
  end
  return open
end

local function popup_key(window)
  local id = window.window_id:gsub("[^%w]", "_")
  return "popup-source-" .. id
end

-- Closing a popup leaves focus on whichever pane Rex picks, so the pane it opened from is remembered per tab.
function M.restore_popup_source(window)
  local source = window ~= nil and M.read_state(popup_key(window))
  if source then rex.session.focus_block{ block_id = source } end
end

function M.popup(ctx, side, top, command, opts)
  opts = opts or {}
  local view = M.windows()
  local window = M.tab_of_block(view, ctx.block_id)
  if close_popups(view, window) then
    M.restore_popup_source(window)
    return
  end
  if window ~= nil then M.write_state(popup_key(window), ctx.block_id) end
  -- Centred on the whole window, as far as the box fits beside the sidebar.
  local rect, size = measure(window, ctx.block_id)
  local left = math.max(0.01, side - sidebar_share(rect, size) / 2)
  local w, h = 1 - 2 * side, 1 - 2 * top
  M.fail(select(2, rex.session.new_layer{
    window_id = window and window.window_id,
    bounds = { left, top, w, h },
    focus = true,
    layout = rex.layout.block{ flavor = M.SHELL, label = opts.label or M.POPUP_LABEL, options = { command = command, cwd = opts.cwd, size = layer_size(rect, size, w, h) } },
  }))
end

-- Rex drops a select sent before the app knows the tab; unfocused, a miss leaves the server on the shown tab.
function M.new_tab(ctx, layout)
  local created, err = rex.session.new_window{ focus = ctx.client_id == nil, layout = layout }
  M.fail(err)
  if ctx.client_id ~= nil then
    rex.exec{ "sleep", "0.05" }
    rex.client.queue("session.select", { session_id = ctx.session_id, window_id = created.window_id })
  end
  return created
end

function M.pane_bounds(view, block_id)
  local window = M.tab_of_block(view, block_id)
  if window == nil then return nil end
  if window.zoomed_block_id == block_id then return window, { 0, 0, 1, 1 } end
  for _, layer in ipairs(window.layers or {}) do
    local rect = layer.layout ~= nil and M.layout_rect(layer.layout, block_id)
    if rect then
      local x, y = math.max(0, rect[1]), math.max(0, rect[2])
      return window, { x, y, math.min(rect[3], 1 - x), math.min(rect[4], 1 - y) }
    end
  end
end

function M.pane_popup(ctx, command)
  local view = M.windows()
  if close_popups(view, M.tab_of_block(view, ctx.block_id)) then return nil end
  local window, bounds = M.pane_bounds(view, ctx.block_id)
  if window == nil or bounds == nil then error("Pane not found in the session layout", 0) end
  local rect, size = measure(window, ctx.block_id)
  local created, err = rex.session.new_layer{
    window_id = window.window_id,
    bounds = bounds,
    focus = true,
    layout = rex.layout.block{ flavor = M.SHELL, label = M.POPUP_LABEL, options = { command = command, size = layer_size(rect, size, bounds[3], bounds[4]) } },
  }
  M.fail(err)
  return created.block_ids[1]
end

return M
