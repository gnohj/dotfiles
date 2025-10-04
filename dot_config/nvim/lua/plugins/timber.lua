if vim.g.vscode then
  return {}
end

return {
  "Goose97/timber.nvim",
  event = "VeryLazy",
  config = function()
    require("timber").setup({
      log_marker = "🚀",
      log_templates = {
        default = {
          javascript = [[console.log("🚀 -> %log_target", %log_target)]],
          typescript = [[console.log("🚀 -> %log_target", %log_target)]],
          javascriptreact = [[console.log("🚀 -> %log_target", %log_target)]],
          typescriptreact = [[console.log("🚀 -> %log_target", %log_target)]],
          jsx = [[console.log("🚀 -> %log_target", %log_target)]],
          tsx = [[console.log("🚀 -> %log_target", %log_target)]],
          lua = [[print("🚀 -> %log_target", %log_target)]],
          go = [[log.Printf("🚀 -> %log_target: %v\n", %log_target)]],
          python = [[print(f"🚀 -> {%log_target=}")]],
        },
      },
    })
  end,
  keys = {
    {
      "<leader>tc",
      function()
        require("timber.actions").insert_log({ position = "below" })
      end,
      mode = "n",
      desc = "[P]Insert log statement",
    },
    {
      "<leader>tC",
      function()
        require("timber.actions").clear_log_statements({ global = false })
      end,
      mode = "n",
      desc = "[P]Clear log statements in buffer",
    },
  },
}
