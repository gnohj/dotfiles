return {
  "esmuellert/vscode-diff.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  cmd = { "CodeDiff" },
  config = function()
    require("vscode-diff").setup({
      keymaps = {
        view = {
          quit = "<esc>",
          next_file = "<tab>",
          prev_file = "<s-tab>",
          next_hunk = "]h",
          prev_hunk = "[h",
        },
      },
    })

    -- Helper to scroll diff views from anywhere in the vscode-diff tab
    local function scroll_diff_views(direction)
      local tabpage = vim.api.nvim_get_current_tabpage()
      local lifecycle = require("vscode-diff.render.lifecycle")
      local original_win, modified_win = lifecycle.get_windows(tabpage)

      if modified_win and vim.api.nvim_win_is_valid(modified_win) then
        local current_win = vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_win(modified_win)
        local key = direction == "down" and vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
          or vim.api.nvim_replace_termcodes("<C-u>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
        vim.defer_fn(function()
          if vim.api.nvim_win_is_valid(current_win) then
            vim.api.nvim_set_current_win(current_win)
          end
        end, 10)
      end
    end

    -- Set up J/K keymaps for vscode-diff explorer
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "vscode-diff-explorer",
      callback = function(event)
        vim.keymap.set("n", "J", function() scroll_diff_views("down") end, { buffer = event.buf, desc = "Scroll diff down" })
        vim.keymap.set("n", "K", function() scroll_diff_views("up") end, { buffer = event.buf, desc = "Scroll diff up" })
      end,
    })

    -- Set up J/K keymaps and disable conflicting plugins for diff view windows
    local function setup_diff_keymaps()
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_win_get_buf(win)
      -- Check for vscode-diff window marker (set by the plugin on diff windows)
      if vim.w[win].vscode_diff_restore then
        -- Disable mini.diff on this buffer to prevent ]h/[h conflicts
        vim.b[buf].minidiff_disable = true
        -- Remove existing mini.diff keymaps if they were already set
        pcall(vim.keymap.del, "n", "]h", { buffer = buf })
        pcall(vim.keymap.del, "n", "[h", { buffer = buf })
        pcall(vim.keymap.del, "n", "]H", { buffer = buf })
        pcall(vim.keymap.del, "n", "[H", { buffer = buf })

        vim.keymap.set("n", "J", function() scroll_diff_views("down") end, { buffer = buf, desc = "Scroll diff down" })
        vim.keymap.set("n", "K", function() scroll_diff_views("up") end, { buffer = buf, desc = "Scroll diff up" })
      end
    end

    vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
      callback = function()
        -- Defer to ensure plugin has set up the window marker
        vim.schedule(setup_diff_keymaps)
      end,
    })
  end,
}
