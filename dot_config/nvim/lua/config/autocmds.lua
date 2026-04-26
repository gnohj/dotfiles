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
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- ============================================================================
-- Markdown LSP codelens (reference counts) — markdown-oxide
-- ============================================================================
-- Global autocmd (not buffer-local) so it survives LSP attach/detach cycles.
-- Pattern from linkarzu/dotfiles-latest. CursorHold fires after `updatetime` ms
-- of cursor inactivity, so codelens reappears as soon as you stop scrolling.
local function codelens_supported(bufnr)
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if c.server_capabilities and c.server_capabilities.codeLensProvider then
      return true
    end
  end
  return false
end

local function refresh_markdown_codelens(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.bo[bufnr].buftype ~= "" then
    return
  end
  if vim.bo[bufnr].filetype ~= "markdown" then
    return
  end
  if not codelens_supported(bufnr) then
    return
  end
  vim.lsp.codelens.refresh({ bufnr = bufnr })
end

vim.api.nvim_create_autocmd(
  { "BufEnter", "CursorHold", "InsertLeave", "TextChanged" },
  {
    callback = function(args)
      refresh_markdown_codelens(args.buf)
    end,
  }
)

-- Sanitize markdown-oxide fileOperations capability.
-- markdown-oxide returns `scheme: null` in its workspace.fileOperations
-- filters, which decodes to vim.NIL (userdata). mini.files crashes when
-- saving a newly-created file because it does `scheme .. ':'` which fails
-- on userdata. Replace vim.NIL with Lua nil at LspAttach time.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "markdown_oxide" then
      return
    end
    local fo = client.server_capabilities.workspace
      and client.server_capabilities.workspace.fileOperations
    if not fo then
      return
    end
    for _, method in ipairs({
      "didCreate",
      "didDelete",
      "didRename",
      "willCreate",
      "willDelete",
      "willRename",
    }) do
      local entry = fo[method]
      if entry and entry.filters then
        for _, f in ipairs(entry.filters) do
          if f.scheme == vim.NIL then
            f.scheme = nil
          end
        end
      end
    end
  end,
})

-- Workaround for nvim issue 16166: codelens at line 0 renders as a virtual
-- line above line 1 and requires `topfill=1` to be visible. nvim sets this
-- once on initial render, but plugins that call winrestview on cursor move
-- can reset it. Force topfill=1 when the viewport is at the top of a
-- markdown buffer so file-level "X references" codelens stays visible.
-- (Still useful as a fallback — our inline display above bypasses virt_lines
-- entirely so this guard is only relevant if we ever revert to default.)
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorHold", "WinScrolled" }, {
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "markdown" then
      return
    end
    if vim.bo[args.buf].buftype ~= "" then
      return
    end
    local view = vim.fn.winsaveview()
    if view.topline == 1 and view.topfill == 0 then
      vim.fn.winrestview({ topfill = 1 })
    end
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
  pattern = {
    [".*/%.github/workflows/.*%.ya?ml"] = "yaml.github",
    [".*/%.github/actions/.*%.ya?ml"] = "yaml.github",
  },
})

-- ============================================================================
-- LSP progress → Ghostty terminal progress bar (OSC 9;4) + nvim 0.12 echo
-- ============================================================================
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(ev)
    local value = ev.data.params.value or {}
    if not value.kind then return end

    -- OSC 9;4 for Ghostty progress bar
    local status, percent
    if value.kind == "end" then
      status, percent = 0, 0
    elseif value.percentage then
      status, percent = 1, value.percentage
    else
      status, percent = 3, 0 -- indeterminate spinner
    end

    local osc_seq = string.format("\27]9;4;%d;%d\a", status, percent)
    if os.getenv("TMUX") then
      osc_seq = string.format("\27Ptmux;\27%s\27\\", osc_seq)
    end
    io.stdout:write(osc_seq)
    io.stdout:flush()

    -- nvim 0.12 echo progress (bottom status message)
    local msg = value.message or "done"
    if #msg > 40 then msg = msg:sub(1, 37) .. "..." end
    local client = ev.data.client_id and vim.lsp.get_client_by_id(ev.data.client_id)
    vim.api.nvim_echo({ { msg } }, false, {
      id = "lsp",
      kind = "progress",
      title = value.title,
      source = client and client.name or "lsp",
      status = value.kind ~= "end" and "running" or "success",
      percent = value.percentage,
    })
  end,
})

-- Clear Ghostty progress bar on exit (prevents stuck indicator)
vim.api.nvim_create_autocmd({ "VimLeavePre", "ExitPre" }, {
  callback = function()
    local osc = "\27]9;4;0;100\a"
    if os.getenv("TMUX") then
      osc = string.format("\27Ptmux;\27%s\27\\", osc)
    end
    io.stdout:write(osc)
    io.stdout:flush()
  end,
})
