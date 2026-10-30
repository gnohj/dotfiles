-- Pane actions: close pane-or-tab, last-pane toggle, and ctrl+h/j/k/l navigation that yields to vim/tmux/herdr/ssh.
local c = require("common")
local sessions = require("sessions")

local M = {}

local PASS_THROUGH = { "vim", "tmux", "herdr", "ssh" }

local function owns_ctrl_hjkl(block_id)
  local fg = c.foreground(block_id)
  if fg == nil then return false end
  local name = fg.name or ""
  for _, prog in ipairs(PASS_THROUGH) do
    if name:find(prog, 1, true) then return true end
  end
  return false
end

local AXIS = { left = { 1, -1 }, right = { 1, 1 }, up = { 2, -1 }, down = { 2, 1 } }

local function leaf_rects(node, out)
  if node.block_id ~= nil then
    table.insert(out, { id = node.block_id, rect = node.rect })
  else
    leaf_rects(node.split.before, out)
    leaf_rects(node.split.after, out)
  end
  return out
end

local function contains(r, x, y)
  return x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4]
end

local function covers(box, r)
  return contains(box, r[1] + r[3] / 2, r[2] + r[4] / 2)
end

-- Visible panes as {id, rect}, or nil when nothing floats; a tiled pane under a float is hidden, a minimized float is skipped.
local function pane_rects(window, from)
  local tiled, floats, boxes = {}, {}, {}
  for _, layer in ipairs(window.layers or {}) do
    if layer.kind == "tiled" then
      leaf_rects(layer.layout, tiled)
    elseif not c.is_popup(layer) and layer.state ~= "minimized" then
      leaf_rects(layer.layout, floats)
      table.insert(boxes, layer.bounds)
    end
  end
  if #boxes == 0 then return nil end
  local rects = {}
  for _, p in ipairs(tiled) do
    local hidden = false
    for _, box in ipairs(boxes) do hidden = hidden or covers(box, p.rect) end
    if p.id == from or not hidden then table.insert(rects, p) end
  end
  for _, f in ipairs(floats) do table.insert(rects, f) end
  return rects, tiled, floats
end

-- From a floated pane, the tiled pane under its centre, even a hidden one.
local function underneath(tiled, floats, from)
  for _, f in ipairs(floats) do
    if f.id == from then
      local x, y = f.rect[1] + f.rect[3] / 2, f.rect[2] + f.rect[4] / 2
      for _, p in ipairs(tiled) do
        if contains(p.rect, x, y) then return p.id end
      end
    end
  end
end

-- Rex's focus_direction ignores floats: take the pane just past our edge, else the nearest that way.
local function nearest(rects, from, dir)
  local axis, sign = AXIS[dir][1], AXIS[dir][2]
  local function centre(r) return { r[1] + r[3] / 2, r[2] + r[4] / 2 } end
  local src, srect
  for _, p in ipairs(rects) do
    if p.id == from then src, srect = centre(p.rect), p.rect end
  end
  if src == nil then return nil end
  local probe = { src[1], src[2] }
  probe[axis] = (sign > 0 and srect[axis] + srect[axis + 2] or srect[axis]) + sign * 0.002
  for i = #rects, 1, -1 do
    if rects[i].id ~= from and contains(rects[i].rect, probe[1], probe[2]) then return rects[i].id end
  end
  local best, best_score
  for _, p in ipairs(rects) do
    local r, mid = p.rect, centre(p.rect)
    local near = sign > 0 and r[axis] or r[axis] + r[axis + 2]
    local ahead = (near - src[axis]) * sign
    if p.id ~= from and ahead >= -0.001 then
      local score = ahead + 2 * math.abs(mid[3 - axis] - src[3 - axis])
      if best_score == nil or score < best_score then best, best_score = p.id, score end
    end
  end
  return best
end

local function parent_split(node, block_id)
  if node.split == nil then return nil end
  for _, side in ipairs({ "before", "after" }) do
    if node.split[side].block_id == block_id then return node.split, side == "before" end
  end
  local s, before = parent_split(node.split.before, block_id)
  if s ~= nil then return s, before end
  return parent_split(node.split.after, block_id)
end

local function centre_dist(a, b)
  return math.abs(a[1] + a[3] / 2 - b[1] - b[3] / 2) + math.abs(a[2] + a[4] / 2 - b[2] - b[4] / 2)
end

local FLOAT_STEP = 0.02

-- A floated pane slides its layer one step that way, kept inside the window.
local function nudge_float(ctx, w, dir)
  for _, layer in ipairs(w.layers or {}) do
    if layer.kind ~= "tiled" then
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == ctx.block_id then
          local x, y, width, height = layer.bounds[1], layer.bounds[2], layer.bounds[3], layer.bounds[4]
          local dx = dir == "left" and -FLOAT_STEP or dir == "right" and FLOAT_STEP or 0
          local dy = dir == "up" and -FLOAT_STEP or dir == "down" and FLOAT_STEP or 0
          x = math.max(0, math.min(1 - width, x + dx))
          y = math.max(0, math.min(1 - height, y + dy))
          c.fail(select(2, rex.session.resize_layer{ session_id = ctx.session_id, layer_id = layer.layer_id, bounds = { x, y, width, height } }))
          return true
        end
      end
    end
  end
  return false
end

