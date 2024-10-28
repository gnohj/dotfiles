return {
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },
  {
    "unblevable/quick-scope",
  },
  {
    "machakann/vim-highlightedyank",
    config = function()
      vim.g.highlightedyank_highlight_duration = 200 -- Highlight duration in milliseconds
    end,
  },
  {
    "vscode-neovim/vscode-multi-cursor.nvim",
    event = "VeryLazy",
    cond = not not vim.g.vscode,
    config = function()
      require("vscode-multi-cursor").setup({ -- Config is optional
        -- Whether to set default mappings
        default_mappings = true,
        -- If set to true, only multiple cursors will be created without multiple selections
        no_selection = false,
      })
    end,
  },
}
