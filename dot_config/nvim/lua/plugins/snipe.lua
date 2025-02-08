if vim.g.vscode then
  return {}
end

-- https://github.com/leath-dub/snipe.nvim
return {
  "leath-dub/snipe.nvim",
  enabled = false,
  keys = {
    {
      "<S-l>",
      function()
        require("snipe").open_buffer_menu()
      end,
      desc = "Open Snipe buffer menu",
    },
  },
  config = function()
    local snipe = require("snipe")
    snipe.setup({
      navigate = {
        cancel_snipe = "<esc>",
        close_buffer = "d",
      },
      sort = "default",
    })
  end,
}
