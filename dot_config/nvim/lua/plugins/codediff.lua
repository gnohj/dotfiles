return {
  "esmuellert/codediff.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  cmd = "CodeDiff",
  config = function()
    require("codediff").setup({
      diff = {
        -- Lower timeout for faster performance with large files
        -- Skips slow char-level diffs while keeping line-level and fast char-level diffs
        -- See docs/performance.md: 500ms = "very fast, 95% quality"
        max_computation_time_ms = 500,
      },
      explorer = {
        view_mode = "tree", -- "list" (flat) or "tree" (directory tree)
        file_filter = {
          -- Hide heavy/bundle files that are slow to diff
          ignore = {
            "*.min.js",
            "*.min.css",
            "*.bundle.js",
            "*.bundle.css",
            "**/dist/*.js",
            "**/build/*.js",
            "**/node_modules/**",
            "package-lock.json",
            "yarn.lock",
            "pnpm-lock.yaml",
            "**/index.js", -- Bundle outputs
            "**/vendor.js",
            "**/chunk-*.js",
          },
        },
      },
      keymaps = {
        view = {
          quit = "<esc>",
          next_file = "<tab>",
          prev_file = "<s-tab>",
          next_hunk = "]h",
          prev_hunk = "[h",
        },
        explorer = {
          quit = "<esc>",
        },
      },
    })

    -- Helper to scroll diff views from anywhere in the codediff tab
    local function scroll_diff_views(direction)
      local tabpage = vim.api.nvim_get_current_tabpage()
      local lifecycle = require("codediff.ui.lifecycle")
      local original_win, modified_win = lifecycle.get_windows(tabpage)

      if modified_win and vim.api.nvim_win_is_valid(modified_win) then
        local current_win = vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_win(modified_win)
        local key = direction == "down"
            and vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
          or vim.api.nvim_replace_termcodes("<C-u>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
        vim.defer_fn(function()
          if vim.api.nvim_win_is_valid(current_win) then
            vim.api.nvim_set_current_win(current_win)
          end
        end, 10)
      end
    end

    -- Force quit codediff tab (handles modified buffers)
    local function force_quit_codediff()
      local lifecycle = require("codediff.ui.lifecycle")
      local tabpage = vim.api.nvim_get_current_tabpage()
      local session = lifecycle.get_session(tabpage)
      if not session then return end

      -- Mark diff buffers as unmodified so tabclose works
      local original_bufnr, modified_bufnr = lifecycle.get_buffers(tabpage)
      if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
        vim.bo[original_bufnr].modified = false
      end
      if modified_bufnr and vim.api.nvim_buf_is_valid(modified_bufnr) then
        vim.bo[modified_bufnr].modified = false
      end

      -- Now close the tab
      pcall(vim.cmd, "tabclose!")
    end

    -- Set up J/K keymaps for codediff explorer
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "codediff-explorer",
      callback = function(event)
        vim.keymap.set("n", "J", function()
          scroll_diff_views("down")
        end, { buffer = event.buf, desc = "Scroll diff down" })
        vim.keymap.set("n", "K", function()
          scroll_diff_views("up")
        end, { buffer = event.buf, desc = "Scroll diff up" })
        -- Override <esc> to force quit (handles modified buffer issue)
        vim.keymap.set("n", "<esc>", force_quit_codediff, { buffer = event.buf, desc = "Quit codediff" })
      end,
    })

    -- Helper to navigate hunks in codediff
    local function navigate_hunk(direction)
      local lifecycle = require("codediff.ui.lifecycle")
      local tabpage = vim.api.nvim_get_current_tabpage()
      local session = lifecycle.get_session(tabpage)
      if not session or not session.stored_diff_result then return end

      local diff_result = session.stored_diff_result
      if #diff_result.changes == 0 then return end

      local current_buf = vim.api.nvim_get_current_buf()
      local is_original = current_buf == session.original_bufnr
      local cursor = vim.api.nvim_win_get_cursor(0)
      local current_line = cursor[1]

      if direction == "next" then
        for i, mapping in ipairs(diff_result.changes) do
          local target_line = is_original and mapping.original.start_line or mapping.modified.start_line
          if target_line > current_line then
            pcall(vim.api.nvim_win_set_cursor, 0, { target_line, 0 })
            vim.api.nvim_echo({ { string.format("Hunk %d of %d", i, #diff_result.changes), "None" } }, false, {})
            return
          end
        end
        -- Wrap to first
        local first = diff_result.changes[1]
        local target = is_original and first.original.start_line or first.modified.start_line
        pcall(vim.api.nvim_win_set_cursor, 0, { target, 0 })
        vim.api.nvim_echo({ { string.format("Hunk 1 of %d", #diff_result.changes), "None" } }, false, {})
      else
        for i = #diff_result.changes, 1, -1 do
          local mapping = diff_result.changes[i]
          local target_line = is_original and mapping.original.start_line or mapping.modified.start_line
          if target_line < current_line then
            pcall(vim.api.nvim_win_set_cursor, 0, { target_line, 0 })
            vim.api.nvim_echo({ { string.format("Hunk %d of %d", i, #diff_result.changes), "None" } }, false, {})
            return
          end
        end
        -- Wrap to last
        local last = diff_result.changes[#diff_result.changes]
        local target = is_original and last.original.start_line or last.modified.start_line
        pcall(vim.api.nvim_win_set_cursor, 0, { target, 0 })
        vim.api.nvim_echo({ { string.format("Hunk %d of %d", #diff_result.changes, #diff_result.changes), "None" } }, false, {})
      end
    end

    -- Patterns for files that should always have optimizations applied
    local heavy_file_patterns = {
      "index%.js$",
      "index%.mjs$",
      "bundle%.js$",
      "%.min%.js$",
      "%.min%.css$",
      "vendor%.js$",
      "chunk%-.*%.js$",
      "dist/.*%.js$",
      "build/.*%.js$",
      "%.bundle%.",
      "node_modules/",
      "package%-lock%.json$",
      "yarn%.lock$",
      "pnpm%-lock%.yaml$",
    }

    local function is_heavy_file(bufname)
      for _, pattern in ipairs(heavy_file_patterns) do
        if bufname:match(pattern) then
          return true
        end
      end
      return false
    end

    -- Apply bigfile optimizations for large buffers
    local function apply_bigfile_optimizations(buf, win)
      local bufname = vim.api.nvim_buf_get_name(buf)
      local line_count = vim.api.nvim_buf_line_count(buf)
      local size_threshold = 5000 -- lines threshold for bigfile
      local is_heavy = is_heavy_file(bufname)

      if line_count > size_threshold or is_heavy then
        -- Disable expensive features
        vim.bo[buf].swapfile = false
        vim.bo[buf].undolevels = 100
        vim.b[buf].completion = false
        vim.b[buf].minianimate_disable = true
        vim.b[buf].minihipatterns_disable = true

        -- Disable treesitter highlighting for this buffer
        pcall(function()
          vim.treesitter.stop(buf)
        end)

        -- Disable LSP for this buffer
        pcall(function()
          local clients = vim.lsp.get_clients({ bufnr = buf })
          for _, client in ipairs(clients) do
            vim.lsp.buf_detach_client(buf, client.id)
          end
        end)
        vim.b[buf].lsp_disabled = true

        -- Set syntax off for heavy files
        if is_heavy then
          vim.bo[buf].syntax = "off"
        end

        -- Set simpler window options
        vim.wo[win].foldmethod = "manual"
        vim.wo[win].statuscolumn = ""
        vim.wo[win].conceallevel = 0
        vim.wo[win].spell = false
        vim.wo[win].list = false
        vim.wo[win].cursorline = false
        vim.wo[win].cursorcolumn = false
        vim.wo[win].colorcolumn = ""
        vim.wo[win].signcolumn = "no"

        -- Disable matchparen
        if vim.fn.exists(":NoMatchParen") ~= 0 then
          vim.cmd([[NoMatchParen]])
        end

        local reason = is_heavy and vim.fn.fnamemodify(bufname, ":t") or string.format("%d lines", line_count)
        Snacks.notify.warn({
          ("Heavy diff file detected (%s)."):format(reason),
          "Syntax/LSP/treesitter **disabled** for performance.",
        }, { title = "codediff: Big File" })
      end
    end

    -- Check if current window is a codediff view window
    local function is_codediff_window(win)
      local tabpage = vim.api.nvim_win_get_tabpage(win)
      local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
      if not ok then return false end

      local session = lifecycle.get_session(tabpage)
      if not session then return false end

      local original_win, modified_win = lifecycle.get_windows(tabpage)
      return win == original_win or win == modified_win
    end

    -- Set up J/K keymaps and disable conflicting plugins for diff view windows
    local function setup_diff_keymaps()
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_win_get_buf(win)
      -- Check if this is a codediff view window
      if is_codediff_window(win) then
        -- Disable mini.diff and gitsigns on this buffer
        vim.b[buf].minidiff_disable = true
        vim.b[buf].gitsigns_head = nil -- Hint to gitsigns this isn't a normal git buffer

        -- Disable fold-imports by opening all folds in this buffer
        vim.wo[win].foldenable = false

        -- Apply bigfile optimizations if buffer is large or matches heavy file patterns
        apply_bigfile_optimizations(buf, win)

        -- Remove existing gitsigns/mini.diff keymaps and SET our own
        pcall(vim.keymap.del, "n", "]h", { buffer = buf })
        pcall(vim.keymap.del, "n", "[h", { buffer = buf })
        pcall(vim.keymap.del, "n", "]H", { buffer = buf })
        pcall(vim.keymap.del, "n", "[H", { buffer = buf })

        -- Set codediff hunk navigation (overrides any remaining keymaps)
        vim.keymap.set("n", "]h", function()
          navigate_hunk("next")
        end, { buffer = buf, desc = "Next hunk (codediff)" })
        vim.keymap.set("n", "[h", function()
          navigate_hunk("prev")
        end, { buffer = buf, desc = "Prev hunk (codediff)" })

        vim.keymap.set("n", "J", function()
          scroll_diff_views("down")
        end, { buffer = buf, desc = "Scroll diff down" })
        vim.keymap.set("n", "K", function()
          scroll_diff_views("up")
        end, { buffer = buf, desc = "Scroll diff up" })
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
