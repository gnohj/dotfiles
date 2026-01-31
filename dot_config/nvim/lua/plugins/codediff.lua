-- Helper open command in a new tmux window with zen disabled
local function open_in_tmux(cmd, window_name, file)
  local cwd = vim.fn.getcwd()
  local shell_cmd
  if file then
    shell_cmd =
      string.format([[nvim --cmd "let g:zen_disabled=1" "%s" -c "%s"]], file, cmd)
  else
    shell_cmd =
      string.format([[nvim --cmd "let g:zen_disabled=1" -c "%s"]], cmd)
  end
  vim.fn.jobstart(
    { "tmux", "new-window", "-n", window_name, "-c", cwd, shell_cmd },
    { detach = true }
  )
end

return {
  "esmuellert/codediff.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  cmd = "CodeDiff",
  keys = {
    {
      "<leader>gD",
      function()
        -- Get default branch dynamically
        local default_branch = vim.fn.system(
          "git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' | tr -d '\\n'"
        )
        if default_branch == "" then
          default_branch = "main"
        end
        open_in_tmux("CodeDiff origin/" .. default_branch .. " HEAD", "🔀")
      end,
      desc = "Diff against default branch (tmux)",
    },
    {
      "<leader>gc",
      function()
        -- Compare current file against last commit
        local file = vim.fn.expand("%:p")
        if file == "" then
          vim.notify("No file in current buffer", vim.log.levels.ERROR)
          return
        end
        open_in_tmux("CodeDiff file HEAD", "📄", file)
      end,
      desc = "Diff current file against HEAD (tmux)",
    },
    {
      "<leader>gS",
      function()
        -- Compare all staged/unstaged changes against last commit
        open_in_tmux("CodeDiff HEAD", "📋")
      end,
      desc = "Diff all changes against HEAD (tmux)",
    },
  },
  config = function()
    require("codediff").setup({
      diff = {
        -- Lower timeout for faster performance with large files
        -- Skips slow char-level diffs while keeping line-level and fast char-level diffs
        -- See docs/performance.md: 500ms = "very fast, 95% quality"
        max_computation_time_ms = 500,
      },
      explorer = {
        width = 30, -- Sidebar width in columns (default: 40)
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
        history = {
          quit = "<esc>",
        },
      },
    })

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

        local reason = is_heavy and vim.fn.fnamemodify(bufname, ":t")
          or string.format("%d lines", line_count)
        Snacks.notify.warn(
          ("Heavy diff file (%s). Syntax/LSP/treesitter disabled."):format(
            reason
          ),
          { title = "codediff" }
        )
      end
    end

    -- Check if current window is a codediff view window
    local function is_codediff_window(win)
      local tabpage = vim.api.nvim_win_get_tabpage(win)
      local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
      if not ok then
        return false
      end

      local session = lifecycle.get_session(tabpage)
      if not session then
        return false
      end

      local original_win, modified_win = lifecycle.get_windows(tabpage)
      return win == original_win or win == modified_win
    end

    -- Disable conflicting plugins for ALL diff view windows
    local function setup_diff_window(win, buf)
      -- Disable mini.diff and gitsigns on this buffer
      vim.b[buf].minidiff_disable = true
      vim.b[buf].gitsigns_head = nil -- Hint to gitsigns this isn't a normal git buffer

      -- Disable fold-imports by opening all folds in this buffer
      vim.wo[win].foldenable = false

      -- Disable features that slow down scrolling for ALL codediff buffers
      vim.b[buf].minianimate_disable = true
      vim.b[buf].minihipatterns_disable = true
      vim.wo[win].cursorline = false
      vim.wo[win].cursorcolumn = false
      vim.wo[win].spell = false

      -- Apply additional bigfile optimizations for large/heavy files
      apply_bigfile_optimizations(buf, win)
    end

    local function setup_diff_keymaps()
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_win_get_buf(win)
      -- Check if this is a codediff view window
      if is_codediff_window(win) then
        setup_diff_window(win, buf)
      end
    end

    vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
      callback = function()
        -- Defer to ensure plugin has set up the window marker
        vim.schedule(setup_diff_keymaps)
      end,
    })

    -- Quit nvim when codediff tab closes (if in zen-disabled tmux window)
    vim.api.nvim_create_autocmd("TabClosed", {
      callback = function()
        if vim.g.zen_disabled then
          -- Check if any codediff sessions remain
          local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
          if ok then
            -- Small delay to let the tab fully close
            vim.defer_fn(function()
              local has_session = false
              for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
                if lifecycle.get_session(tabpage) then
                  has_session = true
                  break
                end
              end
              if not has_session then
                vim.cmd("qa")
              end
            end, 100)
          end
        end
      end,
    })
  end,
}
