if vim.g.vscode then
  return {}
end

return {
  "dmtrKovalenko/fold-imports.nvim",
  opts = {},
  event = "BufRead",
}
