return {
  "pwntester/octo.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "Octo" },
  opts = {
    enable_builtin = true,
    picker = "snacks",
    mappings = {
      review_diff = {
        select_next_entry = {
          lhs = "<Tab>",
          desc = "move to next changed file",
        },
        select_prev_entry = {
          lhs = "<S-Tab>",
          desc = "move to previous changed file",
        },
        close_review_tab = {
          lhs = "<esc>",
          desc = "close review tab",
        },
        add_review_comment = {
          lhs = "<leader>ca",
          desc = "add review comment",
          mode = { "n", "x" },
        },
        add_review_suggestion = {
          lhs = "<leader>sa",
          desc = "add review suggestion",
          mode = { "n", "x" },
        },
        next_thread = {
          lhs = "]t",
          desc = "next comment thread",
        },
        prev_thread = {
          lhs = "[t",
          desc = "previous comment thread",
        },
        submit_review = {
          lhs = "<leader>vs",
          desc = "submit review",
        },
        discard_review = {
          lhs = "<leader>vd",
          desc = "discard review",
        },
      },
    },
  },
  config = function(_, opts)
    require("octo").setup(opts)
  end,
}
