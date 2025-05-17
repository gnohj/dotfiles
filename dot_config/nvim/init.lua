-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Clears jumplist when Neovim Starts before any file is loaded and only clears once
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd("clearjumps")
  end,
})
