return {
  "mason-org/mason.nvim",
  opts = function(_, opts)
    vim.list_extend(opts.ensure_installed, {
      "templ",
      "html-lsp",
      "tailwindcss-language-server",
      "harper-ls",
      "prettierd",
      "eslint-lsp",
      "vtsls",
    })
  end,
}
