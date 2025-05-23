--[[
 █████╗ ██╗   ██╗████████╗ ██████╗  ██████╗███╗   ███╗██████╗ ███████╗
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗██╔════╝████╗ ████║██╔══██╗██╔════╝
███████║██║   ██║   ██║   ██║   ██║██║     ██╔████╔██║██║  ██║███████╗
██╔══██║██║   ██║   ██║   ██║   ██║██║     ██║╚██╔╝██║██║  ██║╚════██║
██║  ██║╚██████╔╝   ██║   ╚██████╔╝╚██████╗██║ ╚═╝ ██║██████╔╝███████║
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝  ╚═════╝╚═╝     ╚═╝╚═════╝ ╚══════╝
See `:help lua-guide-autocommands`
--]]

-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Mini.files key bindings
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

    vim.keymap.set(
      "n",
      "<space>y",
      function()
        -- Get the current entry (file or directory)
        local curr_entry = mini_files.get_fs_entry()
        if curr_entry then
          local path = curr_entry.path
          -- Build the osascript command to copy the file or directory to the clipboard
          local cmd = string.format([[osascript -e 'set the clipboard to POSIX file "%s"' ]], path)
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
      end,
      { buffer = buf_id, noremap = true, silent = true, desc = "[P]MiniFiles Copy file/directory contents to clipboard" }
    )

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

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.opt.formatoptions:remove({ "c", "r", "o" })
  end,
  desc = "Disable New Line Comment",
})

-- Disable built-in spellchecking for Markdown - https://github.com/LazyVim/LazyVim/discussions/392
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("lazyvim_user_markdown", { clear = true }),
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})

-- Fold keymaps in markdown files
vim.api.nvim_create_autocmd("BufRead", {
  pattern = "*.md",
  callback = function()
    -- Get the current buffer and its name
    local bufnr = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(bufnr)

    -- Skip completely if we're in diffview
    if bufname:match("^diffview://") then
      return
    end

    -- Skip if the filetype is related to diffview
    local filetype = vim.bo.filetype
    if filetype:match("^diffview") then
      return
    end

    -- Avoid running zk multiple times for the same buffer
    if vim.b.zk_executed then
      return
    end

    vim.b.zk_executed = true -- Mark as executed

    -- Use `vim.defer_fn` to add a slight delay before executing `zk`
    vim.defer_fn(function()
      -- Double-check we're still in the same buffer and it's valid
      if vim.api.nvim_get_current_buf() == bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.cmd("normal zk")

        -- Only try to write if it's a normal buffer
        if vim.bo.buftype == "" then
          pcall(function()
            vim.cmd("silent write")
          end)
          vim.notify("Folded keymaps", vim.log.levels.INFO)
        end
      end
    end, 100)
  end,
})

-- :OpenPRChanges - Uses the default origin/master
-- :OpenPRChanges origin/develop - Uses origin/develop instead
-- :OpenPRChanges + Tab - Shows completion options for branches
vim.api.nvim_create_user_command("OpenPRChanges", function(opts)
  local base_branch = opts.args ~= "" and opts.args or "origin/master"

  local changed_files = vim.fn.systemlist("git diff --name-only " .. base_branch .. "...HEAD")

  for _, file in ipairs(changed_files) do
    vim.cmd("edit " .. file)
  end
end, {
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    local branches = vim.fn.systemlist("git branch -a | cut -c 3-")
    local matches = {}
    for _, branch in ipairs(branches) do
      if branch:match("^" .. ArgLead) then
        table.insert(matches, branch)
      end
    end
    return matches
  end,
})

-- :ReviewPRChanges (uses Avante and origin/master)
-- :ReviewPRChanges avante (uses Avante with origin/master)
-- :ReviewPRChanges avante origin/develop (uses Avante with origin/develop)
-- :ReviewPRChanges copilot origin/develop (uses CopilotChat with origin/develop)
vim.api.nvim_create_user_command("ReviewPRChanges", function(opts)
  local args = vim.split(opts.args, " ", { trimempty = true })
  local ai_tool = args[1] or "avante"
  local base_branch = args[2] or "origin/master"

  local diff_cmd = "git diff " .. base_branch .. "...HEAD > /tmp/pr_changes.diff"
  vim.fn.system(diff_cmd)

  vim.cmd("split /tmp/pr_changes.diff")

  local prompt =
    "Review these PR changes and provide specific feedback on potential issues, improvements, and best practices. Focus only on the changed lines shown with + and - prefixes."

  if ai_tool:lower() == "avante" then
    vim.cmd(":AvanteAsk " .. prompt)
  elseif ai_tool:lower() == "copilot" then
    vim.cmd(":CopilotChat " .. prompt)
  else
    print("Unknown AI tool: " .. ai_tool .. ". Supported tools are 'avante' and 'copilot'.")
  end
end, {
  nargs = "*",
  complete = function(ArgLead, CmdLine, CursorPos)
    local args = vim.split(CmdLine, " ", { trimempty = true })

    if #args <= 2 then
      local tools = { "avante", "copilot" }
      local matches = {}
      for _, tool in ipairs(tools) do
        if tool:match("^" .. ArgLead) then
          table.insert(matches, tool)
        end
      end
      return matches
    elseif #args <= 3 then
      local branches = vim.fn.systemlist("git branch -a | cut -c 3-")
      local matches = {}
      for _, branch in ipairs(branches) do
        if branch:match("^" .. ArgLead) then
          table.insert(matches, branch)
        end
      end
      return matches
    end

    return {}
  end,
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

local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

-- Setup Diffview-specific keymaps
vim.api.nvim_create_autocmd({ "FileType" }, {
  group = augroup("diffview_escape"),
  pattern = {
    "DiffviewFiles",
    "DiffviewFileHistory",
    "DiffviewFilePanel",
    "DiffviewFHOptionPanel",
    "DiffviewOptionPanel",
    "DiffviewFilePanelTitle",
    "DiffviewLog",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "<esc>", function()
      vim.cmd("DiffviewClose")
    end, {
      buffer = event.buf,
      silent = true,
      desc = "[P]Close Diffview",
    })
  end,
})

-- For diff buffers within Diffview
vim.api.nvim_create_autocmd({ "BufEnter" }, {
  group = augroup("diffview_diff_buffers"),
  callback = function(event)
    -- Check if this is a diff buffer inside Diffview
    if vim.bo[event.buf].filetype == "diff" or vim.wo.diff then
      -- Check if we're in a Diffview session
      if vim.fn.exists("*DiffviewExists") == 1 and vim.fn.DiffviewExists() == 1 then
        vim.keymap.set("n", "<esc>", function()
          vim.cmd("DiffviewClose")
        end, {
          buffer = event.buf,
          silent = true,
          desc = "[P]Close Diffview",
        })
      end
    end
  end,
})

-- close some filetypes with <esc>
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "PlenaryTestPopup",
    "grug-far",
    "goto-preview",
    "help",
    "lspinfo",
    "notify",
    "qf",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
    "dbout",
    "gitsigns-blame",
    "Lazy",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
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
