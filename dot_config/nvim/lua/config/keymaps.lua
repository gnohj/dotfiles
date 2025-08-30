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

local function insertFullPath()
  local full_path = vim.fn.expand("%:p") -- Get the full file path
  vim.fn.setreg("+", full_path:gsub(vim.fn.expand("$HOME"), "~")) -- Replace $HOME with ~
end

keymap(
  "n",
  "<leader>fy",
  insertFullPath,
  { silent = true, noremap = true, desc = "[P]Copy full path" }
)

-- Quit or exit neovim, easier than to do <leader>qq
keymap({ "n", "v", "i" }, "<C-q>", "<cmd>wqa<cr>", { desc = "[P]Quit All" })
-- Quit or exit neovim, easier than to do <leader>qq
keymap({ "n", "v", "i" }, "<C-q>", "<cmd>wqa<cr>", { desc = "[P]Quit All" })

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
-- I tried using <C-v> but duh, that's used for visual block mode
keymap({ "n", "i" }, "<M-p>", function()
  local pasted_image = require("img-clip").paste_image()
  if pasted_image then
    -- "Update" saves only if the buffer has been modified since the last save
    vim.cmd("silent! update")
    -- Get the current line
    local line = vim.api.nvim_get_current_line()
    -- Move cursor to end of line
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], #line })
    -- I reload the file, otherwise I cannot view the image after pasted
    vim.cmd("edit!")
  end
end, { desc = "[P]Paste image from system clipboard" })

-- Disable lazygit which is enabled default by LazyVim
-- map("n", "<leader>gg", function() Snacks.lazygit( { cwd = LazyVim.root.git() }) end, { desc = "Lazygit (Root Dir)" })
-- map("n", "<leader>gG", function() Snacks.lazygit() end, { desc = "Lazygit (cwd)" })
vim.keymap.del("n", "<leader>gg")
vim.keymap.del("n", "<leader>gG")