-- Re-place the pane on one side of its sibling, so a stacked pair goes side by side and back, keeping its share.
local function move_beside(ctx, dir)
  local w = c.tab_of_block(c.windows(), ctx.block_id)
  if w ~= nil and nudge_float(ctx, w, dir) then return end
  local layout = w and c.tiled_layout(w)
  if layout == nil then return end
  local split, was_before = parent_split(layout, ctx.block_id)
  if split == nil then return end
  local sibling = was_before and split.after or split.before
  local self_rect = was_before and split.before.rect or split.after.rect
  local anchor, ratio = sibling.block_id, nil
  if anchor == nil then
    local best
    for _, p in ipairs(leaf_rects(sibling, {})) do
      local d = centre_dist(p.rect, self_rect)
      if best == nil or d < best then anchor, best = p.id, d end
    end
  end
  local side = (dir == "left" or dir == "up") and "before" or "after"
  if sibling.block_id ~= nil then
    local share = was_before and split.ratio or 1 - split.ratio
    ratio = side == "before" and share or 1 - share
  end
  c.fail(select(2, rex.session.move_block{
    session_id = ctx.session_id,
    block_id = ctx.block_id,
    anchor_block_id = anchor,
    direction = (dir == "left" or dir == "right") and "horizontal" or "vertical",
    side = side,
    ratio = ratio,
  }))
end

-- An open popup that focus has left, so ctrl+h/j/k/l from elsewhere returns to it.
local function left_popup(window, from)
  for _, layer in ipairs(window.layers or {}) do
    local b = c.is_popup(layer) and layer.blocks[1]
    if b and b.block_id ~= from then return b.block_id end
  end
end

-- A key handler rather than an action, since only a handler can hand the key back to the pane by returning false.
function M.navigate(dir)
  return function(ctx, ev)
    local window = c.tab_of_block(c.windows(), ctx.block_id)
    local popup = window and left_popup(window, ctx.block_id)
    if popup ~= nil then
      rex.session.focus_block{ session_id = ctx.session_id, block_id = popup }
      return true
    end
    if owns_ctrl_hjkl(ctx.block_id) then return false end
    local rects, tiled, floats
    if window then rects, tiled, floats = pane_rects(window, ctx.block_id) end
    if rects == nil then
      rex.session.focus_direction{ session_id = ctx.session_id, direction = dir }
    else
      local target = nearest(rects, ctx.block_id, dir) or underneath(tiled, floats, ctx.block_id)
      if target ~= nil then rex.session.focus_block{ session_id = ctx.session_id, block_id = target } end
    end
    return true
  end
end

function M.setup()
  -- block.close takes a tab with its last pane (herdr close_pane); an emptied session lingers, so close it and return to the last.
  rex.action{
    name = "close_pane",
    title = "Close Pane or Last-Pane Tab",
    category = "Panes",
    run = function(ctx, args)
      c.fail(select(2, rex.call("block.close", { session_id = ctx.session_id, block_id = ctx.block_id })))
      local windows = c.windows().windows
      if type(windows) ~= "table" or #windows == 0 then sessions.close_session(ctx) end
    end,
  }

  -- One titled action per side, so the move mode's key menu labels each key.
  for dir, title in pairs({ left = "Move Pane to Left", down = "Move Pane Below",
                            up = "Move Pane Above", right = "Move Pane to Right" }) do
    rex.action{
      name = "move_" .. dir,
      title = title,
      category = "Panes",
      repeats = true,
      run = function(ctx) move_beside(ctx, dir) end,
    }
  end

  -- From a floated pane, minimize its layer; from a tiled one, restore the tab's only float or pick among several.
  rex.action{
    name = "float_minimize",
    title = "Minimize or Pick Floating Pane",
    category = "Panes",
    run = function(ctx)
      local window = c.tab_of_block(c.windows(), ctx.block_id)
      if window == nil then return end
      local floats = {}
      for _, layer in ipairs(window.layers or {}) do
        if layer.kind ~= "tiled" and not c.is_popup(layer) then
          for _, b in ipairs(layer.blocks or {}) do
            if b.block_id == ctx.block_id and layer.state ~= "minimized" then
              c.fail(select(2, rex.session.set_layer_state{ session_id = ctx.session_id, layer_id = layer.layer_id, state = "minimized" }))
              return
            end
          end
          table.insert(floats, layer.layer_id)
        end
      end
      if #floats == 1 then
        c.fail(select(2, rex.session.set_layer_state{ session_id = ctx.session_id, layer_id = floats[1], state = "normal", focus = true }))
      elseif #floats > 1 then
        c.popup(ctx, 0.3, 0.3, { c.HOME .. "/.local/bin/mux/rex/rex-float-picker", window.window_id })
      end
    end,
  }

  -- Previous pane in the current tab (herdr hack-herdr-last-pane.sh), tracked per tab on press.
  rex.action{
    name = "last_pane",
    title = "Last Pane Toggle",
    category = "Panes",
    run = function(ctx, args)
      local view = c.windows()
      local key = "last-pane-" .. view.active_window_id:gsub("[^%w]", "_")
      local target = c.read_state(key)
      c.write_state(key, ctx.block_id)
      if target ~= nil and target ~= ctx.block_id then
        local _, err = rex.session.focus_block{ block_id = target }
        if err == nil then return end
      end
      c.fail(select(2, rex.session.focus_previous_pane{}))
    end,
  }
end

return M
