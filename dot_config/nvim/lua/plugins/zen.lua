local restore_win_separator

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
  if restore_win_separator then
    restore_win_separator()
  end
end

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

local function is_codediff_tab()
  local lifecycle = package.loaded["codediff.ui.lifecycle"]
  if lifecycle then
    local tabpage = vim.api.nvim_get_current_tabpage()
    if lifecycle.get_session(tabpage) then
      return true
    end
  end
  return false
end

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

local function is_zen_or_integration(ft)
  for _, v in ipairs(zen_and_integration_filetypes) do
    if ft == v then
      return true
    end
  end
  return false
end

-- Used when filetype might not be set yet (timing issues)
local function is_side_panel_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype

  if is_zen_or_integration(ft) then
    return true
  end

  -- Fallback for windows with empty filetype (still loading)
  if ft == "" then
    local buftype = vim.bo[buf].buftype
    local winfixwidth = vim.wo[win].winfixwidth
    if buftype == "nofile" and winfixwidth then
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

-- Resolve the herdr binary robustly: pane shells don't always export
-- HERDR_BIN_PATH, and nvim's $PATH at system() time may miss the nix dir where
-- herdr lives (same rationale as mux.lua / herdr-navigator.lua).
local function herdr_bin()
  local h = vim.env.HERDR_BIN_PATH
  if h and h ~= "" then
    return h
  end
  local p = vim.fn.exepath("herdr")
  if p ~= "" then
    return p
  end
  return "herdr"
end

-- True when a dashboard sidebar is claiming horizontal space, so centering the
-- editor on top of the reduced viewport just wastes the columns next to the
-- sidebar and zen should skip centering. Two multiplexers, two signals:
--   tmux-dash sets the global `@dash` option on its server while running.
--   herdr reserves a left column band for its sidebar; `api snapshot` then
--   reports every tab layout's `area.x > 0` (x is 0 when the sidebar is hidden).
-- herdr is checked first because it also runs inside the `th` tmux wrapper, so
-- TMUX is set too (same herdr-wins precedence as mux.lua).
--
-- Cached, since it's read on every width recompute. Both markers only change on
-- a viewport resize (dashboard attach/detach, herdr `prefix+shift+b` sidebar
-- toggle), which fires VimResized — so the cache invalidates there (see
-- config()), keeping detection live.
local dash_sidebar_cache = nil
local function in_dash_sidebar()
  if dash_sidebar_cache ~= nil then
    return dash_sidebar_cache
  end
  local result = false
  if vim.env.HERDR_SOCKET_PATH and vim.env.HERDR_SOCKET_PATH ~= "" then
    local out = vim.fn.system({ herdr_bin(), "api", "snapshot" })
    if vim.v.shell_error == 0 then
      local ok, decoded = pcall(vim.json.decode, out)
      local snap = ok and decoded and decoded.result and decoded.result.snapshot
      if snap and type(snap.layouts) == "table" then
        for _, layout in ipairs(snap.layouts) do
          if layout.tab_id == snap.focused_tab_id and layout.area then
            result = (layout.area.x or 0) > 0
            break
          end
        end
      end
    end
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local out = vim.fn.system({ "tmux", "show-option", "-gv", "@dash" })
    result = vim.v.shell_error == 0 and vim.trim(out) == "1"
  end
  dash_sidebar_cache = result
  return result
end

-- Ideal (max) centered content width, and the min terminal width worth
-- centering at all. The effective width shrinks to fit narrower panes (e.g.
-- nvim sharing a herdr tab with an agent pane at ~141 cols) so zen still
-- centers instead of silently bailing; at full width it stays at the max.
local ZEN_MAX_WIDTH = 148
local ZEN_MIN_COLUMNS = 100

