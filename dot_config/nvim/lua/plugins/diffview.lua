return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewFileHistory" },
  keys = {
    { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
  },
  opts = {
    keymaps = {
      file_history_panel = {
        { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        { "n", "<esc>", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
      },
      view = {
        { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        { "n", "<esc>", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
        { "n", "<tab>", "<cmd>DiffviewFocusFiles<cr>", { desc = "Focus file panel" } },
      },
    },
  },
}
