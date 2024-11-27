if vim.g.vscode then
  return {}
end

return {
  "jiaoshijie/undotree",
  dependencies = "nvim-lua/plenary.nvim",
  config = true,
  keys = {
    { "<leader>ut", "<cmd>lua require('undotree').toggle()<cr>", desc = "Toggle UndoTree" }, -- Correct syntax for desc
  },
}
