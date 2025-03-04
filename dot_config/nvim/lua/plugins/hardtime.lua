if vim.g.vscode then
  return {}
end

return {
  "m4xshen/hardtime.nvim",
  enabled = false,
  dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
  opts = {
    disabled_filetypes = { "qf", "netrw", "NvimTree", "lazy", "mason", "oil" },
  },
}
