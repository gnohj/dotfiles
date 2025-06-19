if vim.g.vscode then
  return {}
end

-- https://github.com/Chaitanyabsprip/fastaction.nvim
return {
  "Chaitanyabsprip/fastaction.nvim",
  opts = {
    dismiss_keys = { "j", "k", "<c-c>", "<esc>", "q" },
    priority = {
      eslint = {
        { key = "a", order = 1, pattern = "fix all" },
        { key = "f", order = 2, pattern = "fix this" },
      },
    },
  },
}
