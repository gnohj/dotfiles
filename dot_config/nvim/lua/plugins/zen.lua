-- Forward declaration for restore function (defined later)
local restore_win_separator

-- Helper to close zen padding windows
local function close_zen_padding()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      if ft == "zen-left" or ft == "zen-right" then
        pcall(vim.api.nvim_win_close, win, true)
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end
  end
  -- Restore normal window separators
  if restore_win_separator then
    restore_win_separator()
  end
end

-- Helper to check if dashboard is visible
local function is_dashboard_visible()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft == "snacks_dashboard" then
      return true
    end
  end
  return false
end

-- Helper to check if we're in a codediff tab
local function is_codediff_tab()
  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if ok then
    local tabpage = vim.api.nvim_get_current_tabpage()
    if lifecycle.get_session(tabpage) then
      return true
    end
  end
  return false
end

-- Helper to check if zen windows already exist
local function is_zen_active()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft == "zen-left" or ft == "zen-right" then
      return true
    end
  end
  return false
end

-- Filetypes that are zen padding or integrations (should not count as "normal" windows)
local zen_and_integration_filetypes = {
  -- Zen padding
  "zen-left",
  "zen-right",
  -- Right integrations
  "copilot-chat",
  "neotest-summary",
  "aerial",
  "dapui_watches",
  "dapui_scopes",
  "dapui_stacks",
  "dapui_breakpoints",
  -- Left integrations
  "fugitiveblame",
  "fyler",
  "neo-tree",
  "dbui",
  "undotree",
  "diff",
  -- Top integrations
  "man",
  "help",
  "fugitive",
  -- Bottom integrations
  "dap-repl",
  "qf",
  "trouble",
}

-- Helper to check if filetype is zen or integration
local function is_zen_or_integration(ft)
  for _, v in ipairs(zen_and_integration_filetypes) do
    if ft == v then
      return true
    end
  end
  return false
end

-- Helper to check if a window looks like a side panel (zen or integration)
-- Used when filetype might not be set yet (timing issues)
local function is_side_panel_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype

  -- If filetype is known, use that
  if is_zen_or_integration(ft) then
    return true
  end

  -- Fallback for windows with empty filetype (still loading)
  -- Check if it looks like a side panel: nofile buffer, fixed width, at edge
  if ft == "" then
    local buftype = vim.bo[buf].buftype
    local winfixwidth = vim.wo[win].winfixwidth
    if buftype == "nofile" and winfixwidth then
      -- Check if at left or right edge
      local win_col = vim.api.nvim_win_get_position(win)[2]
      local win_width = vim.api.nvim_win_get_width(win)
      local total_cols = vim.o.columns
      if win_col == 0 or (win_col + win_width >= total_cols - 1) then
        return true
      end
    end
  end

  return false
end

-- Store main_width for toggle (set during config)
local zen_main_width = 148

-- Store original highlights/settings to restore later
local original_win_separator = nil
local original_fillchars = nil

-- Helper to apply transparent/invisible styling to a zen window
local function style_zen_window(win)
  -- Get the Normal highlight to match exact background
  local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
  local bg = normal_hl.bg

  -- Create a window-specific highlight that matches Normal exactly
  if bg then
    vim.api.nvim_set_hl(0, "ZenBg", { bg = bg, fg = bg })
  else
    vim.api.nvim_set_hl(0, "ZenBg", { bg = "NONE", fg = "NONE" })
  end

  -- Save original settings once
  if original_win_separator == nil then
    original_win_separator = vim.api.nvim_get_hl(0, { name = "WinSeparator" })
  end
  if original_fillchars == nil then
    original_fillchars = vim.o.fillchars
  end

  -- IMPORTANT: Use space character for separators GLOBALLY
  -- This is the most reliable way to hide separators
  local current_fillchars = vim.o.fillchars
  local needs_update = false

  -- Hide vertical separator
  if not current_fillchars:match("vert: ") then
    if current_fillchars:match("vert:[^,]*") then
      current_fillchars = current_fillchars:gsub("vert:[^,]*", "vert: ")
    else
      current_fillchars = current_fillchars .. ",vert: "
    end
    needs_update = true
  end

  -- Hide horizontal separator
  if not current_fillchars:match("horiz: ") then
    if current_fillchars:match("horiz:[^,]*") then
      current_fillchars = current_fillchars:gsub("horiz:[^,]*", "horiz: ")
    else
      current_fillchars = current_fillchars .. ",horiz: "
    end
    needs_update = true
  end

  if needs_update then
    vim.o.fillchars = current_fillchars
  end

  -- Also make WinSeparator background transparent
  if bg then
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = bg, bg = bg })
  else
    -- For transparent, use a very dark color that blends
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#000000", bg = "NONE" })
  end

  -- Set window-local highlight namespace
  vim.wo[win].winhighlight = table.concat({
    "Normal:ZenBg",
    "NormalNC:ZenBg",
    "EndOfBuffer:ZenBg",
    "WinSeparator:ZenBg",
    "VertSplit:ZenBg",
    "StatusLine:ZenBg",
    "StatusLineNC:ZenBg",
    "SignColumn:ZenBg",
    "CursorLine:ZenBg",
    "CursorLineNr:ZenBg",
    "LineNr:ZenBg",
  }, ",")
  vim.wo[win].fillchars = "eob: ,vert: ,horiz: " -- Hide end-of-buffer and separators
  vim.wo[win].statusline = " " -- Empty status line
  vim.wo[win].signcolumn = "no"
