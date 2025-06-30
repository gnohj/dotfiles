if vim.g.vscode then
  return {}
end

return {
  "hedyhli/outline.nvim",
  lazy = true,
  cmd = { "Outline", "OutlineOpen" },
  keys = { -- Example mapping to toggle outline
    { "<leader>O", "<cmd>Outline<CR>", desc = "Toggle outline" },
  },
  opts = {
    -- Your setup opts here
    symbol_folding = {
      -- Unfold entire symbol tree by default with false, otherwise enter 0 to fold when opening
      autofold_depth = 0,
      auto_unfold = {
        only = true,
        hovered = true,
      },
    },
    outline_window = {
      -- Percentage or integer of columns
      width = 33,
    },
  },
}
