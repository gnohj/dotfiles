if vim.g.vscode then
  return {}
end

-- Lazyvim will call this plugin via autocmd: on readpost, insertleave, writepost
return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        yaml = { "actionlint" },
      },
      linters = {
        actionlint = {
          condition = function(ctx)
            -- Match both workflows and actions directories
            return ctx.filename:match("%.github/workflows/.*%.ya?ml$")
              or ctx.filename:match("%.github/actions/.*/action%.ya?ml$")
          end,
        },
      },
    },
  },
}
