if vim.g.vscode then
  return {}
end

return {
  "mason-org/mason.nvim",
  opts = {
    ensure_installed = {
      "eslint-lsp",
      "harper-ls",
      "lua-language-server",
      "prettier",
      "prettierd",
      "vtsls",
    },
  },
}
