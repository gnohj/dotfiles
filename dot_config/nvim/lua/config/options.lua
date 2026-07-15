local opt = vim.opt

opt.timeout = true
opt.timeoutlen = 1000

vim.g.snacks_animate = false

vim.g.snacks_scroll = false

vim.opt.completeopt = { "menuone", "popup", "noinsert" }

vim.opt.autoread = true

vim.o.swapfile = false
vim.opt.linebreak = true
vim.opt.wrap = false

-- enable neovim scrolling when in tmux
vim.opt.mouse = "a"
vim.opt.mousescroll = "ver:3,hor:0"
-- free the right mouse button from the popup menu so it can be mapped to
-- right-drag-select-and-copy (see keymaps.lua) — mirrors the tmux right-drag
-- binding, which passes through to nvim because mouse=a
vim.opt.mousemodel = "extend"

-- Global statusline — one statusline across the entire Neovim window, not per split
vim.opt.laststatus = 3
-- Hide statusline text but keep the bar itself
vim.opt.statusline = " "

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

-- Minimal left side setup
opt.number = false -- Disable line numbers by default
opt.relativenumber = false -- Disable relative numbers
opt.signcolumn = "yes:1" -- Keep minimal sign column for git/diagnostics

-- OSC52 clipboard when working over SSH (remote dev box). Locally on the Mac the native
-- provider (pbcopy) stays in charge; over SSH there's no pbcopy on a headless box, so
-- route yanks through the terminal's OSC52 escape → they land in the LOCAL Mac clipboard.
-- Gated on $SSH_TTY so it ONLY kicks in on the remote side, never locally. (nvim 0.10+)
if os.getenv("SSH_TTY") ~= nil then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
  end
end
