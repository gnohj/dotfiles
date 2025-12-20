return {
  "nvim-mini/mini.diff",
  event = "VeryLazy",
  opts = {
    view = {
      style = "sign",
      signs = {
        add = "•",
        change = "•",
        delete = "",
      },
    },
    -- Disable default mappings - using gitsigns for hunk navigation
    mappings = {
      apply = "",
      reset = "",
      textobject = "",
      goto_first = "",
      goto_prev = "",
      goto_next = "",
      goto_last = "",
    },
  },
  keys = {
    {
      "<leader>go",
      function()
        require("mini.diff").toggle_overlay(0)
      end,
      desc = "Toggle mini.diff overlay",
    },
  },
}
