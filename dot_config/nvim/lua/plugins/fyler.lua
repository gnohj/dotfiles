if vim.g.vscode then
  return {}
end

return {
  "A7Lavinraj/fyler.nvim",
  dependencies = { "echasnovski/mini.icons" },
  branch = "stable",
  lazy = false,
  opts = {
    default_explorer = true,
    ["q"] = "CloseView",
    -- Mappings:
    -- mappings can be customized by action names which are local to thier view
    mappings = {
      -- For `explorer` actions checkout following link:
      -- https://github.com/A7Lavinraj/fyler.nvim/blob/main/lua/fyler/views/explorer/actions.lua
      explorer = {
        n = {
          ["<esc>"] = "CloseView",
          ["<CR>"] = "Select",
        },
      },
    },
  },
  cmd = "Fyler",
  keys = {
    { "<leader>fo", "<cmd>Fyler<cr>", desc = "fyler.nvim" },
  },
}
