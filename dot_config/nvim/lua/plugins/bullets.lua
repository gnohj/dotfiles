-- https://github.com/bullets-vim/bullets.vim

return {
  "bullets-vim/bullets.vim",
  ft = { "markdown", "text", "gitcommit" }, -- Only load for these filetypes
  config = function()
    vim.g.bullets_delete_last_bullet_if_empty = 2
  end,
}
