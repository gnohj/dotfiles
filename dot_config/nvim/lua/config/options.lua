--[[
 ██████╗ ██████╗ ████████╗██╗ ██████╗ ███╗   ██╗███████╗
██╔═══██╗██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
██║   ██║██████╔╝   ██║   ██║██║   ██║██╔██╗ ██║███████╗
██║   ██║██╔═══╝    ██║   ██║██║   ██║██║╚██╗██║╚════██║
╚██████╔╝██║        ██║   ██║╚██████╔╝██║ ╚████║███████║
 ╚═════╝ ╚═╝        ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
--]]

-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.timeout = true
opt.timeoutlen = 1000

vim.g.snacks_animate = false

vim.opt.completeopt = { "menuone", "popup", "noinsert" }

vim.o.swapfile = false
vim.opt.linebreak = true
vim.opt.wrap = false

-- enable neovim scrolling when in tmux
vim.opt.mouse = "a"
vim.opt.mousescroll = "ver:3,hor:0"

-- Global statusline — one statusline across the entire Neovim window, not per split
vim.opt.laststatus = 3

vim.g.snacks_animate = false

-- Show LSP diagnostics (inlay hints) in a hover window / popup
-- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#show-line-diagnostics-automatically-in-hover-window
-- https://www.reddit.com/r/neovim/comments/1168p97/how_can_i_make_lspconfig_wrap_around_these_hints/
-- Time it takes to show the popup after you hover over the line with an error
vim.o.updatetime = 200

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
