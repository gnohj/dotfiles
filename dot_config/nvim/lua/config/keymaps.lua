--[[
██╗  ██╗███████╗██╗   ██╗███╗   ███╗ █████╗ ██████╗ ███████╗
██║ ██╔╝██╔════╝╚██╗ ██╔╝████╗ ████║██╔══██╗██╔══██╗██╔════╝
█████╔╝ █████╗   ╚████╔╝ ██╔████╔██║███████║██████╔╝███████╗
██╔═██╗ ██╔══╝    ╚██╔╝  ██║╚██╔╝██║██╔══██║██╔═══╝ ╚════██║
██║  ██╗███████╗   ██║   ██║ ╚═╝ ██║██║  ██║██║     ███████║
╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝
--]]

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

-- Disable LazyVim's ; and , bindings (restore native vim f/t repeat behavior)
keymap({ "n", "x", "o" }, ";", ";", { desc = "Next f/t/F/T" })
keymap({ "n", "x", "o" }, ",", ",", { desc = "Prev f/t/F/T" })

keymap("i", "jk", "<ESC>", { desc = "[P]Exit insert mode with jk" })

keymap("v", "q", "+y", { desc = "[P]Yank selected text in visual mode" })

-- Use snacks picker for LSP go to definition (consistent ivy layout, multiple results handled properly)
keymap("n", "gd", function()
  require("snacks").picker.lsp_definitions()
end, { desc = "Go to Definition" })

-- Quit Neovim instance with save and quit all
keymap("n", "<C-q>", "<cmd>wqa<cr>", { desc = "[P]Save and quit all" })

-- Restart Neovim (nvim 0.12+)
keymap("n", "<leader>qr", "<cmd>restart<cr>", { desc = "[P]Restart Neovim" })

-- Toggle relative line numbers (both number and relativenumber)
keymap("n", "<leader>tn", function()
  local current = vim.opt.number:get()
  vim.opt.number = not current
  vim.opt.relativenumber = not current
end, { desc = "[P]Toggle relative line numbers" })

-- Toggle absolute line numbers only (no relative)
keymap("n", "<leader>tN", function()
  vim.opt.number = not vim.opt.number:get()

  vim.opt.relativenumber = false
end, { desc = "[P]Toggle absolute line numbers" })

keymap("n", "<M-o>", "<C-o>", { desc = "[P]Jump backward in jump list" })
keymap("n", "<M-i>", "<C-i>", { desc = "[P]Jump forward in jump list" })

