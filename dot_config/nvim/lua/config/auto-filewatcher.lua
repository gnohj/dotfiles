--[[
███████╗██╗██╗     ███████╗    ██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗███████╗██████╗
██╔════╝██║██║     ██╔════╝    ██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║██╔════╝██╔══██╗
█████╗  ██║██║     █████╗      ██║ █╗ ██║███████║   ██║   ██║     ███████║█████╗  ██████╔╝
██╔══╝  ██║██║     ██╔══╝      ██║███╗██║██╔══██║   ██║   ██║     ██╔══██║██╔══╝  ██╔══██╗
██║     ██║███████╗███████╗    ╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║███████╗██║  ██║
╚═╝     ╚═╝╚══════╝╚══════╝     ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
Event-based filesystem watcher for instant external file change detection
Inspired by folke/sidekick.nvim - https://github.com/folke/sidekick.nvim/blob/main/lua/sidekick/cli/watch.lua
--]]

local M = {}

M.watches = {} ---@type table<string, uv.uv_fs_event_t>
M.changes = {} ---@type table<string, boolean>

--- Simple debounce implementation
--- @param fn function The function to debounce
--- @param ms number Milliseconds to wait
--- @return function Debounced function
local function debounce(fn, ms)
  local timer = vim.uv.new_timer()
  return function(...)
    local args = { ... }
    timer:stop()
    timer:start(ms, 0, function()
      vim.schedule_wrap(fn)(unpack(args))
    end)
  end
end

--- Get directory of a buffer
local function get_buf_dir(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.bo[buf].buftype ~= "" then
    return nil
  end
  -- Skip virtual schemes (gitsigns://, diffview://, etc)
  if path:match("^%w+://") then
    return nil
  end
  return vim.fn.fnamemodify(path, ":h")
end

--- Refresh checktime and clear changes (will be debounced)
local function refresh_impl()
  vim.cmd("checktime")
  M.changes = {}
end

--- Debounced refresh function
local refresh = debounce(refresh_impl, 100)

--- Start watching a directory
function M.start(dir)
  if M.watches[dir] then
    return
  end

  local watch = vim.uv.new_fs_event()
  local ok, err = watch:start(dir, {}, function(err, filename)
    if filename then
      M.changes[dir .. "/" .. filename] = true
      vim.schedule(refresh)
    end
  end)

  if not ok then
    vim.notify("Failed to watch " .. dir .. ": " .. err, vim.log.levels.WARN)
    if not watch:is_closing() then
      watch:close()
    end
    return
  end

  M.watches[dir] = watch
end

--- Stop watching a directory
function M.stop(dir)
  local watch = M.watches[dir]
  if watch then
    M.watches[dir] = nil
    if not watch:is_closing() then
      watch:close()
    end
  end
end

--- Update watches based on current buffers (implementation)
local function update_impl()
  local active_dirs = {}

  -- Collect directories from all loaded buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local dir = get_buf_dir(buf)
      if dir then
        active_dirs[dir] = true
        M.start(dir)
      end
    end
  end

  -- Remove watches for directories no longer in use
  for dir in pairs(M.watches) do
    if not active_dirs[dir] then
      M.stop(dir)
    end
  end
end

--- Debounced update function
M.update = debounce(update_impl, 100)

--- Cleanup all watches
function M.cleanup()
  for dir in pairs(M.watches) do
    M.stop(dir)
  end
end

--- Setup autocmds and initialize
function M.setup()
  -- Update watches when buffers change
  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufEnter" }, {
    callback = function()
      vim.schedule(M.update)
    end,
    desc = "Update filesystem watches",
  })

  -- Initial setup
  vim.defer_fn(M.update, 100)

  -- Cleanup on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = M.cleanup,
    desc = "Cleanup filesystem watches",
  })
end

return M
