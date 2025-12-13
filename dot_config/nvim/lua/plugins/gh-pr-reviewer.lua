return {
  "otavioschwanck/github-pr-reviewer.nvim",
  opts = {
    debug = true, -- Enable debug logging to diagnose 422 errors
  },
  keys = {
    { "<leader>gp", "<cmd>PRReviewMenu<cr>", desc = "PR Review Menu" },
    {
      "<leader>gp",
      "<cmd>PRSuggestChange<CR>",
      desc = "Suggest change",
      mode = "v",
    },
  },
}