-------------------------------------------------------------------------------
--                           Chezmoi
-------------------------------------------------------------------------------
vim.keymap.set("n", "<leader>cz", function()
  local chezmoi_source = vim.fn.system("chezmoi source-path"):gsub("\n", "")
  Snacks.picker.files({
    cwd = chezmoi_source,
    title = "Chezmoi Source Files",
    hidden = true,
  })
end, { desc = "Edit chezmoi source files" })

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
--                           Logsitter
-------------------------------------------------------------------------------
keymap(
  "n",
  "<leader>tc",
  "<cmd> lua require('logsitter').log()<cr>",
  { desc = "[P]Turbo Console Log" }
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
--                           TMUX New Pane Peek
-------------------------------------------------------------------------------
-- local function tmux_pane_function(dir)
--   -- NOTE: variable that controls the auto-cd behavior
--   local auto_cd_to_new_dir = true
--   -- NOTE: Variable to control pane direction: 'right' or 'bottom'
--   -- If you modify this, make sure to also modify TMUX_PANE_DIRECTION in the
--   -- zsh-vi-mode section on the .zshrc file
--   -- Also modify this in your tmux.conf file if you want it to work when in tmux
--   -- copy-mode
--   local pane_direction = vim.g.tmux_pane_direction or "right"
--   -- NOTE: Below, the first number is the size of the pane if split horizontally,
--   -- the 2nd number is the size of the pane if split vertically
--   local pane_size = (pane_direction == "right") and 90 or 15
--   local move_key = (pane_direction == "right") and "C-l" or "C-k"
--   local split_cmd = (pane_direction == "right") and "-h" or "-v"
--   -- if no dir is passed, use the current file's directory
--   local file_dir = dir or vim.fn.expand("%:p:h")
--   -- Simplified this, was checking if a pane existed
--   local has_panes = vim.fn.system("tmux list-panes | wc -l"):gsub("%s+", "")
--     ~= "1"
--   -- Check if the current pane is zoomed (maximized)
--   local is_zoomed = vim.fn
--     .system("tmux display-message -p '#{window_zoomed_flag}'")
--     :gsub("%s+", "") == "1"
--   -- Escape the directory path for shell
--   local escaped_dir = file_dir:gsub("'", "'\\''")
--   -- If any additional pane exists
--   if has_panes then
--     if is_zoomed then
--       -- Compare the stored pane directory with the current file directory
--       if auto_cd_to_new_dir and vim.g.tmux_pane_dir ~= escaped_dir then
--         -- If different, cd into the new dir
--         vim.fn.system(
--           "tmux send-keys -t :.+ 'cd \"" .. escaped_dir .. "\"' Enter"
--         )
--         -- Update the stored directory to the new one
--         vim.g.tmux_pane_dir = escaped_dir
--       end
--       -- If zoomed, unzoom and switch to the correct pane
--       vim.fn.system("tmux resize-pane -Z")
--       vim.fn.system("tmux send-keys " .. move_key)
--     else
--       -- If not zoomed, zoom current pane
--       vim.fn.system("tmux resize-pane -Z")
--     end
--   else
--     -- Store the initial directory in a Neovim variable
--     if vim.g.tmux_pane_dir == nil then
--       vim.g.tmux_pane_dir = escaped_dir
--     end
--     -- If no pane exists, open it with zsh and DISABLE_PULL variable
--     vim.fn.system(
--       "tmux split-window "
--         .. split_cmd
--         .. " -l "
--         .. pane_size
--         .. " 'cd \""
--         .. escaped_dir
--         .. "\" && DISABLE_PULL=1 zsh'"
--     )
--     vim.fn.system("tmux send-keys " .. move_key)
--     -- Resolve zsh-vi-mode issue for first-time pane
--     vim.fn.system("tmux send-keys Escape i")
--   end
-- end

-------------------------------------------------------------------------------
--                           Obsidian
-------------------------------------------------------------------------------

-- If I execute the function without an argument, it will open the dir where the current file lives
-- keymap({ "n", "v", "i" }, "<M-f>", function()
--   tmux_pane_function("/Users/gnohj/Obsidian/second-brain")
-- end, { desc = "[P]Terminal on tmux pane" })

-- If I execute the function without an argument, it will open the dir where the current file lives
-- vim.keymap.set({ "n", "v", "i" }, "<M-o", function()
--   tmux_pane_function("/Users/gnohj/Obsidian/second-brain")
-- end, { desc = "[P]Terminal Notes on tmux pane" })

-- >>> oo # from shell, navigate to vault (optional)
--
-- # NEW NOTE
-- >>> on "Note Name" # call my "obsidian new note" shell script (~/bin/on)
-- >>>
-- >>> ))) <leader>on # inside vim now, format note as template
-- >>> ))) # add tag, e.g. fact / blog / video / etc..
-- >>> ))) # add hubs, e.g. [[python]], [[machine-learning]], etc...
-- >>> ))) <leader>of # format title
--
-- # END OF DAY/WEEK REVIEW
-- >>> or # review notes in inbox
-- >>>
-- >>> ))) <leader>ok # inside vim now, move to zettelkasten
-- >>> ))) <leader>odd # or delete
-- >>>
-- >>> og # organize saved notes from zettelkasten into notes/[tag] folders
-- >>> ou # sync local with Notion

-- navigate to vault
keymap(
  "n",
  "<leader>oo",
  ":cd /Users/gnohj/Obsidian/second-brain/<cr>",
  { desc = "[P]Obsidian: Navigate to vault" }
)
--
-- convert note to template and remove leading white space
keymap("n", "<leader>on", function()
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
  "<leader>of",
  ":s/\\(# \\)[^_]*_/\\1/ | s/-/ /g<cr>",
  { desc = "[P]Obsidian: Format note title" }
)
--
-- for review workflow
-- move file in current buffer to zettelkasten folder
keymap(
  "n",
  "<leader>ok",
  ":!mv '%:p' /Users/gnohj/Obsidian/second-brain/Zettelkasten/<cr>:bd<cr>",
  { desc = "[P]Obsidian: Move file to Zettelkasten" }
)
-- delete file in current buffer
keymap(
  "n",
  "<leader>odd",
  ":!rm '%:p'<cr>:bd<cr>",
  { desc = "[P]Obsidian: Delete file in current buffer" }
)

keymap("n", "gf", function()
  if require("obsidian").util.cursor_on_markdown_link() then
    return "<cmd>ObsidianFollowLink<CR>"
  else
    return "gf"
  end
end, {
  noremap = false,
  expr = true,
  desc = "[P]Obsidian: Follow link under cursor",
})

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
    vim.opt.foldexpr = "v:lua.require'lazyvim.util'.ui.foldexpr()"
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
