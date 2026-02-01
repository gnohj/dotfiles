return {
  "2kabhishek/seeker.nvim",
  dependencies = { "folke/snacks.nvim" },
  keys = {
    { "<leader>fk", "<cmd>Seeker<cr>", desc = "Seeker (files)" },
    { "<leader>fK", "<cmd>Seeker grep<cr>", desc = "Seeker (grep)" },
  },
  opts = {
    picker = "snacks",
    toggle_key = "<C-e>",
  },
}
