return {
  "stevearc/aerial.nvim",
  event = "LazyFile",
  keys = {
    { "<leader>O", "<cmd>AerialToggle<cr>", desc = "Aerial (Symbols)" },
  },
  opts = {},
  config = function(_, opts)
    require("aerial").setup(opts)

    -- Set up escape to close aerial
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "aerial",
      callback = function(event)
        vim.keymap.set("n", "<esc>", "<cmd>AerialClose<cr>", {
          buffer = event.buf,
          silent = true,
          desc = "Close Aerial",
        })
      end,
    })
  end,
}
