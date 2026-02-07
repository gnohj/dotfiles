return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 500
  end,
  opts = {
    spec = {
      { "<leader>gh", hidden = true },
      { "<leader>gl", hidden = true }, -- Hidden: use visual mode for gitlineage
      { "<leader>G", hidden = true },
      { "<leader>K", hidden = true },
      { "<leader>L", hidden = true },
      { "<leader>n", hidden = true },
      { "<leader>a", group = "toggle copilot suggestions" },
      { "<leader>m", group = "toggle c" },
      { "<leader>o", group = "opencode" },
      { "<leader>z", group = "obsidian" },
      { "<leader>h", group = "hunks" },
      { "<leader>p", group = "yank history" },
      { "<leader>-", desc = "Open yazi at cwd" },
    },
  },
}
