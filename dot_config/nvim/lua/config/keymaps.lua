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

keymap("n", "<C-q>", "<cmd>wqa<cr>", { desc = "[P]Save and quit all" })

-- Restart Neovim (nvim 0.12+)
keymap("n", "<leader>qr", "<cmd>restart<cr>", { desc = "[P]Restart Neovim" })

keymap("n", "<leader>tn", function()
  local current = vim.opt.number:get()
  vim.opt.number = not current
  vim.opt.relativenumber = not current
end, { desc = "[P]Toggle relative line numbers" })

keymap("n", "<leader>tN", function()
  vim.opt.number = not vim.opt.number:get()

  vim.opt.relativenumber = false
end, { desc = "[P]Toggle absolute line numbers" })

keymap("n", "<M-o>", "<C-o>", { desc = "[P]Jump backward in jump list" })
keymap("n", "<M-i>", "<C-i>", { desc = "[P]Jump forward in jump list" })

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
  local full_path = vim.fn.expand("%:p")
  local display_path

  -- Format: codediff:///repo/path///commit_hash/relative/path
  if full_path:match("^codediff://") then
    -- Extract path after ///commit_hash/ (40 hex chars)
    local relative_path = full_path:match("///[a-f0-9]+/(.+)$")
    display_path = relative_path or full_path
  else
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
  local path = vim.fn.getreg("+"):gsub("%s+", "")
  if path == "" then
    vim.notify("Clipboard is empty", vim.log.levels.WARN)
    return
  end

  local expanded = path:gsub("^~", vim.fn.expand("$HOME"))

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

-- Lazygit: re-bind <leader>gg with dynamic config so the inferno-monorepo
-- overlay (inferno.yml) is picked up at open-time instead of load-time.
pcall(vim.keymap.del, "n", "<leader>gg")
pcall(vim.keymap.del, "n", "<leader>gG")
local function lazygit_open()
  local cfg = vim.fn.expand("~/.config/lazygit/config.yml")
  local origin = vim.fn.system("git remote get-url origin 2>/dev/null"):gsub("%s+$", "")
  if origin:find("inferno-monorepo") then
    cfg = cfg .. "," .. vim.fn.expand("~/.config/lazygit/inferno.yml")
  end
  Snacks.lazygit.open({ args = { "--use-config-file", cfg } })
end
keymap("n", "<leader>gg", lazygit_open, { desc = "Lazygit" })

-- Grugfar
keymap(
  { "v" },
  "<leader>s1",
  '<cmd>lua require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })<cr>',
  { noremap = true, silent = true }
)

-- Package Info
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

-- GitHub Browse (Upstream Branch)
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

-- Open the GitHub PR for the current branch in a browser. If no PR exists
-- for the branch, fall back to the repo's open-PRs list (sorted by updated).
keymap("n", "<leader>gx", function()
  local cwd = vim.fn.expand("%:p:h")
  if cwd == "" then
    cwd = vim.fn.getcwd()
  end
  -- Fallback: open the repo's open-PRs list (sorted by recently-updated).
  local function open_pr_list()
    vim.fn.jobstart(
      { "gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner" },
      {
        cwd = cwd,
        stdout_buffered = true,
        on_stdout = function(_, data)
          local repo = (data and data[1] or ""):gsub("%s+$", "")
          vim.schedule(function()
            if repo == "" then
              vim.notify(
                "No PR for branch and could not resolve repo",
                vim.log.levels.WARN
              )
              return
            end
            local url = "https://github.com/"
              .. repo
              .. "/pulls?q=sort%3Aupdated-desc+is%3Apr+is%3Aopen"
            vim.ui.open(url)
            vim.notify(
              "No PR for branch — opened repo PRs list",
              vim.log.levels.INFO
            )
          end)
        end,
      }
    )
  end

  -- Detached HEAD (e.g. a review worktree) has no current branch. Recover the
  -- branch from the remote ref pointing at HEAD (remote-agnostic) and open
  -- that branch's PR before falling back to the repo PRs list.
  local function try_detached_then_list()
    local sym = vim.fn.systemlist({ "git", "-C", cwd, "symbolic-ref", "-q", "--short", "HEAD" })
    if #sym > 0 and sym[1] ~= "" then
      open_pr_list()
      return
    end
    local refs = vim.fn.systemlist({
      "git", "-C", cwd, "branch", "--points-at", "HEAD", "-r", "--format=%(refname:short)",
    })
    local branch
    for _, r in ipairs(refs) do
      r = r:gsub("%s+$", "")
      if r ~= "" and not r:match("/HEAD$") then
        branch = r:gsub("^[^/]+/", "")
        break
      end
    end
    if not branch or branch == "" then
      open_pr_list()
      return
    end
    vim.fn.jobstart({ "gh", "pr", "view", branch, "--web" }, {
      cwd = cwd,
      on_exit = function(_, c2)
        if c2 == 0 then
          return
        end
        open_pr_list()
      end,
    })
  end

  vim.fn.jobstart({ "gh", "pr", "view", "--web" }, {
    cwd = cwd,
    on_exit = function(_, code)
      if code == 0 then
        return
      end
      try_detached_then_list()
    end,
  })
end, { desc = "[P]Open GitHub PR for current branch (or repo PRs list)" })

