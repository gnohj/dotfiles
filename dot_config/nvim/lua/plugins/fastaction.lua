-- https://github.com/Chaitanyabsprip/fastaction.nvim
return {
  "Chaitanyabsprip/fastaction.nvim",
  enabled = false,
  event = "LspAttach",
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
