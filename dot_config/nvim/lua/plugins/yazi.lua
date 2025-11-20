return {
  "mikavilpas/yazi.nvim",
  version = "*",
  event = "VeryLazy",
  dependencies = {
    { "nvim-lua/plenary.nvim", lazy = true },
  },
  keys = {
    {
      "<leader>-",
      mode = { "n", "v" },
      "<cmd>Yazi<cr>",
      desc = "Open yazi at the current file",
    },
    {
      -- Open in the current working directory
      "<leader>=",
      "<cmd>Yazi cwd<cr>",
      desc = "Open the file manager in nvim's working directory",
    },
  },
  opts = {
    keymaps = {
      show_help = "<f1>",
    },
    -- Match skhd popup dimensions (90% width, 90% height)
    yazi_floating_window_winblend = 0,
    yazi_floating_window_border = "rounded",
    floating_window_scaling_factor = 0.9,
  },
}
