return {
  "sudo-tee/opencode.nvim",
  event = "VeryLazy",
  cond = function()
    return vim.fn.executable("opencode") == 1
  end,
  config = function()
    require("opencode").setup({
      ui = {
        window_width = 0.22,
        icons = {
          preset = "text",
          overrides = {},
        },
      },
      context = {
        enabled = true,
        current_file = {
          enabled = true,
        },
        cursor_data = {
          enabled = true,
        },
        selection = {
          enabled = true,
        },
        diagnostics = {
          info = false,
          warn = true,
          error = true,
        },
      },
    })
  end,
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        anti_conceal = { enabled = false },
        file_types = { "markdown", "opencode_output" },
      },
      ft = { "markdown", "opencode_output" },
    },
    "saghen/blink.cmp",
    "folke/snacks.nvim",
  },
}
