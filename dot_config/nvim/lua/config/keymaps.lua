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

-- Restore gd to LSP go to definition (overrides illuminate/search highlighting)
keymap("n", "gd", vim.lsp.buf.definition, { desc = "Go to Definition" })

-- Quit Neovim instance with save and quit all
keymap("n", "<C-q>", "<cmd>wqa<cr>", { desc = "[P]Save and quit all" })

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
keymap("n", "<leader>uz", function()
  require("config.auto-zen").toggle_manual()
end, { desc = "[P]Toggle Zen Mode (manual)" })

local function insertFullPath()
  local full_path = vim.fn.expand("%:p") -- Get the full file path
  local display_path = full_path:gsub(vim.fn.expand("$HOME"), "~") -- Replace $HOME with ~
  vim.fn.setreg("+", display_path)
  vim.notify("Copied to clipboard: " .. display_path, vim.log.levels.INFO)
end

keymap(
  "n",
  "<leader>fy",
  insertFullPath,
  { silent = true, noremap = true, desc = "[P]Copy full path" }
)

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

-- HACK: View and paste images in Neovim like in Obsidian
-- Paste images
-- The <M-j> keymap is defined in plugins/img-clip.lua to ensure proper loading

-- Disable lazygit which is enabled default by LazyVim
vim.keymap.del("n", "<leader>gg")
vim.keymap.del("n", "<leader>gG")

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
--                           DiffView
-------------------------------------------------------------------------------

keymap("n", "<leader><leader>m", function()
  if next(require("diffview.lib").views) == nil then
    vim.cmd("DiffviewOpen origin/master...HEAD")
  else
    vim.cmd("DiffviewClose")
  end
end, { desc = "[P]DiffView: Toggle master branch diff" })

keymap("n", "<leader><leader>d", function()
  if next(require("diffview.lib").views) == nil then
    vim.cmd("DiffviewOpen origin/develop...HEAD")
  else
    vim.cmd("DiffviewClose")
  end
end, { desc = "[P]DiffView: Toggle develop branch diff" })

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

-------------------------------------------------------------------------------
--                  Tiny Code Action / Fastaction
-------------------------------------------------------------------------------
keymap(
  "n",
  "<leader>ca",
  function()
    local group =
      vim.api.nvim_create_augroup("TinyCodeActionEscape", { clear = true })

    vim.api.nvim_create_autocmd("BufNew", {
      group = group,
      once = true,
      callback = function(event)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(event.buf) then
            vim.keymap.set("n", "<esc>", function()
              -- Close all floating windows
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_is_valid(win) then
                  local config = vim.api.nvim_win_get_config(win)
                  if config.relative ~= "" then -- It's a floating window
                    pcall(vim.api.nvim_win_close, win, true)
                  end
                end
              end
            end, {
              buffer = event.buf,
              silent = true,
              desc = "Close all floating windows",
            })
          end
        end)
      end,
    })

    require("tiny-code-action").code_action()
  end,
  { noremap = true, silent = true, desc = "Code action with escape support" }
)

-------------------------------------------------------------------------------
--                           OpenCode AI Assistant
-------------------------------------------------------------------------------

-- Visual mode: Quick prompts with selection
keymap("v", "<leader>ot", function()
  vim.cmd('normal! "vy')
  local selection = vim.fn.getreg("v")
  require("opencode.api").run(
    "Add tests for this code:\n\n```\n" .. selection .. "\n```"
  )
end, { desc = "[P]OpenCode: Add tests for selection" })

keymap("v", "<leader>of", function()
  vim.cmd('normal! "vy')
  local selection = vim.fn.getreg("v")
  require("opencode.api").run("Fix this code:\n\n```\n" .. selection .. "\n```")
end, { desc = "[P]OpenCode: Fix selected code" })

keymap("v", "<leader>oO", function()
  vim.cmd('normal! "vy')
  local selection = vim.fn.getreg("v")
  require("opencode.api").run(
    "Optimize this code for performance and readability:\n\n```\n"
      .. selection
      .. "\n```"
  )
end, { desc = "[P]OpenCode: Optimize selection" })

-- Normal mode: Context-aware prompts
keymap("n", "<leader>oe", function()
  require("opencode.context").load()
  require("opencode.api").run("Explain the code at cursor and its context")
end, { desc = "[P]OpenCode: Explain code at cursor" })

keymap("n", "<leader>or", function()
  require("opencode.context").load()
  require("opencode.api").run(
    "Review the current file for correctness and readability"
  )
end, { desc = "[P]OpenCode: Review file" })

-- Mode switching
keymap("n", "<leader>om", function()
  require("opencode.api").switch_mode()
end, { desc = "[P]OpenCode: Switch mode (build/plan)" })

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
  local obsidian_tasks = vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/second-brain/Tasks")

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
  -- These are lazyvim.org defaults but setting them just in case a file
  -- doesn't have them set
  if vim.fn.has("nvim-0.10") == 1 then
    vim.opt.foldmethod = "expr"
    vim.opt.foldexpr = "v:lua.require'lazyvim.util'.treesitter.foldexpr()"
    vim.opt.foldtext = ""
  else
    vim.opt.foldmethod = "indent"
    vim.opt.foldtext = "v:lua.require'lazyvim.util'.ui.foldtext()"
  end
  -- vim.opt.foldlevel = 99 -- Remove this line.  We'll set foldlevel in the keymaps.
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
