return {
  "otavioschwanck/github-pr-reviewer.nvim",
  opts = {
    debug = true, -- Enable debug logging to diagnose 422 errors
  },
  keys = {
    { "<leader>zp", "<cmd>PRReviewMenu<cr>", desc = "PR Review Menu" },
    {
      "<leader>zp",
      "<cmd>PRSuggestChange<CR>",
      desc = "Suggest change",
      mode = "v",
    },
  },
}
