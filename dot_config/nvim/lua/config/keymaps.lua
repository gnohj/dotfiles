-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- delete without yanking
keymap({ "n", "v" }, "<leader>d", [["_d]])

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

keymap("n", "<S-h>", function()
  require("telescope.builtin").buffers(require("telescope.themes").get_ivy({
    sort_mru = true,
    sort_lastused = true,
    initial_mode = "normal",
    -- Pre-select the current buffer
    -- ignore_current_buffer = false,
    -- select_current = true,
    layout_config = {
      -- Set preview width, 0.7 sets it to 70% of the window width
      preview_width = 0.7,
      height = 0.7,
    },
  }))
end, { desc = "[P]Open telescope buffers" })

-- Quickscope --
-- vim.cmd([[
--   highlight QuickScopePrimary ='#afff5f' gui=underline ctermfg=155 cterm=underline
--   highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline
-- ]])
vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }

-- pounce
keymap("n", "<leader>h", function()
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