-- Open the markdown link/image under the cursor in the macOS default app
-- (image → Preview, HTML → browser, PDF → Preview, etc). Falls back to the
-- current buffer's file if no `[text](target)` link is at the cursor.
-- Relative paths are resolved against the buffer's directory so
-- `../Notes-Assets/foo.png` from a vault note opens correctly.
keymap("n", "<leader>gX", function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed for string.find
  local target

  -- Walk all [text](target) and ![text](target) matches; pick the one
  -- whose span contains the cursor column.
  local search_start = 1
  while true do
    local s, e, t = line:find("!?%[[^%]]*%]%(([^)]+)%)", search_start)
    if not s then
      break
    end
    if col >= s and col <= e then
      target = t
      break
    end
    search_start = e + 1
  end

  if target then
    -- Resolve relative paths against the buffer's directory.
    if not target:match("^%w+://") and not target:match("^/") then
      local buf_dir = vim.fn.expand("%:p:h")
      target = vim.fn.fnamemodify(buf_dir .. "/" .. target, ":p")
    end
  else
    -- No markdown link under cursor — fall back to the buffer file.
    target = vim.fn.expand("%:p")
    if target == "" then
      vim.notify(
        "No file in buffer and no link under cursor",
        vim.log.levels.WARN
      )
      return
    end
  end

  vim.ui.open(target)
end, { desc = "[P]Open link under cursor / current file externally" })

-- Toggle Copilot Virtual Text
keymap(
  "n",
  "<leader>a",
  ":lua require('copilot.suggestion').toggle_auto_trigger()<CR>",
  {
    silent = true,
    noremap = true,
    desc = "[P]Copilot: toggle virtual text suggestions",
  }
)

-- Obsidian
-- strip date from note title and replace dashes with spaces
-- must have cursor on title
keymap(
  "n",
  "<leader>zf",
  ":s/\\(# \\)[^_]*_/\\1/ | s/-/ /g<cr>",
  { desc = "[P]Obsidian: Format note title" }
)
-- for review workflow
keymap("n", "<M-k>", function()
  local vault = require("config.obsidian").vault_root()
  local file = vim.fn.expand("%:p")
  local dest = vault .. "/Notes-Publish"
  vim.fn.mkdir(dest, "p")
  vim.cmd(("silent !mv %s %s"):format(vim.fn.shellescape(file), vim.fn.shellescape(dest .. "/")))
  vim.cmd("bd")
end, { desc = "[P]Obsidian: Move file to Notes-Publish" })
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