-- delete without yanking
keymap(
  { "n", "v" },
  "<leader>dd",
  [["_d]],
  { desc = "[P]Delete without yanking" }
)

keymap("x", "<leader>dd", '"_d', { desc = "[P]Delete without yanking" })
keymap(
  "n",
  "<leader>d",
  '"_d',
  { desc = "[P]Delete without yanking (operator)" }
)
keymap(
  "n",
  "<leader>D",
  '"_D',
  { desc = "[P]Delete to end of line without yanking" }
)

keymap(
  "v",
  "J",
  ":m '>+1<CR>gv=gv",
  { desc = "[P]Move line down in visual mode" }
)
keymap(
  "v",
  "K",
  ":m '<-2<CR>gv=gv",
  { desc = "[P]Move line up in visual mode" }
)

-- Set highlight on search, but clear on pressing <Esc> in normal mode
keymap(
  "n",
  "<Esc>",
  "<cmd>nohlsearch<CR>",
  { desc = "[P]Clear search highlight" }
)

keymap("n", "<leader><space>", "<cmd>e #<cr>", { desc = "[P]Alternate buffer" })

-- Toggle zen mode manually (overrides auto zen)
-- DISABLED: Testing zen.nvim (sand4rt) instead
-- keymap("n", "<leader>uz", function()
--   require("config.auto-zen").toggle_manual()
-- end, { desc = "[P]Toggle Zen Mode (manual)" })

local function insertFullPath()
  local full_path = vim.fn.expand("%:p") -- Get the full file path
  local display_path

  -- Check if this is a codediff buffer
  -- Format: codediff:///repo/path///commit_hash/relative/path
  if full_path:match("^codediff://") then
    -- Extract path after ///commit_hash/ (40 hex chars)
    local relative_path = full_path:match("///[a-f0-9]+/(.+)$")
    display_path = relative_path or full_path
  else
    -- Normal file - replace $HOME with ~
    display_path = full_path:gsub(vim.fn.expand("$HOME"), "~")
  end

  vim.fn.setreg("+", display_path)
  vim.notify("Copied to clipboard: " .. display_path, vim.log.levels.INFO)
end

keymap(
  "n",
  "<leader>fy",
  insertFullPath,
  { silent = true, noremap = true, desc = "[P]Copy full path" }
)

-- Open file from clipboard path (pairs with <leader>fy for codediff workflow)
keymap("n", "<leader>fY", function()
  local path = vim.fn.getreg("+"):gsub("%s+", "") -- trim whitespace
  if path == "" then
    vim.notify("Clipboard is empty", vim.log.levels.WARN)
    return
  end

  -- Expand ~ to home directory
  local expanded = path:gsub("^~", vim.fn.expand("$HOME"))

  -- Try to find the file relative to cwd first, then as absolute
  local cwd = vim.fn.getcwd()
  local try_paths = {
    cwd .. "/" .. path, -- relative to cwd
    cwd .. "/" .. expanded, -- expanded relative to cwd
    expanded, -- absolute path
  }

  for _, try_path in ipairs(try_paths) do
    if vim.fn.filereadable(try_path) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(try_path))
      vim.notify("Opened: " .. path, vim.log.levels.INFO)
      return
    end
  end

  vim.notify("File not found: " .. path, vim.log.levels.ERROR)
end, { silent = true, noremap = true, desc = "[P]Open file from clipboard" })

keymap(
  { "n", "v", "i" },
  "<M-r>",
  "<Nop>",
  { desc = "[P] Disabled No operation for <M-r>" }
)

keymap({ "n", "v", "i" }, "<M-y>", function()
  -- require("noice").cmd("history")
  require("noice").cmd("all")
end, { desc = "[P]Noice History" })

-- Paste images: <leader>zv defined in plugins/img-clip.lua
-- Pastes clipboard image into vault's Assets/ folder, embeds as ![[filename]]

-- Disable lazygit which is enabled default by LazyVim
pcall(vim.keymap.del, "n", "<leader>gg")
pcall(vim.keymap.del, "n", "<leader>gG")

-------------------------------------------------------------------------------
--                           Grugfar
-------------------------------------------------------------------------------
keymap(
  { "v" },
  "<leader>s1",
  '<cmd>lua require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })<cr>',
  { noremap = true, silent = true }
)

-------------------------------------------------------------------------------
--                           Package Info
-------------------------------------------------------------------------------

-- package-info keymaps
keymap(
  "n",
  "<leader>cpt",
  "<cmd>lua require('package-info').toggle()<cr>",
  { silent = true, noremap = true, desc = "[P]Package Info Toggle" }
)
keymap(
  "n",
  "<leader>cpd",
  "<cmd>lua require('package-info').delete()<cr>",
  { silent = true, noremap = true, desc = "[P] Package Info Delete package" }
)
keymap(
  "n",
  "<leader>cpu",
  "<cmd>lua require('package-info').update()<cr>",
  { silent = true, noremap = true, desc = "[P]Package Info Update package" }
)
keymap(
  "n",
  "<leader>cpi",
  "<cmd>lua require('package-info').install()<cr>",
  { silent = true, noremap = true, desc = "[P]Package Info Install package" }
)
keymap(
  "n",
  "<leader>cpc",
  "<cmd>lua require('package-info').change_version()<cr>",
  {
    silent = true,
    noremap = true,
    desc = "[P]Package Info Change package version",
  }
)

-------------------------------------------------------------------------------
--                           GitHub Browse (Upstream Branch)
-------------------------------------------------------------------------------

-- Helper function to get upstream/origin default branch with fallbacks
local function get_default_branch()
  local repo = require("snacks").git.get_root()
  if not repo then
    return nil
  end

  -- Tcy upstream default branch first
  local branch = vim.fn
    .system(
      "cd "
        .. vim.fn.shellescape(repo)
        .. " && git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null | sed 's@^refs/remotes/upstream/@@'"
    )
    :gsub("\n", "")

  -- Fallback to origin default branch
  if branch == "" then
    branch = vim.fn
      .system(
        "cd "
          .. vim.fn.shellescape(repo)
          .. " && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'"
      )
      :gsub("\n", "")
  end

  -- Fallback to current checked out branch
  if branch == "" then
    branch = vim.fn
      .system(
        "cd "
          .. vim.fn.shellescape(repo)
          .. " && git rev-parse --abbrev-ref HEAD"
      )
      :gsub("\n", "")
  end

  -- Fallback chain: develop -> main -> master
  if branch == "" or branch == "HEAD" then
    local fallbacks = { "develop", "main", "master" }
    for _, fb in ipairs(fallbacks) do
      local exists = vim.fn.system(
        "cd "
          .. vim.fn.shellescape(repo)
          .. " && git rev-parse --verify "
          .. fb
          .. " 2>/dev/null"
      )
      if vim.v.shell_error == 0 then
        branch = fb
        break
      end
    end
  end

  -- Final fallback
  if branch == "" then
    branch = "master"
  end

  return branch
end

-- Custom GitHub browse that always uses upstream/origin default branch
keymap({ "n", "v" }, "<leader>gb", function()
  local branch = get_default_branch()
  if not branch then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  require("snacks").gitbrowse.open({
    branch = branch,
  })
end, { desc = "[P]Git Browse (upstream branch)" })

-- Custom GitHub URL copy that always uses upstream/origin default branch
keymap({ "n", "v" }, "<leader>gy", function()
  local branch = get_default_branch()
  if not branch then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  require("snacks").gitbrowse({
    branch = branch,
    notify = false,
    open = function(url)
      vim.fn.setreg("+", url)
      vim.notify("Copied to clipboard: " .. url, vim.log.levels.INFO)
    end,
  })
end, { desc = "[P]Copy Git URL (upstream branch)" })

-------------------------------------------------------------------------------
--                           Toggle Copilot Virtual Text
-------------------------------------------------------------------------------

keymap(
  "n",
  "<leader>as",
  ":lua require('copilot.suggestion').toggle_auto_trigger()<CR>",
  {
    silent = true,
    noremap = true,
    desc = "[P]Copilot: toggle virtual text suggestions",
  }
)

-------------------------------------------------------------------------------
--                           Obsidian
-------------------------------------------------------------------------------
-- convert note to template and remove leading white space
keymap("n", "<leader>zn", function()
  local template_path =
    vim.fn.expand("~/Obsidian/second-brain/Templates/note.md")

  if vim.fn.filereadable(template_path) == 0 then
    vim.notify("Template not found: " .. template_path, vim.log.levels.ERROR)
    return
  end

  -- Extract and format title from filename
  local filename = vim.fn.expand("%:t:r")
  local title = filename
    :gsub("^%d%d%d%d%-%d%d%-%d%d_", "")
    :gsub("-", " ")
    :gsub("(%a)([%w_']*)", function(first, rest)
      return first:upper() .. rest:lower()
    end)

  local date = os.date("%Y-%m-%d")

  -- Read and insert template
  vim.cmd("0r " .. template_path)

  -- Replace variables
  vim.cmd("silent! %s/{ { date } }/" .. date .. "/g")
  vim.cmd("silent! %s/{{title}}/" .. title .. "/g")

  -- Remove leading whitespace (make this silent too)
  vim.cmd([[silent! 1,/^\S/s/^\n\{1,}//]])
end, { desc = "New note template" })

-- strip date from note title and replace dashes with spaces
-- must have cursor on title
keymap(
  "n",
  "<leader>zf",
  ":s/\\(# \\)[^_]*_/\\1/ | s/-/ /g<cr>",
  { desc = "[P]Obsidian: Format note title" }
)
--
-- for review workflow
-- move file in current buffer to zettelkasten folder
keymap(
  "n",
  "<M-k>",
  ":!mv '%:p' /Users/gnohj/Obsidian/second-brain/Zettelkasten/<cr>:bd<cr>",
  { desc = "[P]Obsidian: Move file to Zettelkasten" }
)
-- delete file in current buffer
keymap(
  "n",
  "<M-p>",
  ":!rm '%:p'<cr>:bd<cr>",
  { desc = "[P]Obsidian: Delete file in current buffer" }
)

-- LSP symbols (always-on bindings, independent of plugin lazy-loading).
-- LazyVim's snacks_picker extra binds these via lspconfig `keys` with a
-- `has = "documentSymbol"` filter, which means they only attach on LSP
-- buffers that advertise that capability AND only after the plugin loads.
-- That race left `<leader>ss` unbound long enough for flash to grab `s`.
keymap("n", "<leader>ss", function()
  if package.loaded["snacks"] and Snacks.picker then
    Snacks.picker.lsp_symbols({ filter = LazyVim.config.kind_filter })
  else
    vim.lsp.buf.document_symbol()
  end
end, { desc = "LSP Symbols" })

keymap("n", "<leader>sS", function()
  if package.loaded["snacks"] and Snacks.picker then
    Snacks.picker.lsp_workspace_symbols({
      filter = LazyVim.config.kind_filter,
    })
  else
    vim.lsp.buf.workspace_symbol()
  end
end, { desc = "LSP Workspace Symbols" })

-- markdown-oxide LSP provides native equivalents:
--   gd → goto definition (jump to wikilink target)
--   gr → references (show all backlinks; Lspsaga finder, mtime-sorted, in-place edit)
--   <leader>cs → workspace symbols (search all headings)
--   <leader>cr → rename (auto-updates all backlinks)
--   <leader>ca → code actions (e.g. create note from unresolved [[ref]])
-- Custom <leader>zl / <leader>zb kept for muscle memory + snacks-picker UI.

-- Follow [[wikilink]] under cursor
keymap("n", "<leader>zl", function()
  local vault = vim.fn.expand("~/Obsidian/second-brain")
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  -- Find [[...]] around cursor
  local s, e, link = nil, 0, nil
  while true do
    s, e, link = line:find("%[%[([^%]]+)%]%]", e + 1)
    if not s then
      break
    end
    if col >= s and col <= e then
      break
    end
    link = nil
  end
  if not link then
    vim.notify("No [[wikilink]] under cursor", vim.log.levels.WARN)
    return
  end
  -- Strip any alias (e.g. [[file|alias]])
  link = link:match("^([^|]+)") or link
  -- Search vault for matching file
  local results = vim.fn.globpath(vault, "**/" .. link .. ".md", false, true)
  if #results == 0 then
    vim.notify("Note not found: " .. link, vim.log.levels.WARN)
  elseif #results == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(results[1]))
  else
    vim.ui.select(results, { prompt = "Multiple matches:" }, function(choice)
      if choice then
        vim.cmd("edit " .. vim.fn.fnameescape(choice))
      end
    end)
  end
end, { desc = "[P]Obsidian: Follow [[wikilink]]" })

-- Show all backlinks to current file
keymap("n", "<leader>zb", function()
  local vault = vim.fn.expand("~/Obsidian/second-brain")
  local name = vim.fn.expand("%:t:r") -- filename without extension
  local pattern = "\\[\\[" .. name .. "\\]\\]"
  local results = vim.fn.systemlist(
    "rg -l '" .. pattern .. "' " .. vim.fn.shellescape(vault) .. " 2>/dev/null"
  )
  if #results == 0 then
    vim.notify("No backlinks to: " .. name, vim.log.levels.INFO)
    return
  end
  local items = {}
  for _, path in ipairs(results) do
    table.insert(items, { text = path, file = path })
  end
  Snacks.picker.pick({
    title = "Backlinks: " .. name,
    items = items,
    format = function(item)
      local rel = item.file:gsub(vault .. "/", "")
      return { { rel } }
    end,
    confirm = function(picker, item)
      picker:close()
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
    end,
  })
end, { desc = "[P]Obsidian: Show backlinks to this note" })

-- Obsidian frontmatter search helper
local function vault_frontmatter_search(field, prompt, pattern_fn, multiline)
  local vault = vim.fn.expand("~/Obsidian/second-brain")

  local function run_search(query)
    local pattern = pattern_fn(query)
    local flag = multiline and "-U -l" or "-l"
    local results = vim.fn.systemlist(
      "rg " .. flag .. " '" .. pattern .. "' " .. vim.fn.shellescape(vault) .. " 2>/dev/null"
    )
    if #results == 0 then
      vim.notify("No notes found for " .. field .. ": " .. query, vim.log.levels.INFO)
      return
    end
    local items = {}
    for _, path in ipairs(results) do
      table.insert(items, { text = path, file = path })
    end
    Snacks.picker.pick({
      title = field .. ": " .. query,
      items = items,
      format = function(item)
        local rel = item.file:gsub(vault .. "/", "")
        return { { rel } }
      end,
      confirm = function(picker, item)
        picker:close()
        vim.cmd("edit " .. vim.fn.fnameescape(item.file))
      end,
    })
  end

  if prompt then
    vim.ui.input({ prompt = prompt }, function(query)
      if not query or query == "" then
        return
      end
      run_search(query)
    end)
  else
    -- Called with pattern_fn already bound to a query (e.g. from vim.ui.select)
    run_search("")
  end
end

-- Search vault by hub (filing category) in frontmatter
keymap("n", "<leader>zh", function()
  local vault = vim.fn.expand("~/Obsidian/second-brain")
  local hub_dirs = vim.fn.globpath(vault .. "/Notes", "*", false, true)
  local hubs = {}
  for _, d in ipairs(hub_dirs) do
    if vim.fn.isdirectory(d) == 1 then
      table.insert(hubs, vim.fn.fnamemodify(d, ":t"))
    end
  end
  vim.ui.select(hubs, { prompt = "Hub:" }, function(choice)
    if not choice then
      return
    end
    vault_frontmatter_search("hub", nil, function()
      return "^hubs: " .. choice .. "$|^  - " .. choice .. "$"
    end)
  end)
end, { desc = "[P]Obsidian: Find notes by hub" })

-- Search vault by tag (topic) in frontmatter
keymap("n", "<leader>zt", function()
  local vault = vim.fn.expand("~/Obsidian/second-brain")
  local tag_files = vim.fn.globpath(vault .. "/0-Tags", "*.md", false, true)
  local tags = {}
  for _, f in ipairs(tag_files) do
    table.insert(tags, vim.fn.fnamemodify(f, ":t:r"))
  end
  vim.ui.select(tags, { prompt = "Tag:" }, function(choice)
    if not choice then
      return
    end
    vault_frontmatter_search("tag", nil, function()
      return "\\[\\[" .. choice .. "\\]\\]"
    end)
  end)
end, { desc = "[P]Obsidian: Find notes by tag" })

-- Strip AVAILABLE hint comments from frontmatter
keymap("n", "<leader>zc", function()
  -- Delete whole-line AVAILABLE comments (above-field format)
  vim.cmd([[silent! g/^\s*#\s*AVAILABLE:/d]])
  -- Strip inline AVAILABLE comments (after-field format)
  vim.cmd([[silent! %s/\s*#\s*AVAILABLE:.*$//]])
  vim.cmd("write")
  vim.notify("Stripped AVAILABLE hints", vim.log.levels.INFO)
end, { desc = "[P]Obsidian: Clean AVAILABLE hints from frontmatter" })

-- Create a new note in 0-Inbox/ and expand luasnip ;note-template
keymap("n", "<leader>zN", function()
  require("config.obsidian").new_inbox_note()
end, { desc = "[P]Obsidian: New note in inbox (snippet)" })

-- Review created notes in 0-Inbox/ (skips raw resources)
keymap("n", "<leader>zr", function()
  require("config.obsidian").review_inbox()
end, { desc = "[P]Obsidian: Review inbox (created notes only)" })

-- Move current inbox buffer to Zettelkasten/ and close it
keymap("n", "<leader>zk", function()
  require("config.obsidian").move_to_zettelkasten()
end, { desc = "[P]Obsidian: Move buffer to Zettelkasten/" })

-- Delete current inbox buffer file (with confirmation)
keymap("n", "<leader>zx", function()
  require("config.obsidian").delete_from_inbox()
end, { desc = "[P]Obsidian: Delete buffer from inbox" })

-- Publish: Zettelkasten/ -> Notes/<hub>/ via the `op` script
keymap("n", "<leader>zp", function()
  require("config.obsidian").publish()
end, { desc = "[P]Obsidian: Publish (Zettelkasten -> Notes/<hub>)" })

-- Pick an image from vault Assets/ and insert as ![[filename]] at cursor
keymap({ "n", "i" }, "<leader>zi", function()
  local vault = vim.fn.expand("~/Obsidian/second-brain")
  local assets = vault .. "/Assets"
  local exts = { "png", "jpg", "jpeg", "gif", "webp", "avif", "svg" }
  local items = {}
  for _, ext in ipairs(exts) do
    local matches = vim.fn.globpath(assets, "**/*." .. ext, false, true)
    for _, f in ipairs(matches) do
      table.insert(items, {
        text = vim.fn.fnamemodify(f, ":t"),
        file = f,
      })
    end
  end
  if #items == 0 then
    vim.notify("No images in Assets/", vim.log.levels.WARN)
    return
  end
  Snacks.picker.pick({
    title = "Embed image",
    items = items,
    format = function(item)
      return { { item.text } }
    end,
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      vim.api.nvim_put({ "![[" .. item.text .. "]]" }, "c", true, true)
    end,
  })
end, { desc = "[P]Obsidian: Insert image embed from Assets" })

-- Copy hub name to clipboard (for pasting into frontmatter)
keymap("n", "<leader>zH", function()
  local vault = vim.fn.expand("~/Obsidian/second-brain")
  local hub_dirs = vim.fn.globpath(vault .. "/Notes", "*", false, true)
  local hubs = {}
  for _, d in ipairs(hub_dirs) do
    if vim.fn.isdirectory(d) == 1 then
      table.insert(hubs, vim.fn.fnamemodify(d, ":t"))
    end
  end
  vim.ui.select(hubs, { prompt = "Copy hub:" }, function(choice)
    if not choice then
      return
    end
    vim.fn.setreg("+", choice)
    vim.notify("Copied hub: " .. choice, vim.log.levels.INFO)
  end)
end, { desc = "[P]Obsidian: Copy hub to clipboard" })

-- Copy tag name to clipboard (for pasting into frontmatter)
keymap("n", "<leader>zT", function()
  local vault = vim.fn.expand("~/Obsidian/second-brain")
  local tag_files = vim.fn.globpath(vault .. "/0-Tags", "*.md", false, true)
  local tags = {}
  for _, f in ipairs(tag_files) do
    table.insert(tags, vim.fn.fnamemodify(f, ":t:r"))
  end
  vim.ui.select(tags, { prompt = "Copy tag:" }, function(choice)
    if not choice then
      return
    end
    local formatted = '"[[' .. choice .. ']]"'
    vim.fn.setreg("+", formatted)
    vim.notify("Copied tag: " .. formatted, vim.log.levels.INFO)
  end)
end, { desc = "[P]Obsidian: Copy tag to clipboard" })

-- Search vault by date in frontmatter
keymap("n", "<leader>zd", function()
  vault_frontmatter_search("date", "Date (YYYY-MM-DD): ", function(q)
    return "^date:\\n  - " .. q
  end, true)
end, { desc = "[P]Obsidian: Find notes by date" })

-- Search vault by URL in frontmatter
keymap("n", "<leader>zu", function()
  vault_frontmatter_search("url", "URL contains: ", function(q)
    return "^urls:\\n  - .*" .. q
  end, true)
end, { desc = "[P]Obsidian: Find notes by URL" })

-- Grep within a vault tag folder or hub
keymap("n", "<leader>zs", function()
  local vault = vim.fn.expand("~/Obsidian/second-brain")
  local dirs = vim.fn.globpath(vault .. "/Notes", "*", false, true)
  table.insert(dirs, 1, vault .. "/0-Tags")
  table.insert(dirs, 2, vault .. "/0-Hubs")
  table.insert(dirs, 3, vault .. "/0-Inbox")

  local labels = {}
  for _, d in ipairs(dirs) do
    table.insert(labels, vim.fn.fnamemodify(d, ":t"))
  end

  vim.ui.select(labels, { prompt = "Search in:" }, function(choice, idx)
    if not choice then
      return
    end
    Snacks.picker.grep({ dirs = { dirs[idx] } })
  end)
end, { desc = "[P]Obsidian: Scoped grep by tag/hub" })

-------------------------------------------------------------------------------
--                           Tasks Folder Navigation
-------------------------------------------------------------------------------

-- Open local project tasks folder (if exists)
keymap("n", "<leader>ft", function()
  local cwd = vim.fn.getcwd()
  local tasks_path = cwd .. "/tasks"

  if vim.fn.isdirectory(tasks_path) == 1 then
    require("snacks").picker.files({ cwd = tasks_path })
  else
    vim.notify("No tasks/ folder in current directory", vim.log.levels.WARN)
  end
end, { desc = "[P]Open local tasks folder" })

-- Open global Obsidian Tasks folder
keymap("n", "<leader>fT", function()
  local obsidian_tasks = vim.fn.expand(
    "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/second-brain/Tasks"
  )

  if vim.fn.isdirectory(obsidian_tasks) == 1 then
    require("snacks").picker.files({ cwd = obsidian_tasks })
  else
    vim.notify("Obsidian Tasks folder not found", vim.log.levels.ERROR)
  end
end, { desc = "[P]Open Obsidian Tasks folder" })

-------------------------------------------------------------------------------
--                           Folding section
-------------------------------------------------------------------------------

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
--
-- Use <CR> to fold when in normal mode
-- To see help about folds use `:help fold`
keymap("n", "<CR>", function()
  -- Get the current line number
  local line = vim.fn.line(".")
  -- Get the fold level of the current line
  local foldlevel = vim.fn.foldlevel(line)
  if foldlevel == 0 then
    vim.notify("No fold found", vim.log.levels.INFO)
  else
    vim.cmd("normal! za")
    vim.cmd("normal! zz") -- center the cursor line on screen
  end
end, { desc = "[P]Toggle fold" })

local function set_foldmethod_expr()
  vim.opt.foldmethod = "expr"
  vim.opt.foldexpr = "v:lua.require'lazyvim.util'.treesitter.foldexpr()"
  vim.opt.foldtext = ""
end

--
-- UNFOLDING: Keymap for unfolding markdown headings of level 2 or above
-- Changed all the markdown folding and unfolding keymaps from <leader>mfj to
-- zj, zk, zl, z; and zu respectively lamw25wmal
keymap("n", "zu", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- Reloads the file to reflect the changes
  vim.cmd("edit!")
  vim.cmd("normal! zR") -- Unfold all headings
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Unfold all headings level 2 or above" })

--
-- FOLDING: gk jummps to the markdown heading above and then folds it
-- zi by default toggles folding, but I don't need it lamw25wmal
keymap("n", "zi", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- Difference between normal and normal!
  -- - `normal` executes the command and respects any mappings that might be defined.
  -- - `normal!` executes the command in a "raw" mode, ignoring any mappings.
  vim.cmd("normal gk")
  -- This is to fold the line under the cursor
  vim.cmd("normal! za")
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold the heading cursor currently on" })

--
-- FOLDING: Keymap for folding markdown headings of level 1 or above
keymap("n", "zj", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  set_foldmethod_expr() -- Ensure foldmethod is set
  vim.opt.foldlevel = 0 -- Fold everything
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 1 or above" })

--
-- FOLDING: Keymap for folding markdown headings of level 2 or above
-- I know, it reads like "madafaka" but "k" for me means "2"
keymap("n", "zk", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  set_foldmethod_expr() -- Ensure foldmethod is set
  vim.opt.foldlevel = 1 -- Fold level 2 and above
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 2 or above" })

--
-- FOLDING: Keymap for folding markdown headings of level 3 or above
keymap("n", "zl", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  set_foldmethod_expr() -- Ensure foldmethod is set
  vim.opt.foldlevel = 2 -- Fold level 3 and above
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 3 or above" })

--
-- FOLDING: Keymap for folding markdown headings of level 4 or above
keymap("n", "z;", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  set_foldmethod_expr() -- Ensure foldmethod is set
  vim.opt.foldlevel = 3 -- Fold level 4 and above
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 4 or above" })
