-- Shared helpers for Obsidian second-brain workflows.
-- Called from keymaps.lua, the snacks dashboard, and shell scripts in _bin/.
local M = {}

local VAULT = vim.fn.expand("~/Obsidian/second-brain")
local INBOX = VAULT .. "/0-Inbox"
local ZETTEL = VAULT .. "/Zettelkasten"

-- A "created note" is a .md file in the inbox whose first non-empty line
-- is a YAML frontmatter delimiter (`---`). Raw resources (txt dumps,
-- screenshots, .md files without frontmatter) are skipped during review.
local function is_created_note(path)
  if not path:match("%.md$") then
    return false
  end
  local f = io.open(path, "r")
  if not f then
    return false
  end
  for line in f:lines() do
    if line:match("%S") then
      f:close()
      return line:match("^%-%-%-%s*$") ~= nil
    end
  end
  f:close()
  return false
end

-- Prompt for a title and create a new inbox note, then expand
-- the ;note-template luasnip. Used by both <leader>zN and the dashboard
-- "Second Brain (New)" entry.
--
-- When called from the snacks dashboard, no real file has been loaded yet
-- so LazyVim's `LazyFile` event (which lazy-loads treesitter, LSP, etc.)
-- hasn't fired and the dashboard's keypress runs under `eventignore`. We
-- mitigate by clearing eventignore, then re-firing BufReadPost/FileType
-- after `:edit` so plugins that registered handlers later still attach.
function M.new_inbox_note()
  vim.ui.input({ prompt = "New note title: " }, function(title)
    if not title or title == "" then
      return
    end
    local vault = vim.fn.expand("~/Obsidian/second-brain")
    local date = os.date("%Y-%m-%d")
    local filename = title:gsub(" ", "-")
    local path = vault .. "/0-Inbox/" .. date .. "_" .. filename .. ".md"
    if vim.fn.filereadable(path) == 1 then
      vim.notify("Note already exists: " .. path, vim.log.levels.WARN)
      return
    end

    vim.opt.eventignore = ""
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()

    -- Force filetype detection + re-fire LazyFile triggers in case the
    -- original BufNewFile was suppressed (snacks dashboard context).
    if vim.bo[buf].filetype ~= "markdown" then
      vim.bo[buf].filetype = "markdown"
    end
    pcall(
      vim.api.nvim_exec_autocmds,
      "BufReadPost",
      { buffer = buf, modeline = false }
    )
    pcall(
      vim.api.nvim_exec_autocmds,
      "FileType",
      { buffer = buf, modeline = false }
    )
    pcall(
      vim.api.nvim_exec_autocmds,
      "User",
      { pattern = "LazyFile", modeline = false }
    )

    -- Defer snippet expansion one tick so treesitter/LSP have attached
    -- before we start mutating the buffer in insert mode.
    vim.schedule(function()
      local ls = require("luasnip")
      local snippets = ls.get_snippets("markdown")
      for _, snip in ipairs(snippets) do
        if snip.trigger == ";note-template" then
          vim.cmd("startinsert")
          ls.snip_expand(snip)
          return
        end
      end
      vim.notify(";note-template snippet not found", vim.log.levels.WARN)
    end)
  end)
end

-- Open a snacks picker over only the "created notes" in 0-Inbox/. Backs
-- the `or` shell script, the dashboard "Second Brain (Review)" entry, and
-- <leader>zr.
function M.review_inbox()
  local entries = vim.fn.globpath(INBOX, "*.md", false, true)
  local items = {}
  for _, path in ipairs(entries) do
    if is_created_note(path) then
      table.insert(items, {
        text = vim.fn.fnamemodify(path, ":t"),
        file = path,
      })
    end
  end
  if #items == 0 then
    vim.notify("No created notes in 0-Inbox/", vim.log.levels.INFO)
    return
  end
  table.sort(items, function(a, b)
    return a.text < b.text
  end)
  Snacks.picker.pick({
    title = "Inbox: review created notes (" .. #items .. ")",
    items = items,
    format = function(item)
      return { { item.text } }
    end,
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
    end,
  })
end

-- The vault directory is a symlink to iCloud, so the buffer path may
-- resolve to `~/Library/Mobile Documents/...` while INBOX above resolves
-- to `~/Obsidian/second-brain/...`. Match by structural `/0-Inbox/` segment
-- and recover the vault root from the buffer's actual path.
local function inbox_match(path)
  return path:match("^(.+)/0%-Inbox/[^/]+%.md$")
end

-- Move the current buffer's file from 0-Inbox/ to Zettelkasten/ for
-- processing. Closes the buffer after the move (per user preference).
function M.move_to_zettelkasten()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or vim.fn.filereadable(path) ~= 1 then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end
  local vault_root = inbox_match(path)
  if not vault_root then
    vim.notify("Not in 0-Inbox/: " .. path, vim.log.levels.WARN)
    return
  end
  local zettel = vault_root .. "/Zettelkasten"
  vim.fn.mkdir(zettel, "p")
  local target = zettel .. "/" .. vim.fn.fnamemodify(path, ":t")
  if vim.fn.filereadable(target) == 1 then
    vim.notify(
      "Target exists in Zettelkasten/: " .. target,
      vim.log.levels.ERROR
    )
    return
  end
  if vim.bo.modified then
    vim.cmd("silent! write")
  end
  local ok, err = os.rename(path, target)
  if not ok then
    vim.notify("Move failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.cmd("bdelete!")
  vim.notify("Moved to Zettelkasten/: " .. vim.fn.fnamemodify(target, ":t"))
end

-- Delete the current buffer's inbox file (with confirmation). Use when
-- review decides a note isn't worth keeping.
function M.delete_from_inbox()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or vim.fn.filereadable(path) ~= 1 then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end
  if not inbox_match(path) then
    vim.notify("Not in 0-Inbox/: " .. path, vim.log.levels.WARN)
    return
  end
  local choice = vim.fn.confirm(
    "Delete " .. vim.fn.fnamemodify(path, ":t") .. "?",
    "&Yes\n&No",
    2
  )
  if choice ~= 1 then
    return
  end
  local ok, err = os.remove(path)
  if not ok then
    vim.notify("Delete failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.cmd("bdelete!")
  vim.notify("Deleted: " .. vim.fn.fnamemodify(path, ":t"))
end

-- Run the `op` publish script (Zettelkasten/ -> Notes/<hub>/) and report.
-- Output is shown in :messages so you can review what moved/skipped.
function M.publish()
  vim.notify("Publishing… (Zettelkasten → Notes/<hub>/)", vim.log.levels.INFO)
  local out = vim.fn.system({ "op" })
  local code = vim.v.shell_error
  if code ~= 0 then
    vim.notify(
      "op failed (exit " .. code .. "):\n" .. out,
      vim.log.levels.ERROR
    )
    return
  end
  for line in (out .. "\n"):gmatch("([^\n]*)\n") do
    if line ~= "" then
      print(line)
    end
  end
  vim.notify("Publish complete (see :messages)", vim.log.levels.INFO)
end

return M
