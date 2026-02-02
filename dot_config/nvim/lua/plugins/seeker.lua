return {
  "2kabhishek/seeker.nvim",
  dependencies = { "folke/snacks.nvim" },
  keys = {
    { "<leader>sg", "<cmd>Seeker grep<cr>", desc = "Seeker Grep" },
  },
  opts = {
    picker = "snacks",
    toggle_key = "<C-e>",
  },
}
