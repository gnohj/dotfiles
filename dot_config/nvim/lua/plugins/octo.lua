return {
  "pwntester/octo.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "Octo" },
  keys = {
    {
      "<leader>gi",
      function()
        local cwd = vim.fn.getcwd()
        vim.fn.jobstart({ "tmux", "new-window", "-n", "🐙", "-c", cwd, "gh-dash", "--config", vim.fn.expand("~/.config/gh-dash/issues.yml") }, { detach = true })
      end,
      desc = "gh-dash Issues (tmux)",
    },
  },
  opts = {
    enable_builtin = false,
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
