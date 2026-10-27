-- Tab actions: next/previous, go to N, last-tab toggle, close all but the first.
local c = require("common")

local M = {}

-- Keyboard tab switches record the tab they leave, for ctrl+space (rex.on is script-only).
local function last_tab_key(ctx)
  return "last-tab-" .. ctx.session_id:gsub("[^%w]", "_")
end

local function current_tab(ctx, view)
  local w = c.tab_of_block(view, ctx.block_id)
  return w and w.window_id or view.active_window_id
end

local function switch_tab(ctx, view, window_id)
  local current = current_tab(ctx, view)
  if window_id == nil or window_id == current then return end
  c.write_state(last_tab_key(ctx), current)
  if ctx.client_id ~= nil then
    rex.client.queue("session.select", { session_id = ctx.session_id, window_id = window_id })
    return
  end
  c.fail(select(2, rex.session.focus_window{ window_id = window_id }))
end

local function neighbour_tab(ctx, view, step)
  local current = current_tab(ctx, view)
  for i, w in ipairs(view.windows) do
    if w.window_id == current then
      local n = view.windows[(i - 1 + step) % #view.windows + 1]
      return n and n.window_id
    end
  end
end

function M.setup()
  rex.action{
    name = "next_tab",
    title = "Next Tab",
    category = "Tabs",
    run = function(ctx, args)
      local view = c.windows()
      switch_tab(ctx, view, neighbour_tab(ctx, view, 1))
    end,
  }

  rex.action{
    name = "previous_tab",
    title = "Previous Tab",
    category = "Tabs",
    run = function(ctx, args)
      local view = c.windows()
      switch_tab(ctx, view, neighbour_tab(ctx, view, -1))
    end,
  }

  rex.action{
    name = "goto_tab",
    title = "Go to Tab N (1-based)",
    category = "Tabs",
    args = { index = "integer" },
    run = function(ctx, args)
      local view = c.windows()
      local w = view.windows[args.index]
      if w == nil then return end
      switch_tab(ctx, view, w.window_id)
    end,
  }

  -- Bounce to the tab last left by a keyboard switch (herdr hack-herdr-last-tab.sh).
  rex.action{
    name = "last_tab",
    title = "Last Tab Toggle",
    category = "Tabs",
    run = function(ctx, args)
      local view = c.windows()
      local target = c.read_state(last_tab_key(ctx))
      for _, w in ipairs(view.windows) do
        if w.window_id == target and target ~= current_tab(ctx, view) then
          switch_tab(ctx, view, target)
          return
        end
      end
      switch_tab(ctx, view, neighbour_tab(ctx, view, -1))
    end,
  }

  -- herdr hack-herdr-close-other-tabs.sh.
  rex.action{
    name = "close_other_tabs",
    title = "Close All Tabs but the First",
    category = "Tabs",
    run = function(ctx, args)
      for i, w in ipairs(c.windows().windows) do
        if i > 1 then
          c.fail(select(2, rex.session.close_window{ window_id = w.window_id }))
        end
      end
    end,
  }
end

return M
