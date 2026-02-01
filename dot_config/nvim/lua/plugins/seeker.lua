return {
  "2kabhishek/seeker.nvim",
  dependencies = { "folke/snacks.nvim" },
  keys = {
    { "<leader>fg", "<cmd>Seeker<cr>", desc = "Seeker (files)" },
    { "<leader>sg", "<cmd>Seeker grep<cr>", desc = "Seeker Grep" },
  },
  opts = {
    picker = "snacks",
    toggle_key = "<C-e>",
  },
}
