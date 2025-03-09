if vim.g.vscode then
  return {}
end

return {
  "iamcco/markdown-preview.nvim",
  enabled = false,
  build = "cd app && yarn install",
  init = function()
    vim.g.mkdp_filetypes = { "markdown" }
  end,
  ft = { "markdown" },
}
