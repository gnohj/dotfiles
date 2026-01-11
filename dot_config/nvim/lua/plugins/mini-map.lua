return {
  "nvim-mini/mini.map",
  version = false,
  lazy = true,

  config = function()
    local map = require("mini.map")

    -- Custom integration for codediff hunks
    local codediff_integration = function()
      local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
      if not ok then
        return {}
      end

      local tabpage = vim.api.nvim_get_current_tabpage()
      local session = lifecycle.get_session(tabpage)
      if not session or not session.stored_diff_result then
        return {}
      end

      local diff_result = session.stored_diff_result
      if not diff_result.changes or #diff_result.changes == 0 then
        return {}
      end

      local buf = vim.api.nvim_get_current_buf()
      local is_original = buf == session.original_bufnr
      local line_hl = {}

      for _, change in ipairs(diff_result.changes) do
        local range = is_original and change.original or change.modified
        if range then
          local start_line = range.start_line or 1
          local end_line = range.end_line or start_line

          -- Determine highlight based on change type
          -- codediff uses line ranges: empty range means add/delete
          -- original empty = addition, modified empty = deletion, both have content = modification
          local hl_group
          local orig_empty = change.original.start_line == change.original.end_line
          local mod_empty = change.modified.start_line == change.modified.end_line

          if orig_empty and not mod_empty then
            -- Addition: nothing in original, something in modified
            hl_group = "MiniMapAdd"
          elseif mod_empty and not orig_empty then
            -- Deletion: something in original, nothing in modified
            hl_group = "MiniMapDelete"
          else
            -- Modification: both have content
            hl_group = "MiniMapChange"
          end

          -- Only highlight if this side has actual lines
          if start_line < end_line then
            for line = start_line, end_line - 1 do
              table.insert(line_hl, { line = line, hl_group = hl_group })
            end
          end
        end
      end

      return line_hl
    end

    -- Set up highlight groups for diff (using gnohj colors)
    vim.api.nvim_set_hl(0, "MiniMapAdd", { fg = "#b7ce97", bold = true }) -- gnohj_color02 green
    vim.api.nvim_set_hl(0, "MiniMapDelete", { fg = "#da858e", bold = true }) -- gnohj_color11 red
    vim.api.nvim_set_hl(0, "MiniMapChange", { fg = "#d4976c", bold = true }) -- orange for modifications

    -- Scroll bar colors (gnohj blue)
    vim.api.nvim_set_hl(0, "MiniMapSymbolLine", { fg = "#7daea3", bold = true }) -- gnohj blue - current line
    vim.api.nvim_set_hl(0, "MiniMapSymbolView", { fg = "#7daea3" }) -- gnohj blue - viewport

    map.setup({
      integrations = {
        codediff_integration,
        map.gen_integration.builtin_search(),
        map.gen_integration.diagnostic({
          error = "DiagnosticFloatingError",
        }),
      },
      symbols = {
        encode = map.gen_encode_symbols.dot("4x2"),
        scroll_line = "▶",
        scroll_view = "┃",
      },
      window = {
        side = "right",
        width = 8,
        winblend = 75, -- 75% transparent so you can see code behind
        show_integration_count = false,
        focusable = false,
      },
    })
  end,

  init = function()
    -- Track if map is open for codediff
    local codediff_map_open = false

    -- Helper to check if we're in a codediff tab
    local function is_codediff_tab()
      local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
      if not ok then
        return false
      end
      local tabpage = vim.api.nvim_get_current_tabpage()
      return lifecycle.get_session(tabpage) ~= nil
    end

    -- Helper to check if we're in a codediff diff window (not explorer)
    local function is_codediff_diff_window()
      local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
      if not ok then
        return false
      end
      local tabpage = vim.api.nvim_get_current_tabpage()
      local session = lifecycle.get_session(tabpage)
      if not session then
        return false
      end

      local win = vim.api.nvim_get_current_win()
      local original_win, modified_win = lifecycle.get_windows(tabpage)
      return win == original_win or win == modified_win
    end

    -- Open mini.map for codediff
    local function open_codediff_map()
      if not codediff_map_open and is_codediff_diff_window() then
        -- Ensure mini.map is loaded
        require("lazy").load({ plugins = { "mini.map" } })
        vim.schedule(function()
          require("mini.map").open()
          codediff_map_open = true
        end)
      end
    end

    -- Close mini.map when leaving codediff
    local function close_codediff_map()
      if codediff_map_open and not is_codediff_tab() then
        pcall(function()
          require("mini.map").close()
        end)
        codediff_map_open = false
      end
    end

    -- Auto-open when entering codediff diff windows
    vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
      callback = function()
        vim.schedule(function()
          if is_codediff_diff_window() then
            open_codediff_map()
          end
        end)
      end,
    })

    -- Auto-close when leaving codediff tab
    vim.api.nvim_create_autocmd("TabLeave", {
      callback = function()
        if codediff_map_open then
          pcall(function()
            require("mini.map").close()
          end)
          codediff_map_open = false
        end
      end,
    })

    -- Also close when codediff tab is closed
    vim.api.nvim_create_autocmd("TabClosed", {
      callback = function()
        vim.schedule(close_codediff_map)
      end,
    })
  end,
}
