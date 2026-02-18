return {
  "gbprod/yanky.nvim",
  opts = {
    ring = { history_length = 21 },
    highlight = { timer = 250 },
  },
  dependencies = { "folke/snacks.nvim" },
  keys = {
    {
      "<leader>p",
      function()
        Snacks.picker.yanky({
          on_show = function()
            vim.cmd.stopinsert()
          end,
        })
      end,
      mode = { "n", "x" },
      desc = "Open Yank History (Snacks)",
    },
    {
      "=p",
      "<Plug>(YankyPutAfterLinewise)",
      desc = "Put yanked text in line below",
    },
    {
      "=P",
      "<Plug>(YankyPutBeforeLinewise)",
      desc = "Put yanked text in line above",
    },
    {
      "[y",
      "<Plug>(YankyCycleForward)",
      desc = "Cycle forward through yank history",
    },
    {
      "]y",
      "<Plug>(YankyCycleBackward)",
      desc = "Cycle backward through yank history",
    },
    { "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yanky yank" },
  },
}
