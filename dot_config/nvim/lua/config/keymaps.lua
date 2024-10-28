-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

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
