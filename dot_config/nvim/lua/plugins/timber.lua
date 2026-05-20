return {
  "Goose97/timber.nvim",
  event = "VeryLazy",
  -- Build hook applies a compatibility patch for Neovim 0.12+ where
  -- `query:iter_matches` returns arrays of nodes instead of single
  -- nodes. The plugin's directive handler still does
  -- `local node = match[capture_id]` and calls `node:range()`, which
  -- fails ("attempt to call method 'range' on nil"). The patch grabs
  -- the first node from the array if it's a table, leaving the old
  -- nvim behavior unaffected.
  build = function()
    local file_path = vim.fn.stdpath("data")
      .. "/lazy/timber.nvim/lua/timber/actions/treesitter.lua"
    local file = io.open(file_path, "r")
    if file then
      local content = file:read("*all")
      file:close()
      content = content:gsub(
        "local node = match%[capture_id%]\n",
        'local node = match[capture_id]; if type(node) == "table" then node = node[1] end\n'
      )
      file = io.open(file_path, "w")
      if file then
        file:write(content)
        file:close()
      end
    end
  end,
  config = function()
    require("timber").setup({
      log_marker = "🚀",
      log_templates = {
        default = {
          javascript = [[console.log('🚀 -> %log_target', %log_target);]],
          typescript = [[console.log('🚀 -> %log_target', %log_target);]],
          javascriptreact = [[console.log('🚀 -> %log_target', %log_target);]],
          typescriptreact = [[console.log('🚀 -> %log_target', %log_target);]],
          jsx = [[console.log('🚀 -> %log_target', %log_target);]],
          tsx = [[console.log('🚀 -> %log_target', %log_target);]],
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