-- Effective centered width for the current terminal. Below ZEN_MIN_COLUMNS we
-- return the full column count so zen.nvim's own `columns <= width` gate trips
-- and it declines to center (a pane that narrow isn't worth centering).
local function zen_target_width()
  -- Returning the full column count makes zen.nvim's own `columns <= width` gate
  -- trip, so its built-in activation declines too (not just the manual paths).
  if vim.o.columns <= ZEN_MIN_COLUMNS or in_dash_sidebar() then
    return vim.o.columns
  end
  return math.min(ZEN_MAX_WIDTH, vim.o.columns - 8)
end

local function zen_should_activate()
  return vim.o.columns > ZEN_MIN_COLUMNS and not in_dash_sidebar()
end

local original_win_separator = nil
local original_fillchars = nil

local function style_zen_window(win)
  local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
  local bg = normal_hl.bg

  if bg then
    vim.api.nvim_set_hl(0, "ZenBg", { bg = bg, fg = bg })
  else
    vim.api.nvim_set_hl(0, "ZenBg", { bg = "NONE", fg = "NONE" })
  end

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

  if not current_fillchars:match("vert: ") then
    if current_fillchars:match("vert:[^,]*") then
      current_fillchars = current_fillchars:gsub("vert:[^,]*", "vert: ")
    else
      current_fillchars = current_fillchars .. ",vert: "
    end
    needs_update = true
  end

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

  if bg then
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = bg, bg = bg })
  else
    -- For transparent, use a very dark color that blends
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#000000", bg = "NONE" })
  end

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
  vim.wo[win].fillchars = "eob: ,vert: ,horiz: "
  vim.wo[win].statusline = " "
  vim.wo[win].signcolumn = "no"
end

restore_win_separator = function()
  if original_win_separator then
    vim.api.nvim_set_hl(0, "WinSeparator", original_win_separator)
  end
  if original_fillchars then
    vim.o.fillchars = original_fillchars
  end
end

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

local function style_all_zen_windows()
  local found_zen = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if is_zen_window(win) then
      style_zen_window(win)
      found_zen = true
    end
  end
  if not found_zen then
    restore_win_separator()
  end
end

-- Helper to create zen padding windows (mimics zen.nvim's create_window)
local function create_zen_windows(main_width)
  local current_win = vim.api.nvim_get_current_win()
  local padding_width = math.floor((vim.o.columns - main_width) / 2)

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
          if zen_should_activate() then
            create_zen_windows(zen_target_width())
          end
        end
      end,
      desc = "Toggle Zen Mode",
    },
  },
  config = function(_, opts)
    require("zen").setup(opts)

    local group = vim.api.nvim_create_augroup("ZenNvimFixes", { clear = true })

    -- Invalidate the dash-sidebar detection cache when the client resizes: a
    -- tmux-dash attach/detach (@dash marker) or a herdr sidebar toggle (area.x
    -- shift) both change the viewport width and thus fire VimResized.
    vim.api.nvim_create_autocmd("VimResized", {
      group = group,
      callback = function()
        dash_sidebar_cache = nil
      end,
      desc = "Re-check dash-sidebar marker on resize",
    })

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

          if is_dashboard_visible() then
            close_zen_padding()
            return
          end

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

          if normal_wins >= 2 then
            close_zen_padding()
          end
        end)
      end,
      desc = "Fix zen.nvim split detection",
    })

    -- PATCH 2.5: Re-create zen padding when back to single window
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      callback = function()
        vim.schedule(function()
          if is_codediff_tab() or is_dashboard_visible() or is_zen_active() then
            return
          end
          if not zen_should_activate() then
            return
          end

          local normal_wins = 0
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local config = vim.api.nvim_win_get_config(win)
            if config.relative == "" and not is_side_panel_window(win) then
              normal_wins = normal_wins + 1
            end
          end

          if normal_wins == 1 then
            create_zen_windows(zen_target_width())
          end
        end)
      end,
      desc = "Re-create zen padding when back to single window",
    })

    -- PATCH 3: Manually create zen windows after lazy-load (VimEnter already fired)
    vim.schedule(function()
      if
        is_codediff_tab()
        or is_dashboard_visible()
        or not zen_should_activate()
      then
        return
      end

      local normal_wins = 0
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative == "" then
          if not is_side_panel_window(win) then
            normal_wins = normal_wins + 1
          end
        end
      end

      if normal_wins == 1 and not is_zen_active() then
        create_zen_windows(zen_target_width())
      end
    end)
  end,
  opts = {
    main = {
      width = zen_target_width,
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
