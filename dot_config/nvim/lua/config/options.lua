-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- local keymap = vim.keymap.set
local opt = vim.opt

vim.opt.textwidth = 80

vim.o.swapfile = false

-- This allows telelescope to always look at the cwd of the project versus the root_dir of a buffer (which can change based on whatever buffer is open)
-- cwd: usually starts off however you started neovim . or neovim of the directory; if for some reason you cwd: /apps/ on command line then this will be the new cwd
vim.g.root_spec = { "cwd" }

-- Enable the option to require a Prettier config file
-- If no prettier config file is found, the formatter will not be used
vim.g.lazyvim_prettier_needs_config = false

-- clipboard
---@diagnostic disable-next-line: undefined-field
opt.clipboard:append("unnamedplus") -- use system clipboard as default register

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom
