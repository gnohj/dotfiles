if vim.g.vscode then
  return {}
end

return {
  "A7Lavinraj/fyler.nvim",
  dependencies = { "nvim-mini/mini.icons" },
  branch = "stable",
  lazy = false,
  opts = {
    win = {
      kind_presets = {
        split_left = {
          width = "0.2rel", -- Reduce from default 0.3rel to 0.2rel (20% of screen)
        },
      },
    },
    close_on_select = false,
    default_explorer = false,
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