keymap("n", "<leader>zl", function()
  local vault = require("config.obsidian").vault_root()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
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

keymap("n", "<leader>zb", function()
  local vault = require("config.obsidian").vault_root()
  local name = vim.fn.expand("%:t:r")
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
  local vault = require("config.obsidian").vault_root()

  local function run_search(query)
    local pattern = pattern_fn(query)
    local flag = multiline and "-U -l" or "-l"
    -- --no-ignore-vcs: vault `.gitignore` excludes /Projects/, but project
    -- notes can carry vault tags (`;project-note-tagged`) and should appear
    -- in tag/hub/date/url searches.
    local results = vim.fn.systemlist(
      "rg --no-ignore-vcs " .. flag .. " '" .. pattern .. "' " .. vim.fn.shellescape(vault) .. " 2>/dev/null"
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

keymap("n", "<leader>zh", function()
  local vault = require("config.obsidian").vault_root()
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

-- Filters out `_*.md` files (e.g. _hubs.md) so only true tag markers appear.
keymap("n", "<leader>zt", function()
  local vault = require("config.obsidian").vault_root()
  local all_files = vim.fn.globpath(vault .. "/Notes-Meta", "*.md", false, true)
  local tags = {}
  for _, f in ipairs(all_files) do
    local name = vim.fn.fnamemodify(f, ":t:r")
    if not name:match("^_") then
      table.insert(tags, name)
    end
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

keymap("n", "<leader>zc", function()
  -- Delete whole-line AVAILABLE comments (above-field format)
  vim.cmd([[silent! g/^\s*#\s*AVAILABLE:/d]])
  -- Strip inline AVAILABLE comments (after-field format)
  vim.cmd([[silent! %s/\s*#\s*AVAILABLE:.*$//]])
  vim.cmd("write")
  vim.notify("Stripped AVAILABLE hints", vim.log.levels.INFO)
end, { desc = "[P]Obsidian: Clean AVAILABLE hints from frontmatter" })

-- Create a new note in Notes-Inbox/ and expand luasnip ;note-template
keymap("n", "<leader>zN", function()
  require("config.obsidian").new_inbox_note()
end, { desc = "[P]Obsidian: New note in inbox (snippet)" })

-- Create a new project note in cwd's closest `notes/` (or cwd if absent)
-- and expand luasnip ;project-note-tagged
keymap("n", "<leader>zn", function()
  require("config.obsidian").new_project_note()
end, { desc = "[P]Obsidian: New project note (cwd notes/ or root)" })

-- Review created notes in Notes-Inbox/ (skips raw resources)
keymap("n", "<leader>zr", function()
  require("config.obsidian").review_inbox()
end, { desc = "[P]Obsidian: Review inbox (created notes only)" })

keymap("n", "<leader>zk", function()
  require("config.obsidian").move_to_publish()
end, { desc = "[P]Obsidian: Move buffer to Notes-Publish/" })

-- Delete current inbox buffer file (with confirmation)
keymap("n", "<leader>zx", function()
  require("config.obsidian").delete_from_inbox()
end, { desc = "[P]Obsidian: Delete buffer from inbox" })

-- Publish: Notes-Publish/ -> Notes/<hub>/ via the `op` script
keymap("n", "<leader>zp", function()
  require("config.obsidian").publish()
end, { desc = "[P]Obsidian: Publish (Notes-Publish -> Notes/<hub>)" })

-- Open picker for incomplete todos across all `.md` files under Projects/.
-- Greps `- [ ]` (allowing leading whitespace for indented sub-todos) and on
-- selection opens the file at the matching line. Uses ripgrep + snacks picker.
keymap("n", "<leader>zo", function()
  local vault = require("config.obsidian").vault_root()
  local projects_root = vault .. "/Projects"
  if vim.fn.isdirectory(projects_root) ~= 1 then
    vim.notify("No Projects/ directory in vault", vim.log.levels.WARN)
    return
  end
  local results = vim.fn.systemlist(
    "rg -n --no-heading -tmd '^\\s*- \\[ \\]' "
      .. vim.fn.shellescape(projects_root)
      .. " 2>/dev/null"
  )
  if #results == 0 then
    vim.notify("No open todos in Projects/", vim.log.levels.INFO)
    return
  end
  local items = {}
  local strip = projects_root .. "/"
  for _, line in ipairs(results) do
    local file, lnum, content = line:match("^([^:]+):(%d+):(.*)$")
    if file then
      -- Show path relative to Projects/ so it starts with `<project>/...`
      -- rather than the full absolute path. Plain prefix strip — gsub would
      -- interpret dashes (e.g. `second-brain`) as Lua pattern metacharacters.
      local rel = file
      if rel:sub(1, #strip) == strip then
        rel = rel:sub(#strip + 1)
      end
      table.insert(items, {
        text = rel .. ":" .. lnum .. " " .. (content or ""),
        file = file,
        pos = { tonumber(lnum), 0 },
      })
    end
  end
  Snacks.picker.pick({
    title = "Project Todos",
    items = items,
    format = function(item)
      return { { item.text } }
    end,
    confirm = function(picker, item)
      picker:close()
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
      pcall(vim.api.nvim_win_set_cursor, 0, item.pos)
    end,
  })
end, { desc = "[P]Obsidian: Project todos picker" })

-- Pick an image from vault Notes-Assets/ and insert as ![[filename]] at cursor
keymap({ "n", "i" }, "<leader>zi", function()
  local vault = require("config.obsidian").vault_root()
  local assets = vault .. "/Notes-Assets"
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
    vim.notify("No images in Notes-Assets/", vim.log.levels.WARN)
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
end, { desc = "[P]Obsidian: Insert image embed from Notes-Assets" })

keymap("n", "<leader>zH", function()
  local vault = require("config.obsidian").vault_root()
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

-- Filters out `_*.md` files (e.g. _hubs.md) so only true tag markers appear.
keymap("n", "<leader>zT", function()
  local vault = require("config.obsidian").vault_root()
  local all_files = vim.fn.globpath(vault .. "/Notes-Meta", "*.md", false, true)
  local tags = {}
  for _, f in ipairs(all_files) do
    local name = vim.fn.fnamemodify(f, ":t:r")
    if not name:match("^_") then
      table.insert(tags, name)
    end
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

keymap("n", "<leader>zd", function()
  vault_frontmatter_search("date", "Date (YYYY-MM-DD): ", function(q)
    return "^date:\\n  - " .. q
  end, true)
end, { desc = "[P]Obsidian: Find notes by date" })

keymap("n", "<leader>zu", function()
  vault_frontmatter_search("url", "URL contains: ", function(q)
    return "^urls:\\n  - .*" .. q
  end, true)
end, { desc = "[P]Obsidian: Find notes by URL" })

keymap("n", "<leader>zs", function()
  local vault = require("config.obsidian").vault_root()
  local dirs = vim.fn.globpath(vault .. "/Notes", "*", false, true)
  table.insert(dirs, 1, vault .. "/Notes-Meta")
  table.insert(dirs, 2, vault .. "/Notes-Meta")
  table.insert(dirs, 3, vault .. "/Notes-Inbox")

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

-- Folding section

-- HACK: Fold markdown headings in Neovim with a keymap
-- https://youtu.be/EYczZLNEnIY
keymap("n", "<CR>", function()
  local line = vim.fn.line(".")
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

--
-- Right mouse drag → visual-select + auto-copy to the system clipboard,
-- mirroring the tmux right-drag-to-copy binding. Inside nvim the mouse is
-- owned by nvim (mouse=a), so tmux passes the event through and we replicate
-- the behavior here. clipboard=unnamedplus means a plain `y` lands on the
-- macOS clipboard. mousemodel=extend (options.lua) frees the right button.
keymap({ "n", "v" }, "<RightMouse>", "<LeftMouse>", { desc = "[P]Right-drag: position cursor" })
keymap({ "n", "v" }, "<RightDrag>", "<LeftDrag>", { desc = "[P]Right-drag: extend selection" })
keymap("v", "<RightRelease>", "y", { desc = "[P]Right-drag: copy selection to clipboard" })
