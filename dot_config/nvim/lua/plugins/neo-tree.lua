if vim.g.vscode then
  return {}
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  enabled = false,
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = true,
      },
      follow_current_file = {
        enabled = false,
      },
    },
  },
}
