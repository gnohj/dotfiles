--[[
 █████╗ ██╗   ██╗████████╗ ██████╗     ███████╗███████╗███╗   ██╗
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗    ╚══███╔╝██╔════╝████╗  ██║
███████║██║   ██║   ██║   ██║   ██║      ███╔╝ █████╗  ██╔██╗ ██║
██╔══██║██║   ██║   ██║   ██║   ██║     ███╔╝  ██╔══╝  ██║╚██╗██║
██║  ██║╚██████╔╝   ██║   ╚██████╔╝    ███████╗███████╗██║ ╚████║
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝     ╚══════╝╚══════╝╚═╝  ╚═══╝
--]]

-- ============================================================================
-- Auto Zen Mode Module
-- ============================================================================
-- Centralized zen mode management - handles auto-enable/disable based on
-- window count, manual toggles, and integration with dropbar.
--
-- Usage:
--   require("config.auto-zen").setup()  -- Call in autocmds.lua
--   require("config.auto-zen").toggle_manual()  -- Call in keymaps
--   require("config.auto-zen").is_zen_window(win)  -- Call in dropbar

local M = {}

local state = {
  enabled = false,
  manual_control = false,
  zen_win = nil, -- Track the zen window handle
}

-- ============================================================================
-- Public API
-- ============================================================================

---@return boolean
function M.is_enabled()
  return state.enabled
end

---@param win number Window handle
---@return boolean
function M.is_zen_window(win)
  if not state.enabled then
    return false
  end

  local ok, snacks_zen = pcall(require, "snacks.zen")
  if ok and snacks_zen.win then
    return snacks_zen.win.win == win
  end

  return false
end

--- Toggle zen mode manually (overrides auto-behavior)
function M.toggle_manual()
  state.manual_control = not state.manual_control

  require("snacks").zen()

  if state.manual_control then
    vim.notify("Zen: Manual control enabled", vim.log.levels.INFO)
  else
    vim.notify("Zen: Auto mode re-enabled", vim.log.levels.INFO)
  end
end

--- Get zen mode configuration for snacks.nvim
---@return table Zen configuration
function M.get_zen_config()
  return {
    enabled = true,
    toggles = {
      dim = false,
      git_signs = true,
      mini_diff_signs = true,
      diagnostics = true,
      inlay_hints = false,
      todo = true,
    },
    show = {
      statusline = true,
      tabline = false,
    },
    on_open = function(win)
      state.enabled = true
      state.zen_win = win.win

      -- Attach dropbar to zen window when buffers change
      M._setup_zen_dropbar(win.win)
    end,
    on_close = function(_)
      state.enabled = false
      state.zen_win = nil
    end,
  }
end

-- ============================================================================
-- Private Functions
-- ============================================================================

---@param zen_win number Zen window handle
function M._setup_zen_dropbar(zen_win)
  local group = vim.api.nvim_create_augroup("ZenDropbar", { clear = true })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      if state.enabled and vim.api.nvim_get_current_win() == zen_win then
        vim.schedule(function()
          local ok, dropbar_api = pcall(require, "dropbar.api")
          if ok and dropbar_api.get_dropbar then
            pcall(dropbar_api.get_dropbar, ev.buf, zen_win)
          end
        end)
      end
    end,
  })
end

--- Count normal (non-floating) windows in current tabpage
---@return number
local function count_normal_windows()
  local count = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative == "" then
      count = count + 1
    end
  end
  return count
end

--- Check if we should enable zen mode
---@return boolean
local function should_enable_zen()
  -- Only enable if running inside tmux
  if not vim.env.TMUX then
    return false
  end

  -- Skip if user manually disabled auto zen
  if state.manual_control then
    return false
  end

  -- Don't enable if Snacks isn't loaded
  if not package.loaded["snacks"] then
    return false
  end

  -- Don't enable in special buffers
  if vim.bo.buftype ~= "" then
    return false
  end

  return true
end

--- Update zen mode based on window count
local function update_zen_mode()
  if not should_enable_zen() then
    return
  end

  local window_count = count_normal_windows()

  -- Enable zen if only one window, disable if multiple
  if window_count == 1 then
    if not state.enabled then
      require("snacks").zen()
    end
  else
    if state.enabled then
      require("snacks").zen()
    end
  end
end

-- ============================================================================
-- Setup Auto Zen Autocmds
-- ============================================================================

--- Setup all autocmds for auto zen mode
function M.setup()
  local group = vim.api.nvim_create_augroup("AutoZenMode", { clear = true })

  -- Enable on startup (after LazyVim loads)
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyVimStarted",
    group = group,
    callback = function()
      vim.defer_fn(update_zen_mode, 100)
    end,
    desc = "Enable zen mode on startup",
  })

  -- Enable after window is fully set up (handles session restore)
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function()
      -- Only trigger for normal file buffers
      if vim.bo.buftype == "" and vim.bo.filetype ~= "snacks_dashboard" then
        -- Delay for markdown files to let folding autocmd complete
        local delay = vim.bo.filetype == "markdown" and 500 or 300

        vim.defer_fn(function()
          -- Double check cursor is positioned
          local cursor_pos = vim.api.nvim_win_get_cursor(0)
          if cursor_pos and cursor_pos[1] > 0 then
            update_zen_mode()
          end
        end, delay)
      end
    end,
    desc = "Enable zen mode after window setup",
  })

  -- Backup: Enable after first cursor movement
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    once = true,
    callback = function()
      if vim.bo.buftype == "" then
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        if cursor_pos and cursor_pos[1] > 0 then
          vim.defer_fn(update_zen_mode, 150)
        end
      end
    end,
    desc = "Enable zen mode after first cursor movement",
  })

  -- Update when windows change
  vim.api.nvim_create_autocmd(
    { "WinNew", "WinClosed", "WinEnter", "FocusGained" },
    {
      group = group,
      callback = function()
        vim.schedule(update_zen_mode)
      end,
      desc = "Auto toggle zen based on window count",
    }
  )
end

return M
