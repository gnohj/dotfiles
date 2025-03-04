-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }
local harpoon = require("harpoon")
harpoon:setup()

keymap("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- delete without yanking
keymap({ "n", "v" }, "<leader>dd", [["_d]], { desc = "Delete without yanking" })

-- move text up and down
keymap("v", "J", ":m .+1<CR>==", opts)
keymap("v", "K", ":m .-2<CR>==", opts)
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)

-- yank to system clipboard
keymap({ "n", "v" }, "<leader>y", '"+y', opts)

-- paste from system clipboard
keymap({ "n", "v" }, "<leader>p", '"+p', opts)

-- removes highlighting after escaping vim search
keymap("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- increment/decrement numbers
keymap("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap("n", "<leader>=", "<C-x>", { desc = "Decrement number" })

-- Navigate buffers
keymap("n", "<Tab>", ":bnext<CR>", opts) -- Switch to the next buffer
keymap("n", "<S-Tab>", ":bprev<CR>", opts) -- Switch to the previous buffer

keymap("n", "<leader><space>", "<cmd>e #<cr>", { desc = "Alternate buffer" })

local function insertFullPath()
  local full_path = vim.fn.expand("%:p") -- Get the full file path
  vim.fn.setreg("+", full_path:gsub(vim.fn.expand("$HOME"), "~")) -- Replace $HOME with ~
end

keymap("n", "<leader>fy", insertFullPath, { silent = true, noremap = true, desc = "Copy full path" })

-------------------------------------------------------------------------------
--                           Quickscope
-------------------------------------------------------------------------------

-- Quickscope --
-- vim.cmd([[
--   highlight QuickScopePrimary ='#afff5f' gui=underline ctermfg=155 cterm=underline
--   highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline
-- ]])
vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }

-------------------------------------------------------------------------------
--                           Pounce
-------------------------------------------------------------------------------

keymap("n", "<leader>hp", function()
  require("pounce").pounce({})
end, { desc = "Pounce" })

-------------------------------------------------------------------------------
--                           Package Info
-------------------------------------------------------------------------------

-- package-info keymaps
keymap(
  "n",
  "<leader>cpt",
  "<cmd>lua require('package-info').toggle()<cr>",
  { silent = true, noremap = true, desc = "Toggle" }
)
keymap(
  "n",
  "<leader>cpd",
  "<cmd>lua require('package-info').delete()<cr>",
  { silent = true, noremap = true, desc = "Delete package" }
)
keymap(
  "n",
  "<leader>cpu",
  "<cmd>lua require('package-info').update()<cr>",
  { silent = true, noremap = true, desc = "Update package" }
)
keymap(
  "n",
  "<leader>cpi",
  "<cmd>lua require('package-info').install()<cr>",
  { silent = true, noremap = true, desc = "Install package" }
)
keymap(
  "n",
  "<leader>cpc",
  "<cmd>lua require('package-info').change_version()<cr>",
  { silent = true, noremap = true, desc = "Change package version" }
)

-------------------------------------------------------------------------------
--                           DiffView
-------------------------------------------------------------------------------

keymap("n", "<leader><leader>v", function()
  if next(require("diffview.lib").views) == nil then
    vim.cmd("DiffviewOpen --imply-local")
  else
    vim.cmd("DiffviewClose")
  end
end)

keymap("n", "<leader><leader>m", function()
  if next(require("diffview.lib").views) == nil then
    vim.cmd("DiffviewOpen origin/master...HEAD --imply-local")
  else
    vim.cmd("DiffviewClose")
  end
end)

keymap("n", "<leader><leader>d", function()
  if next(require("diffview.lib").views) == nil then
    vim.cmd("DiffviewOpen origin/develop...HEAD --imply-local")
  else
    vim.cmd("DiffviewClose")
  end
end)

keymap("n", "<leader><leader>f", function()
  if next(require("diffview.lib").views) == nil then
    vim.cmd("DiffviewFileHistory %")
  else
    vim.cmd("DiffviewClose")
  end
end)

-------------------------------------------------------------------------------
--                           Toggle Copilot Virtual Text
-------------------------------------------------------------------------------

keymap(
  "n",
  "<leader>as",
  ":lua require('copilot.suggestion').toggle_auto_trigger()<CR>",
  { silent = true, noremap = true, desc = "copilot: toggle virtual text suggestions" }
)

-------------------------------------------------------------------------------
--                           TMUX New Pane Peek
-------------------------------------------------------------------------------
local function tmux_pane_function(dir)
  -- NOTE: variable that controls the auto-cd behavior
  local auto_cd_to_new_dir = true
  -- NOTE: Variable to control pane direction: 'right' or 'bottom'
  -- If you modify this, make sure to also modify TMUX_PANE_DIRECTION in the
  -- zsh-vi-mode section on the .zshrc file
  -- Also modify this in your tmux.conf file if you want it to work when in tmux
  -- copy-mode
  local pane_direction = vim.g.tmux_pane_direction or "right"
  -- NOTE: Below, the first number is the size of the pane if split horizontally,
  -- the 2nd number is the size of the pane if split vertically
  local pane_size = (pane_direction == "right") and 90 or 15
  local move_key = (pane_direction == "right") and "C-l" or "C-k"
  local split_cmd = (pane_direction == "right") and "-h" or "-v"
  -- if no dir is passed, use the current file's directory
  local file_dir = dir or vim.fn.expand("%:p:h")
  -- Simplified this, was checking if a pane existed
  local has_panes = vim.fn.system("tmux list-panes | wc -l"):gsub("%s+", "") ~= "1"
  -- Check if the current pane is zoomed (maximized)
  local is_zoomed = vim.fn.system("tmux display-message -p '#{window_zoomed_flag}'"):gsub("%s+", "") == "1"
  -- Escape the directory path for shell
  local escaped_dir = file_dir:gsub("'", "'\\''")
  -- If any additional pane exists
  if has_panes then
    if is_zoomed then
      -- Compare the stored pane directory with the current file directory
      if auto_cd_to_new_dir and vim.g.tmux_pane_dir ~= escaped_dir then
        -- If different, cd into the new dir
        vim.fn.system("tmux send-keys -t :.+ 'cd \"" .. escaped_dir .. "\"' Enter")
        -- Update the stored directory to the new one
        vim.g.tmux_pane_dir = escaped_dir
      end
      -- If zoomed, unzoom and switch to the correct pane
      vim.fn.system("tmux resize-pane -Z")
      vim.fn.system("tmux send-keys " .. move_key)
    else
      -- If not zoomed, zoom current pane
      vim.fn.system("tmux resize-pane -Z")
    end
  else
    -- Store the initial directory in a Neovim variable
    if vim.g.tmux_pane_dir == nil then
      vim.g.tmux_pane_dir = escaped_dir
    end
    -- If no pane exists, open it with zsh and DISABLE_PULL variable
    vim.fn.system(
      "tmux split-window "
        .. split_cmd
        .. " -l "
        .. pane_size
        .. " 'cd \""
        .. escaped_dir
        .. "\" && DISABLE_PULL=1 zsh'"
    )
    vim.fn.system("tmux send-keys " .. move_key)
    -- Resolve zsh-vi-mode issue for first-time pane
    vim.fn.system("tmux send-keys Escape i")
  end
end

-- If I execute the function without an argument, it will open the dir where the current file lives
keymap({ "n", "v", "i" }, "<M-f>", function()
  tmux_pane_function("/Users/gnohj/Obsidian/second-brain")
end, { desc = "[P]Terminal on tmux pane" })

-- If I execute the function without an argument, it will open the dir where the current file lives
-- vim.keymap.set({ "n", "v", "i" }, "<M-o", function()
--   tmux_pane_function("/Users/gnohj/Obsidian/second-brain")
-- end, { desc = "[P]Terminal Notes on tmux pane" })

-------------------------------------------------------------------------------
--                           Harpoon
-------------------------------------------------------------------------------
keymap("n", "<leader>ha", function()
  harpoon:list():add()
end, { desc = "Add file to Harpoon" })

keymap("n", "<C-e>", function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Toggle Harpoon menu" })

-- Toggle previous & next buffers stored within Harpoon list
keymap("n", "<C-P>", function()
  harpoon:list():prev()
end)
keymap("n", "<C-O>", function()
  harpoon:list():next()
end)

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
  vim.opt.foldlevel = 99
end

-- Function to fold all headings of a specific level
local function fold_headings_of_level(level)
  -- Move to the top of the file
  vim.cmd("normal! gg")
  -- Get the total number of lines
  local total_lines = vim.fn.line("$")
  for line = 1, total_lines do
    -- Get the content of the current line
    local line_content = vim.fn.getline(line)
    -- "^" -> Ensures the match is at the start of the line
    -- string.rep("#", level) -> Creates a string with 'level' number of "#" characters
    -- "%s" -> Matches any whitespace character after the "#" characters
    -- So this will match `## `, `### `, `#### ` for example, which are markdown headings
    if line_content:match("^" .. string.rep("#", level) .. "%s") then
      -- Move the cursor to the current line
      vim.fn.cursor(line, 1)
      -- Fold the heading if it matches the level
      if vim.fn.foldclosed(line) == -1 then
        vim.cmd("normal! za")
      end
    end
  end
end

local function fold_markdown_headings(levels)
  set_foldmethod_expr()
  -- I save the view to know where to jump back after folding
  local saved_view = vim.fn.winsaveview()
  for _, level in ipairs(levels) do
    fold_headings_of_level(level)
  end
  vim.cmd("nohlsearch")
  -- Restore the view to jump to where I was
  vim.fn.winrestview(saved_view)
end

--
-- Keymap for unfolding markdown headings of level 2 or above
-- Changed all the markdown folding and unfolding keymaps from <leader>mfj to
-- zj, zk, zl, z; and zu respectively lamw25wmal
keymap("n", "zu", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mfu", function()
  -- Reloads the file to reflect the changes
  vim.cmd("edit!")
  vim.cmd("normal! zR") -- Unfold all headings
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Unfold all headings level 2 or above" })

--
-- gk jummps to the markdown heading above and then folds it
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
-- Keymap for folding markdown headings of level 1 or above
keymap("n", "zj", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mfj", function()
  -- Reloads the file to refresh folds, otheriise you have to re-open neovim
  vim.cmd("edit!")
  -- Unfold everything first or I had issues
  vim.cmd("normal! zR")
  fold_markdown_headings({ 6, 5, 4, 3, 2, 1 })
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 1 or above" })

--
-- Keymap for folding markdown headings of level 2 or above
-- I know, it reads like "madafaka" but "k" for me means "2"
keymap("n", "zk", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mfk", function()
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  -- Unfold everything first or I had issues
  vim.cmd("normal! zR")
  fold_markdown_headings({ 6, 5, 4, 3, 2 })
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 2 or above" })

--
-- Keymap for folding markdown headings of level 3 or above
keymap("n", "zl", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mfl", function()
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  -- Unfold everything first or I had issues
  vim.cmd("normal! zR")
  fold_markdown_headings({ 6, 5, 4, 3 })
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 3 or above" })

--
-- Keymap for folding markdown headings of level 4 or above
keymap("n", "z;", function()
  -- "Update" saves only if the buffer has been modified since the last save
  vim.cmd("silent update")
  -- vim.keymap.set("n", "<leader>mf;", function()
  -- Reloads the file to refresh folds, otherwise you have to re-open neovim
  vim.cmd("edit!")
  -- Unfold everything first or I had issues
  vim.cmd("normal! zR")
  fold_markdown_headings({ 6, 5, 4 })
  vim.cmd("normal! zz") -- center the cursor line on screen
end, { desc = "[P]Fold all headings level 4 or above" })

-------------------------------------------------------------------------------
--                           Aider
-------------------------------------------------------------------------------
vim.keymap.set("n", "<leader>aA", function()
  local buffers = vim.api.nvim_list_bufs()

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local filepath = vim.api.nvim_buf_get_name(buf)
      -- Only process buffers that are actual files
      if filepath and filepath ~= "" then
        -- Get the terminal buffer job id
        local term_bufs = vim.fn.filter(vim.api.nvim_list_bufs(), 'getbufvar(v:val, "&buftype") == "terminal"')
        for _, term_buf in ipairs(term_bufs) do
          local chan = vim.api.nvim_buf_get_var(term_buf, "terminal_job_id")
          if chan then
            -- Send the add command directly to terminal
            vim.api.nvim_chan_send(chan, "/add " .. filepath .. "\n")
          end
        end
      end
    end
  end
end, { desc = "Add All Buffer Files To Aider" })

vim.opt.completeopt = { "menuone", "popup", "noinsert" }
