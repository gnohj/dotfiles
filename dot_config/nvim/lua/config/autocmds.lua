--[[
 █████╗ ██╗   ██╗████████╗ ██████╗  ██████╗███╗   ███╗██████╗ ███████╗
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗██╔════╝████╗ ████║██╔══██╗██╔════╝
███████║██║   ██║   ██║   ██║   ██║██║     ██╔████╔██║██║  ██║███████╗
██╔══██║██║   ██║   ██║   ██║   ██║██║     ██║╚██╔╝██║██║  ██║╚════██║
██║  ██║╚██████╔╝   ██║   ╚██████╔╝╚██████╗██║ ╚═╝ ██║██████╔╝███████║
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝  ╚═════╝╚═╝     ╚═╝╚═════╝ ╚══════╝
See `:help lua-guide-autocommands`
--]]

-- Autocmds are automatically loaded on the VeryLazy event ( after startup and runs in the background )
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.luaa
-- Add any additional autocmds here

local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

-- ============================================================================
-- Wrap for markdown files
-- ============================================================================
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*.md",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- ============================================================================
-- Mini.files key bindings
-- ============================================================================
vim.api.nvim_create_autocmd("FileType", {
  pattern = "minifiles",
  callback = function(args)
    local buf_id = args.buf

    -- Make sure mini.files is available
    local ok, mini_files = pcall(require, "mini.files")
    if not ok then
      vim.notify("mini.files not available", vim.log.levels.WARN)
      return
    end

    vim.keymap.set("n", "<space>y", function()
      -- Get the current entry (file or directory)
      local curr_entry = mini_files.get_fs_entry()
      if curr_entry then
        local path = curr_entry.path
        -- Build the osascript command to copy the file or directory to the clipboard
        local cmd = string.format(
          [[osascript -e 'set the clipboard to POSIX file "%s"' ]],
          path
        )
        local result = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
          vim.notify("Copy failed: " .. result, vim.log.levels.ERROR)
        else
          vim.notify(vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
          vim.notify("Copied to system clipboard", vim.log.levels.INFO)
        end
      else
        vim.notify("No file or directory selected", vim.log.levels.WARN)
      end
    end, {
      buffer = buf_id,
      noremap = true,
      silent = true,
      desc = "[P]MiniFiles Copy file/directory contents to clipboard",
    })

    -- Copy path to clipboard
    vim.keymap.set("n", "<space>fy", function()
      -- Get the current entry using the API
      local curr_entry = mini_files.get_fs_entry()

      if curr_entry then
        local path = curr_entry.path

        -- Format the path (replace home directory with ~)
        path = path:gsub(vim.fn.expand("$HOME"), "~")

        -- Copy to clipboard
        vim.fn.setreg("+", path)
        vim.fn.setreg('"', path)

        vim.notify("Copied to clipboard: " .. path, vim.log.levels.INFO)
      else
        vim.notify("No file or directory selected", vim.log.levels.WARN)
      end
    end, {
      buffer = buf_id,
      desc = "[P]MiniFiles Copy path to clipboard",
    })
  end,
  desc = "Set up mini.files keymaps",
})

-- Mini Files Explorer - Open file in split
local map_split = function(buf_id, lhs, direction)
  local MiniFiles = require("mini.files")
  local rhs = function()
    -- Get the file under cursor
    local fs_entry = MiniFiles.get_fs_entry()
    if not fs_entry or fs_entry.fs_type ~= "file" then
      -- Not a file under cursor
      return
    end

    -- Make new window and set it as target
    local cur_target = MiniFiles.get_explorer_state().target_window
    local new_target = vim.api.nvim_win_call(cur_target, function()
      vim.cmd(direction .. " split")
      return vim.api.nvim_get_current_win()
    end)

    -- Set as target and go in (open the file)
    MiniFiles.set_target_window(new_target)
    MiniFiles.go_in()
  end

  -- Adding `desc` will result into `show_help` entries
  local desc = "[P]Open in " .. direction .. " split"
  vim.keymap.set("n", lhs, rhs, { buffer = buf_id, desc = desc })
end

vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesBufferCreate",
  callback = function(args)
    local buf_id = args.data.buf_id
    -- You can customize these key mappings
    map_split(buf_id, "<C-s>", "horizontal")
    map_split(buf_id, "<C-v>", "vertical")
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.opt.formatoptions:remove({ "c", "r", "o" })
  end,
  desc = "Disable New Line Comment",
})

-- ============================================================================
-- Disable built-in spellchecking for Markdown - https://github.com/LazyVim/LazyVim/discussions/392
-- ============================================================================
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup(
    "lazyvim_user_markdown",
    { clear = true }
  ),
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})

-- ============================================================================
-- Close filetypes with <esc>
-- ============================================================================
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "PlenaryTestPopup",
    "grug-far",
    "help",
    "lspinfo",
    "notify",
    "qf",
    "quickfix",
    "neo-tree",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
    "dbout",
    "gitsigns-blame",
    "OverseerList",
    "Lazy",
    "noice",
    "MCPHub",
    "aerial",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      -- Check if buffer still exists before setting keymap
      -- When you visually select text and use Shift+J/K to move lines; buffer no longer exists
      if not vim.api.nvim_buf_is_valid(event.buf) then
        return
      end

      vim.keymap.set("n", "<esc>", function()
        vim.cmd("close")
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, {
        buffer = event.buf,
        silent = true,
        desc = "[P]Quit buffer",
      })
    end)
  end,
})

-- Close buffer-name patterns with <esc> (these are not filetypes)
vim.api.nvim_create_autocmd("BufEnter", {
  group = augroup("close_buffers_with_esc"),
  pattern = {
    "gitsigns://*",
    "gitlineage://*",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "<esc>", function()
      vim.cmd("close")
      pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
    end, {
      buffer = event.buf,
      silent = true,
      desc = "[P]Quit buffer",
    })
  end,
})

-- ============================================================================
-- Auto-reload files changed externally
-- ============================================================================

-- Check for external changes when switching buffers or gaining focus
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
  desc = "Check for external file changes on focus/buffer switch",
})

-- Event-based filesystem watcher for instant change detection
require("config.auto-filewatcher").setup()

-- ============================================================================
-- Filetype detection for HTTP files (kulala.nvim)
-- ============================================================================
vim.filetype.add({
  extension = {
    ["http"] = "http",
  },
})
