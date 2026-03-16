return {
  "ThePrimeagen/99",
  dependencies = { "folke/snacks.nvim" },
  keys = {
    {
      "<leader>9s",
      function()
        require("99").search()
      end,
      desc = "99 Search",
    },
    {
      "<leader>9v",
      function()
        require("99").visual()
      end,
      mode = "v",
      desc = "99 Visual",
    },
    {
      "<leader>9x",
      function()
        require("99").stop_all_requests()
      end,
      desc = "99 Stop All",
    },
  },
  config = function()
    local _99 = require("99")
    _99.setup({
      provider = _99.Providers.ClaudeCodeProvider,
      tmp_dir = "./.99-tmp",
      completion = {
        source = "native",
      },
    })
  end,
}
