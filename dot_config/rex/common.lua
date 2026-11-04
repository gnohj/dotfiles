-- Helpers shared by the config modules: pane/tab lookups, per-host state files, and the floating popup.
local M = {}

M.TERM = "com.superlogical.terminal"
M.SHELL = M.TERM .. ".shell"
M.HOME = os.getenv("HOME")
M.STATE_DIR = M.HOME .. "/.local/state/rex-herdr-keys"

-- The server's own env has neither REX_BIN_DIR nor rex on PATH, so spawned helpers are handed the app's CLI dir.
local function rex_bin_dir()
  local dirs = { "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS", "/usr/bin" }
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
  rex.exec({ "mkdir", "-p", M.STATE_DIR })
  local f = io.open(M.STATE_DIR .. "/" .. name, "w")
  if f == nil then return end
  f:write(value)
  f:close()
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
local WINDOW_PX = [[PATH=/opt/homebrew/bin:$PATH; { rift-cli query workspaces; rift-cli query displays; } 2>/dev/null | jq -rs '(.[0] | [.[].windows[]? | select(.bundle_id == "com.superlogical.rex")] | (map(select(.is_focused)) + .)[0].frame) as $w | (.[1] | map(select($w.origin.x >= .frame.origin.x and $w.origin.x < .frame.origin.x + .frame.size.width and $w.origin.y >= .frame.origin.y and $w.origin.y < .frame.origin.y + .frame.size.height))[0].backing_scale // 2) as $s | "\($w.size.width * $s) \($s)"' 2>/dev/null; defaults read com.superlogical.rex Workspace.sidebarWidth 2>/dev/null]]

-- Sidebar width as a share of the pane area's; 0 when hidden or unknown.
local function sidebar_share(window, block_id)
  local layout = window and M.tiled_layout(window)
  local rect = layout and M.layout_rect(layout, block_id)
  local size = rect and rex.block.call(M.TERM, "size", { block_id = block_id })
  if size == nil or size.cell_width_px == nil then return 0 end
  local r = rex.exec{ "/bin/sh", "-c", WINDOW_PX }
  local window_px, scale, sidebar_pt = (r and r.stdout or ""):match("^(%S+) (%S+)%s+(%S*)")
  window_px, scale, sidebar_pt = tonumber(window_px), tonumber(scale), tonumber(sidebar_pt)
  if window_px == nil then return 0 end
  -- A pane's measure counts padding too, so it only decides whether the sidebar shows.
  local panes_px = size.columns * size.cell_width_px / rect[3]
  if (window_px - panes_px) / panes_px < 0.05 then return 0 end
  local sidebar_px = sidebar_pt and sidebar_pt * scale or window_px - panes_px
  return sidebar_px / (window_px - sidebar_px)
end

-- Toggle popup in one floating layer that Rex frames and closes on exit; bounds are {x,y,w,h}.
M.POPUP_LABEL = "popup"
-- A new layer is 80x24 until Rex sizes it; wait, or the first frame is drawn too narrow.
local RUN_SIZED = [["$HOME/.local/bin/mux/rex/rex-wait-size"; exec "$@"]]

-- Only popups toggle closed; a pane floated with pane.float is left alone.
function M.is_popup(layer)
  local b = layer.kind ~= "tiled" and layer.blocks and layer.blocks[1]
  return b and b.label == M.POPUP_LABEL
end

local function close_popups(view)
  local open = false
  for _, w in ipairs(view.windows) do
    if w.window_id == view.active_window_id then
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

local function sized(command)
  local argv = { "/bin/sh", "-c", RUN_SIZED, "sh" }
  for _, a in ipairs(command) do table.insert(argv, a) end
  return argv
end

function M.popup(ctx, side, top, command, cwd, self_sized)
  local view = M.windows()
  if close_popups(view) then return end
  -- Centred on the whole window, as far as the box fits beside the sidebar.
  local left = math.max(0.01, side - sidebar_share(M.tab_of_block(view, ctx.block_id), ctx.block_id) / 2)
  M.fail(select(2, rex.session.new_layer{
    bounds = { left, top, 1 - 2 * side, 1 - 2 * top },
    focus = true,
    layout = rex.layout.block{ flavor = M.SHELL, label = M.POPUP_LABEL, options = { command = self_sized and command or sized(command), cwd = cwd } },
  }))
end

function M.pane_bounds(view, block_id)
  local window = M.tab_of_block(view, block_id)
  if window == nil then return nil end
  if window.zoomed_block_id == block_id then return window, { 0, 0, 1, 1 }, true end
  for _, layer in ipairs(window.layers or {}) do
    local rect = layer.layout ~= nil and M.layout_rect(layer.layout, block_id)
    if rect then
      local x, y = math.max(0, rect[1]), math.max(0, rect[2])
      return window, { x, y, math.min(rect[3], 1 - x), math.min(rect[4], 1 - y) }, false
    end
  end
end

function M.pane_popup(ctx, command)
  local view = M.windows()
  if close_popups(view) then return nil end
  local window, bounds, zoomed = M.pane_bounds(view, ctx.block_id)
  if window == nil then error("Pane not found in the session layout", 0) end
  local created, err = rex.session.new_layer{
    window_id = window.window_id,
    bounds = bounds,
    focus = true,
    layout = rex.layout.block{ flavor = M.SHELL, label = M.POPUP_LABEL, options = { command = sized(command(zoomed)) } },
  }
  M.fail(err)
  return created.block_ids[1], zoomed
end

return M
