--[[
  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
--]]

-- 2 style options "solid" and "transparent"
-- This style is defined in colorscheme-vars.sh
-- :lua print(vim.env.MD_HEADING_BG)
vim.g.md_heading_bg = vim.env.MD_HEADING_BG
vim.g.theme_transparent = vim.env.THEME_TRANSPARENT

vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrw = 1
vim.g.loaded_matchit = 1

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Per-tmux-pane RPC socket so external tools (yazi launcher, etc.) can ask
-- this nvim instance for the current buffer path. Path is keyed off
-- TMUX_PANE so the right nvim is queried even when several are running.
if vim.env.TMUX_PANE then
  local socket = "/tmp/nvim-" .. vim.env.TMUX_PANE:gsub("%%", "") .. ".sock"
  pcall(vim.fn.serverstart, socket)
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      pcall(os.remove, socket)
    end,
  })
end

-- Clears jumplist when Neovim Starts before any file is loaded and only clears once
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd("clearjumps")
  end,
})
