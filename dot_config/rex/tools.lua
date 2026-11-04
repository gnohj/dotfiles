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

-- Toggle-closing kills rex-scrollback before it can restore, so the action remembers each popup's pane.
local scrollback_sources = {}

-- Opening a float unzooms the tab, and closing it leaves focus on some other pane.
local function return_to_pane(source, zoomed, copied)
  c.fail(select(2, rex.session.focus_block{ block_id = source }))
  if zoomed then c.fail(select(2, rex.session.zoom_block{ block_id = source, zoom = true })) end
  if not copied then return end
  local window, bounds = c.pane_bounds(c.windows(), source)
  local size = rex.block.call(c.TERM, "size", { block_id = source })
  if bounds == nil or size == nil or size.columns == nil then return end
  local message = "Copied to clipboard"
  local width = math.min(0.9, (#message + 8) / size.columns * bounds[3])
  local height = math.min(0.12, 1.6 / size.rows * bounds[4])
  rex.session.new_layer{
    window_id = window.window_id,
    bounds = { (1 - width) / 2, 1 - height, width, height },
    focus = false,
    layout = rex.layout.block{
      flavor = c.SHELL,
      label = message,
      options = { shell = "none", command = { "sleep", "1.2" }, size = { columns = #message + 8, rows = 1 }, exit = { on_completion = true, quick_exit_threshold_ms = 0 } },
    },
  }
end

function M.setup()
  -- herdr lazygit popup, 90%, on the pane's repo.
  rex.action{
    name = "lazygit",
    title = "Lazygit (floating)",
    category = "Tools",
    run = function(ctx, args)
      local cwd = c.block_cwd(ctx.block_id)
      local repo = rex.exec{ "git", "-C", cwd, "rev-parse", "--git-dir" }
      if repo == nil or not repo.ok then return end
      c.popup(ctx, 0.05, 0.05, { "lazygit" }, { cwd = cwd, label = "lazygit" })
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
        rex.client.queue("session.select", { session_id = ctx.session_id, window_id = created.window_id })
      end
    end,
  }

  -- herdr scrollback-viewer: the pane's scrollback (or its agent transcript) in nvim, over the pane.
  rex.action{
    name = "scrollback_view",
    title = "Scrollback in Nvim",
    category = "Tools",
    run = function(ctx, args)
      local closing = scrollback_sources[ctx.block_id]
      local overlay, zoomed = c.pane_popup(ctx, function(zoomed)
        return { "/bin/sh", "-c", 'exec "$HOME/.local/bin/mux/rex/rex-scrollback" "$0" "$1"', ctx.block_id, zoomed and "zoomed" or "" }
      end)
      if overlay ~= nil then
        scrollback_sources[overlay] = { source = ctx.block_id, zoomed = zoomed }
      elseif closing ~= nil then
        scrollback_sources[ctx.block_id] = nil
        return_to_pane(closing.source, closing.zoomed, false)
      end
    end,
  }

  -- rex-scrollback calls this on exit; skipped once focus has left the popup.
  rex.action{
    name = "scrollback_return",
    title = "Return From Scrollback",
    category = "Tools",
    args = { source = "string", zoomed = "boolean?", copied = "boolean?" },
    run = function(ctx, args)
      scrollback_sources[ctx.block_id] = nil
      local window = c.tab_of_block(c.windows(), args.source)
      if window == nil or window.focused_block_id ~= ctx.block_id then return end
      return_to_pane(args.source, args.zoomed, args.copied)
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

  -- Moves the dev-box package to the Mac app's build, restarting its server when no agent runs.
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
