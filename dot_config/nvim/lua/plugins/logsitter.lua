if vim.g.vscode then
  return {}
end

return {
  "gaelph/logsitter.nvim",
  enabled = false,
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
  end,
}
