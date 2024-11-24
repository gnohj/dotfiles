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

vim.keymap.set("n", "<S-h>", function()
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

-- reveal active file in neotree
vim.keymap.set("n", "<C-a>", ":Neotree reveal<CR>", { desc = "Reveal active file in neotree" })

-- Quickscope --
-- vim.cmd([[
--   highlight QuickScopePrimary ='#afff5f' gui=underline ctermfg=155 cterm=underline
--   highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline
-- ]])
vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }
