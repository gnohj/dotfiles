-- https://github.com/bullets-vim/bullets.vim
if vim.g.vscode then
  return {}
end

return {
  "bullets-vim/bullets.vim",
  config = function()
    vim.g.bullets_delete_last_bullet_if_empty = 2
  end,
}
