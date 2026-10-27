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

-- A key handler rather than an action, since only a handler can hand the key back to the pane by returning false.
function M.navigate(dir)
  return function(ctx, ev)
    if owns_ctrl_hjkl(ctx.block_id) then return false end
    rex.session.focus_direction{ session_id = ctx.session_id, direction = dir }
    return true
  end
end

function M.setup()
  -- Rex disables pane.close on a tab's last pane, so close the tab instead (herdr close_pane), or the session from its very last pane.
  rex.action{
    name = "close_pane",
    title = "Close Pane or Last-Pane Tab",
    category = "Panes",
    run = function(ctx, args)
      local view = c.windows()
      local w = c.tab_of_block(view, ctx.block_id)
      if w == nil then return end
      local panes = 0
      for _, layer in ipairs(w.layers or {}) do
        if layer.kind == "tiled" then panes = panes + #(layer.blocks or {}) end
      end
      if panes > 1 then
        rex.client.queue("pane.close")
      elseif #view.windows > 1 then
        rex.client.queue("client.tab.close")
      else
        sessions.close_session(ctx)
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
