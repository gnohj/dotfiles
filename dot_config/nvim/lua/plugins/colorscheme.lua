if vim.g.vscode then
  return {}
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
      -- colorscheme = "evergarden",
      -- colorscheme = "jellybeans",
      -- colorscheme = "eldritch",
    },
  },
}
