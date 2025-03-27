if vim.g.vscode then
  return {}
end

return {
  "sindrets/diffview.nvim",
  opts = {
    default_args = {
      DiffviewOpen = { "--imply-local" },
    },
  },
}