end

-- Restore original WinSeparator and fillchars when zen is not active
restore_win_separator = function()
  if original_win_separator then
    vim.api.nvim_set_hl(0, "WinSeparator", original_win_separator)
  end
  if original_fillchars then
    vim.o.fillchars = original_fillchars
  end
end

-- Helper to check if a window is a zen padding window
local function is_zen_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  -- Only check by filetype - zen.nvim sets filetype immediately when creating windows
  -- No fallback needed (fallback was incorrectly matching neotest-summary during loading)
  return ft == "zen-left" or ft == "zen-right"
end

-- Helper to style ALL zen windows (left and right)
local function style_all_zen_windows()
  local found_zen = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if is_zen_window(win) then
      style_zen_window(win)
      found_zen = true
    end
  end
  -- If no zen windows, restore original WinSeparator
  if not found_zen then
    restore_win_separator()
  end
end

-- Helper to create zen padding windows (mimics zen.nvim's create_window)
local function create_zen_windows(main_width)
  local current_win = vim.api.nvim_get_current_win()
  local padding_width = math.floor((vim.o.columns - main_width) / 2)

  -- Create left padding window
  vim.cmd("topleft vnew")
  local left_win = vim.api.nvim_get_current_win()
  local left_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_width(left_win, padding_width)
  vim.wo[left_win].winfixwidth = true
  vim.wo[left_win].winfixbuf = true
  vim.wo[left_win].cursorline = false
  vim.wo[left_win].number = false
  vim.wo[left_win].relativenumber = false
  vim.bo[left_buf].filetype = "zen-left"
  vim.bo[left_buf].buftype = "nofile"
  vim.bo[left_buf].buflisted = false
  style_zen_window(left_win)

  -- Create right padding window
  vim.cmd("botright vnew")
  local right_win = vim.api.nvim_get_current_win()
  local right_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_width(right_win, padding_width)
  vim.wo[right_win].winfixwidth = true
  vim.wo[right_win].winfixbuf = true
  vim.wo[right_win].cursorline = false
  vim.wo[right_win].number = false
  vim.wo[right_win].relativenumber = false
  vim.bo[right_buf].filetype = "zen-right"
  vim.bo[right_buf].buftype = "nofile"
  vim.bo[right_buf].buflisted = false
  style_zen_window(right_win)

  -- Return focus to original window
  vim.api.nvim_set_current_win(current_win)
end

return {
  "sand4rt/zen.nvim",
  -- Don't load zen.nvim if vim.g.zen_disabled is set (e.g., nvim --cmd "let g:zen_disabled=1")
  -- This allows diffview/codediff/octo to open in tmux windows without zen
  cond = function()
    return not vim.g.zen_disabled
  end,
  event = { "BufReadPost", "BufNewFile" },
  keys = {
    {
      "<leader>uz",
      function()
        if is_zen_active() then
          close_zen_padding()
        else
          -- Only create if window is wide enough
          if vim.o.columns > zen_main_width then
            create_zen_windows(zen_main_width)
          end
        end
      end,
      desc = "Toggle Zen Mode",
    },
  },
  config = function(_, opts)
    -- Store width for toggle keymap
    zen_main_width = opts.main.width or 148
    require("zen").setup(opts)

    local group = vim.api.nvim_create_augroup("ZenNvimFixes", { clear = true })

    -- PATCH 0: Style ALL zen windows aggressively
    -- Run styling a few times at startup, then rely on events
    for _, delay in ipairs({ 50, 100, 200, 500, 1000 }) do
      vim.defer_fn(style_all_zen_windows, delay)
    end

    -- Style on common events
    vim.api.nvim_create_autocmd({
      "FileType",
      "BufWinEnter",
      "WinEnter",
      "WinNew",
      "WinClosed",
      "BufEnter",
    }, {
      group = group,
      callback = function()
        -- Skip if in codediff tab to avoid errors when codediff windows close
        if is_codediff_tab() then
          return
        end
        vim.schedule(style_all_zen_windows)
      end,
      desc = "Make zen padding windows transparent",
    })

    -- PATCH 1: Close zen padding when dashboard is shown
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "snacks_dashboard",
      callback = function()
        vim.schedule(close_zen_padding)
      end,
      desc = "Hide zen padding when dashboard is visible",
    })

    -- PATCH 1.1: Close zen padding when codediff opens
    vim.api.nvim_create_autocmd({ "FileType", "TabEnter" }, {
      group = group,
      callback = function(ev)
        if ev.event == "FileType" and ev.match == "codediff-explorer" then
          vim.schedule(close_zen_padding)
        elseif ev.event == "TabEnter" and is_codediff_tab() then
          vim.schedule(close_zen_padding)
        end
      end,
      desc = "Hide zen padding when codediff is visible",
    })

    -- PATCH 1.5: Close zen-right/left when integrations open
    -- Uses both FileType (first open) and BufWinEnter (subsequent opens when buffer is reused)
    local function close_zen_right_if_exists()
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "zen-right" then
              pcall(vim.api.nvim_win_close, win, true)
              if vim.api.nvim_buf_is_valid(buf) then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
              end
            end
          end
        end
      end)
    end

    local function close_zen_left_if_exists()
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "zen-left" then
              pcall(vim.api.nvim_win_close, win, true)
              if vim.api.nvim_buf_is_valid(buf) then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
              end
            end
          end
        end
      end)
    end

    -- Right integrations - close zen-right on FileType or BufWinEnter
    vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
      group = group,
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local right_integrations = {
          "neotest-summary",
          "aerial",
          "copilot-chat",
          "dapui_watches",
          "dapui_scopes",
          "dapui_stacks",
          "dapui_breakpoints",
        }
        for _, integration_ft in ipairs(right_integrations) do
          if ft == integration_ft then
            close_zen_right_if_exists()
            return
          end
        end
      end,
      desc = "Close zen-right when right integration opens",
    })

    -- Left integrations - close zen-left on FileType or BufWinEnter
    vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
      group = group,
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local left_integrations =
          { "neo-tree", "fugitiveblame", "fyler", "dbui", "undotree", "diff" }
        for _, integration_ft in ipairs(left_integrations) do
          if ft == integration_ft then
            close_zen_left_if_exists()
            return
          end
        end
      end,
      desc = "Close zen-left when left integration opens",
    })

    -- PATCH 2: zen.nvim doesn't listen to WinNew, so splits aren't detected immediately
    vim.api.nvim_create_autocmd("WinNew", {
      group = group,
      callback = function()
        vim.schedule(function()
          -- Skip if in codediff tab
          if is_codediff_tab() then
            close_zen_padding()
            return
          end

          -- Skip if dashboard is visible
          if is_dashboard_visible() then
            close_zen_padding()
            return
          end

          -- Count non-popup, non-side-panel windows (real editor splits)
          local normal_wins = 0
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local config = vim.api.nvim_win_get_config(win)
            if config.relative == "" then
              -- Use is_side_panel_window which handles empty filetype too
              if not is_side_panel_window(win) then
                normal_wins = normal_wins + 1
              end
            end
          end

          -- Close zen padding windows if we have 2+ real editor windows
          if normal_wins >= 2 then
            close_zen_padding()
          end
        end)
      end,
      desc = "Fix zen.nvim split detection",
    })

    -- PATCH 3: Manually create zen windows after lazy-load (VimEnter already fired)
    vim.schedule(function()
      -- Skip if in codediff tab, dashboard visible, or window too small
      if
        is_codediff_tab()
        or is_dashboard_visible()
        or vim.o.columns <= opts.main.width
      then
        return
      end

      -- Count real editor windows (non-side-panel, non-popup)
      local normal_wins = 0
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative == "" then
          if not is_side_panel_window(win) then
            normal_wins = normal_wins + 1
          end
        end
      end

      -- Only create zen windows if single window and no zen windows exist
      if normal_wins == 1 and not is_zen_active() then
        create_zen_windows(opts.main.width)
      end
    end)
  end,
  opts = {
    main = {
      width = 148, -- or vim.wo.colorcolumn
    },
    -- TIP: find a buffer's filetype with :lua print(vim.bo.filetype)
    top = {
      { filetype = "man" },
      { filetype = "help" },
      { filetype = "fugitive" },
    },
    right = {
      min_width = 46,
      { filetype = "copilot-chat" },
      { filetype = "neotest-summary" },
      {
        filetype = {
          "dapui_watches",
          "dapui_scopes",
          "dapui_stacks",
          "dapui_breakpoints",
        },
      },
    },
    bottom = {
      { filetype = "dap-repl" },
      { filetype = "qf" },
      { filetype = "trouble" },
      -- Removed noice - it was causing floats to become horizontal splits
    },
    left = {
      min_width = 46,
      { filetype = "fugitiveblame" },
      { filetype = "fyler" },
      { filetype = "neo-tree" }, -- Fixed: hyphenated
      { filetype = "dbui" },
      { filetype = { "undotree", "diff" } },
    },
  },
}
