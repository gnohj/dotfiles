-- Popups and helpers: lazygit, yazi, scrollback in nvim, pluck, opening a picked file, and the dev-box Rex update.
local c = require("common")

local M = {}

-- Pluck's hint labels are drawn by a twin block in a same-layout scratch tab that swaps into the pane's slot.
local function scratch_layout(node, source, hint)
  if node.block_id ~= nil then
    return rex.layout.block{ flavor = c.SHELL, options = { command = node.block_id == source and hint or { "sleep", "600" } } }
  end
  local split = node.split.direction == "horizontal" and rex.layout.horizontal or rex.layout.vertical
  return split(node.split.ratio, scratch_layout(node.split.before, source, hint), scratch_layout(node.split.after, source, hint))
end

local function block_at(node, rect)
  if node.block_id ~= nil then
    for i = 1, 4 do
      if math.abs(node.rect[i] - rect[i]) > 1e-6 then return nil end
    end
    return node.block_id
  end
  return block_at(node.split.before, rect) or block_at(node.split.after, rect)
end

function M.setup()
  -- herdr lazygit popup, 90%, on the pane's repo.
  rex.action{
    name = "lazygit",
    title = "Lazygit (floating)",
    category = "Tools",
    run = function(ctx, args)
      c.popup(ctx, 0.05, 0.05, { "lazygit" }, c.block_cwd(ctx.block_id))
    end,
  }

  -- herdr yazi-herdr.sh: yazi in a new tab at the pane's cwd; keyboard focus follows only a client session.select.
  rex.action{
    name = "yazi_tab",
    title = "Yazi in New Tab",
    category = "Tools",
    run = function(ctx, args)
      local created, err = rex.session.new_window{
        layout = rex.layout.block{
          flavor = c.SHELL,
          options = { command = { "yazi" }, cwd = c.block_cwd(ctx.block_id) },
        },
      }
      c.fail(err)
      if ctx.client_id ~= nil then
        rex.exec.start({ "/bin/sh", "-c", 'for d in 0.2 0.4; do sleep "$d"; "$0" -C "$1" do session.select session_id="$2" window_id="$3"; done', c.REX_CLI, ctx.client_id, ctx.session_id, created.window_id }, { detach = true })
      end
    end,
  }

  -- herdr scrollback-viewer: the pane's scrollback (or its agent transcript) in nvim.
  rex.action{
    name = "scrollback_view",
    title = "Scrollback in Nvim",
    category = "Tools",
    run = function(ctx, args)
      c.popup(ctx, 0.05, 0.05, { "/bin/sh", "-c", 'exec "$HOME/.local/bin/mux/rex/rex-scrollback" "$0"', ctx.block_id })
    end,
  }

  -- herdr pluck: hint labels over the pane's visible tokens.
  rex.action{
    name = "pluck",
    title = "Pluck Visible Token",
    category = "Tools",
    run = function(ctx, args)
      local window = c.tab_of_block(c.windows(), ctx.block_id)
      local layout = window and c.tiled_layout(window)
      local rect = layout and c.layout_rect(layout, ctx.block_id)
      if rect == nil then return end
      local hint = { "/bin/sh", "-c", 'exec "$HOME/.local/bin/mux/rex/rex-pluck" "$0" "$1"', ctx.block_id, window.window_id }
      local created, err = rex.session.new_window{ layout = scratch_layout(layout, ctx.block_id, hint) }
      c.fail(err)
      for _, w in ipairs(c.windows().windows) do
        if w.window_id == created.window_id then
          local twin = block_at(c.tiled_layout(w), rect)
          c.fail(select(2, rex.session.swap_blocks{ block_id = ctx.block_id, other_block_id = twin }))
          c.fail(select(2, rex.session.focus_block{ block_id = twin }))
        end
      end
    end,
  }

  -- rex-pluck opens a picked file here: nvim in a new tab at its line.
  rex.action{
    name = "open_file_tab",
    title = "Open File in Nvim Tab",
    category = "Tools",
    args = { path = "string", line = "integer?" },
    run = function(ctx, args)
      local created, err = rex.session.new_window{
        layout = rex.layout.block{
          flavor = c.SHELL,
          options = { command = args.line and { "nvim", "+" .. args.line, "--", args.path } or { "nvim", "--", args.path }, cwd = args.path:match("^(.*)/") or c.HOME },
        },
      }
      c.fail(err)
      if ctx.client_id ~= nil then
        rex.client.queue("session.select", { session_id = ctx.session_id, window_id = created.window_id })
      end
    end,
  }

  -- The Mac app updates itself through Install Update; this upgrades the dev-box package beside it.
  rex.action{
    name = "update_devbox_rex",
    title = "Update Rex on Dev Box",
    category = "Rex",
    run = function(ctx, args)
      c.popup(ctx, 0.2, 0.25, { "/bin/sh", "-c", '"$HOME/.local/bin/rex-update"; printf "\\nPress enter to close"; read _' })
    end,
  }
end

return M
