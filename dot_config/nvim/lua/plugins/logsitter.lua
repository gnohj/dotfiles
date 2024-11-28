if vim.g.vscode then
  return {}
end

return {
  "gaelph/logsitter.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("logsitter").setup({
      path_format = "default",
      prefix = "🚀",
      separator = "->",
      logging_functions = {
        javascript = "console.log",
        javascriptreact = "console.log",
        typescript = "console.log",
        typescriptreact = "console.log",
        lua = "print",
        go = "log.Printf",
        python = "print",
        swift = "print",
      },
    })
    -- local logsitter = require("logsitter")

    -- logsitter (turbo console log)
    vim.keymap.set("n", "<leader>tc", function()
      require("logsitter").log()
    end, { desc = "Turbo Console Log" })
  end,
}
