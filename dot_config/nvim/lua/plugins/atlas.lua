return {
  "emrearmagan/atlas.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "esmuellert/codediff.nvim",
  },
  cmd = "Atlas",
  keys = {
    { "<leader>gA", "<cmd>Atlas<cr>", desc = "Atlas" },
    { "<leader>gp", "<cmd>Atlas pulls github<cr>", desc = "Atlas PRs" },
    { "<leader>gP", "<cmd>Atlas review<cr>", desc = "Atlas review current PR" },
    { "<leader>gJ", "<cmd>Atlas issues jira<cr>", desc = "Atlas Jira issues" },
  },
  opts = function()
    return require("config.atlas").opts()
  end,
  config = function(_, opts)
    require("config.atlas").setup(opts)
  end,
}
