if vim.g.vscode then
  return {}
end

return {
  "A7Lavinraj/fyler.nvim",
  dependencies = { "nvim-mini/mini.icons" },
  branch = "stable",
  lazy = false,
  opts = {
    close_on_select = false,
    default_explorer = true,
    confirm_simple = true, -- Auto-confirm simple operations like copy
    ["<esc>"] = "CloseView",
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
    { "<leader>fo", "<cmd>Fyler kind=split_left<cr>", desc = "fyler.nvim" },
  },
}
