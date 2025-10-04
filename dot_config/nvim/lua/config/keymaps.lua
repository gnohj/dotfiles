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

-- increment/decrement numbers
keymap("n", "<leader>+", "<C-a>", { desc = "[P]Increment number" })
keymap("n", "<leader>=", "<C-x>", { desc = "[P]Decrement number" })

keymap("n", "<leader><space>", "<cmd>e #<cr>", { desc = "[P]Alternate buffer" })

-- Toggle zen mode manually (overrides auto zen)
keymap("n", "<leader>uz", function()
  -- Toggle manual control flag
  vim.g.zen_manual_control = not vim.g.zen_manual_control

  -- Toggle zen mode
  require("snacks").zen()

  -- Notify user of state
  if vim.g.zen_manual_control then
    vim.notify("Zen: Manual control enabled", vim.log.levels.INFO)
  else
    vim.notify("Zen: Auto mode re-enabled", vim.log.levels.INFO)
  end
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

-- Quit or exit neovim, easier than to do <leader>qq
keymap({ "n", "v", "i" }, "<C-space>", "<cmd>wqa<cr>", { desc = "[P]Quit All" })

keymap(
  { "n", "v", "i" },
  "<M-r>",
  "<Nop>",
  { desc = "[P] Disabled No operation for <M-r>" }
)
-- Page scrolling with Alt+d and Alt+u
keymap("n", "<M-d>", "<C-d>", { desc = "Page down" })
keymap("n", "<M-u>", "<C-u>", { desc = "Page up" })

-- If you also want these to work in visual mode
keymap("v", "<M-d>", "<C-d>", { desc = "Page down" })
keymap("v", "<M-u>", "<C-u>", { desc = "Page up" })

keymap({ "n", "v", "i" }, "<M-y>", function()
  -- require("noice").cmd("history")
  require("noice").cmd("all")
end, { desc = "[P]Noice History" })

-- HACK: View and paste images in Neovim like in Obsidian
-- Paste images
-- The <M-j> keymap is defined in plugins/img-clip.lua to ensure proper loading

-- Disable lazygit which is enabled default by LazyVim
-- map("n", "<leader>gg", function() Snacks.lazygit( { cwd = LazyVim.root.git() }) end, { desc = "Lazygit (Root Dir)" })
-- map("n", "<leader>gG", function() Snacks.lazygit() end, { desc = "Lazygit (cwd)" })
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
  "<leader>zk",
  ":!mv '%:p' /Users/gnohj/Obsidian/second-brain/Zettelkasten/<cr>:bd<cr>",
  { desc = "[P]Obsidian: Move file to Zettelkasten" }
)
-- delete file in current buffer
keymap(
  "n",
  "<leader>zdd",
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
