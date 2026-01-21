return {
  "stevearc/aerial.nvim",
  event = "LazyFile",
  keys = {
    { "<leader>O", "<cmd>AerialToggle<cr>", desc = "Aerial (Symbols)" },
  },
  opts = {},
  config = function(_, opts)
    require("aerial").setup(opts)
  end,
}
