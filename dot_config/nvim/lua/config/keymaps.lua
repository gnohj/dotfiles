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

-- keymap("n", "<S-h>", function()
--   require("telescope.builtin").buffers(require("telescope.themes").get_ivy({
--     sort_mru = true,
--     sort_lastused = true,
--     initial_mode = "normal",
--     -- Pre-select the current buffer
--     -- ignore_current_buffer = false,
--     -- select_current = true,
--     layout_config = {
--       -- Set preview width, 0.7 sets it to 70% of the window width
--       preview_width = 0.7,
--       height = 0.7,
--     },
--   }))
-- end, { desc = "[P]Open telescope buffers" })

-- Quickscope --
-- vim.cmd([[
--   highlight QuickScopePrimary ='#afff5f' gui=underline ctermfg=155 cterm=underline
--   highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline
-- ]])
vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }

-- pounce
keymap("n", "<leader>hp", function()
  require("pounce").pounce({})
end, { desc = "Pounce" })

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

local function insertFullPath()
  local full_path = vim.fn.expand("%:p") -- Get the full file path
  vim.fn.setreg("+", full_path:gsub(vim.fn.expand("$HOME"), "~")) -- Replace $HOME with ~
end

keymap("n", "<leader>fy", insertFullPath, { silent = true, noremap = true, desc = "Copy full path" })

-- reveal active file in neotree
keymap("n", "<leader>fa", ":Neotree reveal<CR>", { desc = "Reveal active file in neotree" })

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

keymap(
  "n",
  "<leader>as",
  ":lua require('copilot.suggestion').toggle_auto_trigger()<CR>",
  { silent = true, noremap = true, desc = "copilot: toggle virtual text suggestions" }
)

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
vim.keymap.set({ "n", "v", "i" }, "<M-f>", function()
  tmux_pane_function("/Users/gnohj/Obsidian/second-brain")
end, { desc = "[P]Terminal on tmux pane" })

-- If I execute the function without an argument, it will open the dir where the current file lives
-- vim.keymap.set({ "n", "v", "i" }, "<M-o", function()
--   tmux_pane_function("/Users/gnohj/Obsidian/second-brain")
-- end, { desc = "[P]Terminal Notes on tmux pane" })

vim.keymap.set("n", "<leader>ha", function()
  harpoon:list():add()
end)
vim.keymap.set("n", "<C-e>", function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end)

vim.keymap.set("n", "<leader>hs", function()
  harpoon:list():select(1)
end)
vim.keymap.set("n", "<leader>hd", function()
  harpoon:list():select(2)
end)
vim.keymap.set("n", "<leader>hf", function()
  harpoon:list():select(3)
end)
vim.keymap.set("n", "<leader>hg", function()
  harpoon:list():select(4)
end)

-- Toggle previous & next buffers stored within Harpoon list
vim.keymap.set("n", "<C-P>", function()
  harpoon:list():prev()
end)
vim.keymap.set("n", "<C-N>", function()
  harpoon:list():next()
end)

-- Navigate buffers
keymap("n", "<Tab>", ":bnext<CR>", opts) -- Switch to the next buffer
keymap("n", "<S-Tab>", ":bprev<CR>", opts) -- Switch to the previous buffer

keymap("n", "<leader><space>", "<cmd>e #<cr>", { desc = "Alternate buffer" })
