if vim.g.vscode then
  return {}
end

return {
  "m4xshen/hardtime.nvim",
  enabled = true,
  dependencies = { "MunifTanjim/nui.nvim" },
  event = "BufEnter",
  opts = {
    disabled_filetypes = { "qf", "netrw", "NvimTree", "lazy", "mason", "oil" },
    restricted_keys = {
      ["jk"] = false, -- Allow jk combination
      ["kj"] = false, -- Allow kj combination (if you use this too)
      ["j"] = false, -- Allow j key
      ["k"] = false, -- Allow k key
    },
  },
}
