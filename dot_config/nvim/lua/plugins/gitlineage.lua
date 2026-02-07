return {
  "LionyxML/gitlineage.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<leader>gl",
      function()
        require("gitlineage").selected_history()
      end,
      mode = "v",
      desc = "Git Lineage (selected lines)",
    },
    {
      "<leader>gl",
      "<nop>",
      mode = "n",
      desc = "Git Lineage (visual mode only)",
    },
  },
  opts = {},
}
